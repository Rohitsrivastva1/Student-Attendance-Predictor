//
//  StudyTaskModels.swift
//  Student Attendance Predictor
//
//  Homework / assignment / exam list. Focus Timer picks from this list.
//

import Foundation

enum StudyTaskKind: String, Codable, CaseIterable, Identifiable {
    case homework
    case assignment
    case quiz
    case exam
    case chapter
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .homework: return "Homework"
        case .assignment: return "Assignment"
        case .quiz: return "Quiz"
        case .exam: return "Exam"
        case .chapter: return "Chapter"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .homework: return "book.closed.fill"
        case .assignment: return "doc.text.fill"
        case .quiz: return "questionmark.circle.fill"
        case .exam: return "pencil.and.list.clipboard"
        case .chapter: return "text.book.closed.fill"
        case .other: return "flag.fill"
        }
    }

    static func inferred(from text: String) -> StudyTaskKind {
        let lower = text.lowercased()
        if lower.contains("exam") || lower.contains("midsem") || lower.contains("end sem")
            || lower.contains("endsem") || lower.contains("internal") || lower.contains("midterm")
            || lower.contains("datesheet") || lower.contains("date sheet") {
            return .exam
        }
        if lower.contains("quiz") || lower.contains("test") || lower.contains("viva") {
            return .quiz
        }
        if lower.contains("assignment") || lower.contains("assign") || lower.contains("project") {
            return .assignment
        }
        if lower.contains("homework") || lower.contains("hw ") || lower.hasPrefix("hw")
            || lower.contains("home work") {
            return .homework
        }
        return .homework
    }
}

enum StudyTaskSource: String, Codable {
    case photo
    case paste
    case manual
    case syllabus
}

struct StudyTaskTopic: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCovered: Bool

    init(id: UUID = UUID(), title: String, isCovered: Bool = false) {
        self.id = id
        self.title = title
        self.isCovered = isCovered
    }
}

struct StudyTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var kind: StudyTaskKind
    var subjectID: UUID?
    var subjectName: String
    var dueDate: Date?
    var isDone: Bool
    var isArchived: Bool
    var topics: [StudyTaskTopic]
    var notes: String
    var source: StudyTaskSource
    var createdAt: Date
    var completedAt: Date?
    var syllabusDocumentID: UUID?
    var syllabusUnitID: UUID?
    var syllabusTopicID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        kind: StudyTaskKind,
        subjectID: UUID? = nil,
        subjectName: String = "",
        dueDate: Date? = nil,
        isDone: Bool = false,
        isArchived: Bool = false,
        topics: [StudyTaskTopic] = [],
        notes: String = "",
        source: StudyTaskSource = .manual,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        syllabusDocumentID: UUID? = nil,
        syllabusUnitID: UUID? = nil,
        syllabusTopicID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.subjectID = subjectID
        self.subjectName = subjectName
        self.dueDate = dueDate
        self.isDone = isDone
        self.isArchived = isArchived
        self.topics = topics
        self.notes = notes
        self.source = source
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.syllabusDocumentID = syllabusDocumentID
        self.syllabusUnitID = syllabusUnitID
        self.syllabusTopicID = syllabusTopicID
    }

    var uncoveredTopics: [StudyTaskTopic] {
        topics.filter { $0.isCovered == false }
    }

    var coveredCount: Int {
        topics.filter(\.isCovered).count
    }

    var topicsLeftLabel: String {
        guard topics.isEmpty == false else { return kind.title }
        return "\(uncoveredTopics.count) of \(topics.count) topics left"
    }

    var daysRemaining: Int? {
        guard let dueDate else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: dueDate)
        return cal.dateComponents([.day], from: start, to: end).day
    }

    var dueLabel: String {
        guard let days = daysRemaining else { return "No date" }
        if days < 0 { return "\(-days)d overdue" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days left"
    }

    var displaySubject: String {
        let name = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "No subject" : name
    }
}

struct StudyTaskDraft: Identifiable, Equatable {
    var id: UUID
    var isSelected: Bool
    var title: String
    var kind: StudyTaskKind
    var subjectName: String
    var dueDate: Date?
    var topicsText: String
    var isDateFlagged: Bool

    init(
        id: UUID = UUID(),
        isSelected: Bool = true,
        title: String,
        kind: StudyTaskKind,
        subjectName: String = "",
        dueDate: Date? = nil,
        topicsText: String = "",
        isDateFlagged: Bool = false
    ) {
        self.id = id
        self.isSelected = isSelected
        self.title = title
        self.kind = kind
        self.subjectName = subjectName
        self.dueDate = dueDate
        self.topicsText = topicsText
        self.isDateFlagged = isDateFlagged
    }

    var topicTitles: [String] {
        topicsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}

struct SyllabusChapterDraft: Identifiable, Equatable {
    var id: UUID
    var isSelected: Bool
    var title: String
    var topicsText: String
    var dueDate: Date
    var unitID: UUID?
    var topicID: UUID?

    init(
        id: UUID = UUID(),
        isSelected: Bool = true,
        title: String,
        topicsText: String = "",
        dueDate: Date,
        unitID: UUID? = nil,
        topicID: UUID? = nil
    ) {
        self.id = id
        self.isSelected = isSelected
        self.title = title
        self.topicsText = topicsText
        self.dueDate = dueDate
        self.unitID = unitID
        self.topicID = topicID
    }

    var topicTitles: [String] {
        topicsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
