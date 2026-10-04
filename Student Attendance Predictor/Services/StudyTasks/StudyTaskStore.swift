//
//  StudyTaskStore.swift
//  Student Attendance Predictor
//
//  On-device task list. Home, reminders, and Focus Timer all read this.
//

import Foundation
import Combine

@MainActor
final class StudyTaskStore: ObservableObject {
    static let shared = StudyTaskStore()

    @Published private(set) var tasks: [StudyTask] = []

    private let defaults: UserDefaults
    private enum Keys {
        static let tasks = "studyTasks.items.v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        fillMissingDueDates()
        archivePastExams()
    }

    var pending: [StudyTask] {
        tasks
            .filter { $0.isDone == false && $0.isArchived == false }
            .sorted(by: Self.sortPending)
    }

    var dueSoon: [StudyTask] {
        pending.filter { task in
            guard let days = task.daysRemaining else { return false }
            return days <= 2
        }
    }

    var dueToday: [StudyTask] {
        pending.filter { $0.daysRemaining == 0 }
    }

    var upcomingExams: [StudyTask] {
        pending.filter { $0.kind == .exam && ($0.daysRemaining ?? 99) <= 7 }
    }

    func tasks(for subjectID: UUID?) -> [StudyTask] {
        guard let subjectID else { return pending }
        return pending.filter { $0.subjectID == subjectID }
    }

    func task(id: UUID) -> StudyTask? {
        tasks.first { $0.id == id }
    }

    func nextPending(after currentID: UUID?) -> StudyTask? {
        let list = pending
        guard list.isEmpty == false else { return nil }
        guard let currentID, let index = list.firstIndex(where: { $0.id == currentID }) else {
            return list.first
        }
        if index + 1 < list.count { return list[index + 1] }
        return list.first { $0.id != currentID }
    }

    @discardableResult
    func add(from drafts: [StudyTaskDraft], source: StudyTaskSource, subjects: [SubjectSummary]) -> Int {
        var added = 0
        for draft in drafts where draft.isSelected {
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false else { continue }
            let match = Self.matchSubject(name: draft.subjectName, subjects: subjects)
            let topics = draft.topicTitles.map { StudyTaskTopic(title: $0) }
            let task = StudyTask(
                title: String(title.prefix(80)),
                kind: draft.kind,
                subjectID: match.id,
                subjectName: match.name,
                dueDate: draft.dueDate ?? Self.nextDay(),
                topics: topics,
                source: source
            )
            tasks.insert(task, at: 0)
            added += 1
        }
        persist()
        rescheduleReminders()
        if added > 0 {
            AnalyticsService.shared.log(.studyTasksAdded(count: added))
        }
        return added
    }

    func complete(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone = true
        tasks[index].completedAt = Date()
        let finished = tasks[index]
        persist()
        rescheduleReminders()
        AnalyticsService.shared.log(.studyTaskCompleted(kind: finished.kind.rawValue))
        Self.markSyllabusCovered(for: finished)
    }

    @discardableResult
    func addSyllabusChapters(
        _ drafts: [SyllabusChapterDraft],
        document: SyllabusDocument,
        subjectName: String
    ) -> Int {
        var added = 0
        for draft in drafts where draft.isSelected {
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false else { continue }
            if hasOpenSyllabusLink(
                documentID: document.id,
                unitID: draft.unitID,
                topicID: draft.topicID
            ) {
                continue
            }
            let topics = draft.topicTitles.map { StudyTaskTopic(title: $0) }
            let task = StudyTask(
                title: String(title.prefix(80)),
                kind: .chapter,
                subjectID: document.subjectID,
                subjectName: subjectName,
                dueDate: draft.dueDate,
                topics: topics,
                source: .syllabus,
                syllabusDocumentID: document.id,
                syllabusUnitID: draft.unitID,
                syllabusTopicID: draft.topicID
            )
            tasks.insert(task, at: 0)
            added += 1
        }
        persist()
        rescheduleReminders()
        if added > 0 {
            AnalyticsService.shared.log(.studyTasksAdded(count: added))
        }
        return added
    }

    func hasOpenSyllabusLink(documentID: UUID, unitID: UUID?, topicID: UUID?) -> Bool {
        tasks.contains { task in
            task.isDone == false
                && task.isArchived == false
                && task.syllabusDocumentID == documentID
                && task.syllabusUnitID == unitID
                && task.syllabusTopicID == topicID
        }
    }

    static func chapterDrafts(
        from document: SyllabusDocument,
        includeLearned: Bool = false
    ) -> [SyllabusChapterDraft] {
        let units: [(unit: SyllabusUnit, topics: [SyllabusTopic])] = document.units.compactMap { unit in
            let topics = unit.topics.filter { includeLearned || $0.status != .learned }
            guard topics.isEmpty == false else { return nil }
            return (unit, topics)
        }
        guard units.isEmpty == false else { return [] }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        func due(offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: today) ?? today
        }

        if units.count >= 2 {
            return units.enumerated().map { index, item in
                var draft = SyllabusChapterDraft(
                    title: item.unit.title,
                    topicsText: item.topics.map(\.title).joined(separator: "\n"),
                    dueDate: due(offset: index + 1),
                    unitID: item.unit.id
                )
                if StudyTaskStore.shared.hasOpenSyllabusLink(
                    documentID: document.id,
                    unitID: item.unit.id,
                    topicID: nil
                ) {
                    draft.isSelected = false
                }
                return draft
            }
        }

        let topics = units.flatMap { unit in
            unit.topics.map { (unit: unit.unit, topic: $0) }
        }
        return topics.enumerated().map { index, item in
            var draft = SyllabusChapterDraft(
                title: item.topic.title,
                topicsText: "",
                dueDate: due(offset: index + 1),
                unitID: item.unit.id,
                topicID: item.topic.id
            )
            if StudyTaskStore.shared.hasOpenSyllabusLink(
                documentID: document.id,
                unitID: item.unit.id,
                topicID: item.topic.id
            ) {
                draft.isSelected = false
            }
            return draft
        }
    }

    private static func markSyllabusCovered(for task: StudyTask) {
        guard let documentID = task.syllabusDocumentID else { return }
        if let topicID = task.syllabusTopicID {
            SyllabusStore.shared.setTopicStatus(
                documentID: documentID,
                topicID: topicID,
                status: .learned
            )
            return
        }
        if let unitID = task.syllabusUnitID {
            SyllabusStore.shared.markUnitLearned(documentID: documentID, unitID: unitID)
        }
    }

    func reopen(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone = false
        tasks[index].completedAt = nil
        tasks[index].isArchived = false
        persist()
        rescheduleReminders()
    }

    func delete(id: UUID) {
        tasks.removeAll { $0.id == id }
        persist()
        rescheduleReminders()
    }

    func setTopicCovered(taskID: UUID, topicID: UUID, covered: Bool) {
        guard let t = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        guard let p = tasks[t].topics.firstIndex(where: { $0.id == topicID }) else { return }
        tasks[t].topics[p].isCovered = covered
        persist()
        AnalyticsService.shared.log(.studyTaskTopicCovered)
    }

    func update(_ task: StudyTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        persist()
        rescheduleReminders()
    }

    func rescheduleReminders() {
        NotificationService.rescheduleStudyTaskReminders(tasks: pending)
    }

    func fillMissingDueDates() {
        let tomorrow = Self.nextDay()
        var changed = false
        for index in tasks.indices {
            guard tasks[index].isDone == false, tasks[index].isArchived == false else { continue }
            guard tasks[index].dueDate == nil else { continue }
            tasks[index].dueDate = tomorrow
            changed = true
        }
        if changed {
            persist()
            rescheduleReminders()
        }
    }

    static func nextDay(from today: Date = Date()) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: today)) ?? today
    }

    func archivePastExams() {
        let start = Calendar.current.startOfDay(for: Date())
        var changed = false
        for index in tasks.indices {
            let task = tasks[index]
            guard task.kind == .exam, task.isArchived == false, let due = task.dueDate else { continue }
            if due < start {
                tasks[index].isArchived = true
                changed = true
            }
        }
        if changed {
            persist()
            rescheduleReminders()
        }
    }

    static func matchSubject(name: String, subjects: [SubjectSummary]) -> (id: UUID?, name: String) {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.isEmpty == false else { return (nil, "") }
        let lower = needle.lowercased()
        if let exact = subjects.first(where: { $0.name.lowercased() == lower }) {
            return (exact.id, exact.name)
        }
        if let partial = subjects.first(where: {
            $0.name.lowercased().contains(lower) || lower.contains($0.name.lowercased())
        }) {
            return (partial.id, partial.name)
        }
        return (nil, String(needle.prefix(40)))
    }

    private static func sortPending(_ lhs: StudyTask, _ rhs: StudyTask) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?):
            if l != r { return l < r }
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case (nil, nil):
            break
        }
        return lhs.createdAt > rhs.createdAt
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.tasks),
              let decoded = try? JSONDecoder().decode([StudyTask].self, from: data) else {
            tasks = []
            return
        }
        tasks = decoded
        rescheduleReminders()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: Keys.tasks)
        }
    }
}
