//
//  FocusTimerService.swift
//  Student Attendance Predictor
//
//  Pomodoro-style focus / break timer. One active session; today + week stats in UserDefaults.
//

import Foundation
import Combine

@MainActor
final class FocusTimerService: ObservableObject {
    static let shared = FocusTimerService()

    enum Phase: String {
        case idle
        case focus
        case breakTime = "break"
    }

    static let freeFocusOptions = [15, 25, 45, 60]
    static let proQuickOptions = [90]
    static let breakOptions = [5, 10, 15]
    static let defaultFocusMinutes = 25
    static let defaultBreakMinutes = 5
    static let defaultDailyGoalMinutes = 60
    static let markPromptDurationSeconds = 30
    static let minCustomMinutes = 5
    static let maxCustomMinutes = 180

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var remainingSeconds: Int = defaultFocusMinutes * 60
    @Published private(set) var isRunning = false
    @Published var selectedFocusMinutes: Int = defaultFocusMinutes {
        didSet {
            let clamped = min(max(selectedFocusMinutes, Self.minCustomMinutes), Self.maxCustomMinutes)
            if clamped != selectedFocusMinutes {
                selectedFocusMinutes = clamped
                return
            }
            guard phase == .idle else { return }
            remainingSeconds = selectedFocusMinutes * 60
        }
    }
    @Published var selectedBreakMinutes: Int = defaultBreakMinutes
    @Published var dailyGoalMinutes: Int = defaultDailyGoalMinutes
    @Published var taggedSubjectID: UUID?
    @Published var taggedSubjectName: String?

    private var topicStore: FocusTopicStore { FocusTopicStore.shared }
    private var taskStore: StudyTaskStore { StudyTaskStore.shared }

    /// Task list item the student is sitting with. Nil means Other (freeform / syllabus).
    @Published var selectedTaskID: UUID?
    @Published var pendingTaskWrapUp: TaskWrapUpPrompt?

    struct TaskWrapUpPrompt: Equatable {
        let taskID: UUID
        let title: String
        let kind: StudyTaskKind
        let firstUncoveredTopic: StudyTaskTopic?
        let nextTaskID: UUID?
        let nextTitle: String?
    }

    @Published private(set) var todayFocusMinutes: Int = 0
    @Published private(set) var todaySessionCount: Int = 0
    @Published private(set) var weekFocusMinutes: Int = 0
    @Published private(set) var markPromptActive = false
    /// After a focus session on a syllabus-linked topic — student confirms “mark learned”.
    @Published var pendingSyllabusLearnPrompt: SyllabusLearnPrompt?

    struct SyllabusLearnPrompt: Equatable {
        let documentID: UUID
        let topicID: UUID
        let title: String
    }

    private var timer: Timer?
    private var markPromptTimer: Timer?
    private var segmentStartedAt: Date?
    private var segmentDurationSeconds: Int = defaultFocusMinutes * 60
    private var dailyMinutes: [String: Int] = [:]
    /// Accumulated focus seconds across pause/resume for the current focus segment.
    private var focusedElapsedSeconds: Int = 0
    private var lastTickAt: Date?

    @Published var autoStartNextFocus = false

    private enum Keys {
        static let day = "focus.stats.day"
        static let minutes = "focus.stats.minutes"
        static let sessions = "focus.stats.sessions"
        static let preferredMinutes = "focus.preferredMinutes"
        static let preferredBreak = "focus.preferredBreak"
        static let dailyGoal = "focus.dailyGoalMinutes"
        static let history = "focus.dailyHistory"
        static let autoNext = "focus.autoStartNext"
        static let activeSnapshot = "focus.activeSnapshot.v1"
    }

    private let defaults = UserDefaults.standard

    init() {
        let preferred = defaults.object(forKey: Keys.preferredMinutes) as? Int
        if let preferred, (Self.minCustomMinutes...Self.maxCustomMinutes).contains(preferred) {
            selectedFocusMinutes = preferred
        }
        let breakPreferred = defaults.object(forKey: Keys.preferredBreak) as? Int
        if let breakPreferred, Self.breakOptions.contains(breakPreferred) {
            selectedBreakMinutes = breakPreferred
        }
        let goal = defaults.object(forKey: Keys.dailyGoal) as? Int
        if let goal, (15...180).contains(goal) {
            dailyGoalMinutes = goal
        }
        remainingSeconds = selectedFocusMinutes * 60
        autoStartNextFocus = defaults.bool(forKey: Keys.autoNext)
        loadHistory()
        reloadTodayStats()
        recomputeWeekMinutes()
        restoreActiveSnapshotIfNeeded()
    }

    /// Call once after launch — must not run inside `init` (Live Activity reconcile used to re-enter `shared`).
    func reconcileLiveActivityOnLaunchIfNeeded() {
        FocusTimerLiveActivityService.reconcileOnLaunch(
            phase: phase,
            isRunning: isRunning,
            remainingSeconds: remainingSeconds,
            segmentDurationSeconds: segmentDurationSeconds,
            subjectName: taggedSubjectName,
            markPromptActive: markPromptActive
        )
    }

    var progress: Double {
        guard segmentDurationSeconds > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(segmentDurationSeconds))
    }

    var displayTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var phaseLabel: String {
        if markPromptActive {
            return "Mark today's class?"
        }
        switch phase {
        case .idle: return "Ready to focus"
        case .focus: return isRunning ? "Focusing" : "Paused"
        case .breakTime: return isRunning ? "Break" : "Break paused"
        }
    }

    var dailyGoalProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(1, Double(todayFocusMinutes) / Double(dailyGoalMinutes))
    }

    var isUsingProDuration: Bool {
        Self.freeFocusOptions.contains(selectedFocusMinutes) == false
            || selectedBreakMinutes != Self.defaultBreakMinutes
    }

    func clampToEntitlement(isPro: Bool) {
        guard isPro == false else { return }
        if Self.freeFocusOptions.contains(selectedFocusMinutes) == false {
            selectedFocusMinutes = Self.defaultFocusMinutes
        }
        if selectedBreakMinutes != Self.defaultBreakMinutes {
            selectedBreakMinutes = Self.defaultBreakMinutes
        }
    }

    func tagSubject(id: UUID?, name: String?) {
        taggedSubjectID = id
        taggedSubjectName = name?.isEmpty == false ? name : nil
    }

    var selectedTask: StudyTask? {
        guard let selectedTaskID else { return nil }
        return taskStore.task(id: selectedTaskID)
    }

    func selectTask(_ task: StudyTask) {
        selectedTaskID = task.id
        topicStore.clearSelection()
        if let sid = task.subjectID {
            tagSubject(id: sid, name: task.subjectName)
        } else if task.subjectName.isEmpty == false {
            tagSubject(id: taggedSubjectID, name: task.subjectName)
        }
        AnalyticsService.shared.log(.focusTaskSelected(kind: task.kind.rawValue))
    }

    func selectOtherFocus() {
        selectedTaskID = nil
        pendingTaskWrapUp = nil
    }

    func continueSelectedTask() {
        pendingTaskWrapUp = nil
        restartFocusFromWrapUp()
    }

    func startNextPendingTask() {
        guard let nextID = pendingTaskWrapUp?.nextTaskID,
              let next = taskStore.task(id: nextID) else {
            pendingTaskWrapUp = nil
            return
        }
        pendingTaskWrapUp = nil
        selectTask(next)
        restartFocusFromWrapUp()
    }

    private func restartFocusFromWrapUp() {
        pause()
        phase = .idle
        focusedElapsedSeconds = 0
        remainingSeconds = selectedFocusMinutes * 60
        segmentDurationSeconds = remainingSeconds
        startOrResume()
    }

    func markSelectedTaskDone() {
        guard let prompt = pendingTaskWrapUp ?? selectedTask.map({
            TaskWrapUpPrompt(
                taskID: $0.id,
                title: $0.title,
                kind: $0.kind,
                firstUncoveredTopic: $0.uncoveredTopics.first,
                nextTaskID: taskStore.nextPending(after: $0.id)?.id,
                nextTitle: taskStore.nextPending(after: $0.id)?.title
            )
        }) else { return }
        taskStore.complete(id: prompt.taskID)
        AnalyticsService.shared.log(.focusTaskMarkedDone)
        if let nextID = prompt.nextTaskID, let next = taskStore.task(id: nextID) {
            selectTask(next)
        } else {
            selectOtherFocus()
        }
        pendingTaskWrapUp = nil
    }

    func coverFirstTopicFromWrapUp() {
        guard let prompt = pendingTaskWrapUp, let topic = prompt.firstUncoveredTopic else { return }
        taskStore.setTopicCovered(taskID: prompt.taskID, topicID: topic.id, covered: true)
        pendingTaskWrapUp = nil
    }

    func dismissTaskWrapUp() {
        pendingTaskWrapUp = nil
    }

    func startOrResume() {
        if phase == .idle {
            phase = .focus
            segmentDurationSeconds = selectedFocusMinutes * 60
            remainingSeconds = segmentDurationSeconds
            focusedElapsedSeconds = 0
            defaults.set(selectedFocusMinutes, forKey: Keys.preferredMinutes)
            defaults.set(selectedBreakMinutes, forKey: Keys.preferredBreak)
            FocusSessionStore.shared.noteFocusSegmentStarted()
            AnalyticsService.shared.log(
                .focusTimerStarted(
                    minutes: selectedFocusMinutes,
                    hasSubjectTag: taggedSubjectID != nil,
                    hasTopicTag: topicStore.selectedTopicID != nil
                )
            )
        }
        guard remainingSeconds > 0 else { return }
        isRunning = true
        segmentStartedAt = Date()
        lastTickAt = Date()
        scheduleEndNotification()
        startTicker()
        syncLiveActivity()
        persistActiveSnapshot()
    }

    func pause() {
        accumulateRunningElapsed()
        isRunning = false
        timer?.invalidate()
        timer = nil
        lastTickAt = nil
        NotificationService.cancelFocusTimerNotification()
        if phase != .idle {
            AnalyticsService.shared.log(
                .focusTimerPaused(phase: phase.rawValue, remainingSeconds: remainingSeconds)
            )
        }
        syncLiveActivity()
        persistActiveSnapshot()
    }

    func reset() {
        let previousPhase = phase
        if previousPhase == .focus {
            accumulateRunningElapsed()
            FocusSessionStore.shared.recordAbandonedIfNeeded(
                plannedMinutes: selectedFocusMinutes,
                actualSeconds: focusedElapsedSeconds,
                subjectID: taggedSubjectID,
                subjectName: taggedSubjectName,
                topicID: topicStore.selectedTopicID,
                topicName: topicStore.selectedTopic?.name
            )
        }
        cancelMarkPrompt(logDismissed: false)
        pause()
        phase = .idle
        focusedElapsedSeconds = 0
        remainingSeconds = selectedFocusMinutes * 60
        segmentDurationSeconds = remainingSeconds
        if previousPhase != .idle {
            AnalyticsService.shared.log(.focusTimerReset(phase: previousPhase.rawValue))
        }
        clearActiveSnapshot()
        syncLiveActivity()
    }

    func skipToBreak() {
        guard phase == .focus else { return }
        accumulateRunningElapsed()
        completeFocusSegment(recordStats: true)
    }

    func setAutoStartNextFocus(_ enabled: Bool) {
        autoStartNextFocus = enabled
        defaults.set(enabled, forKey: Keys.autoNext)
    }

    func persistDailyGoal() {
        let clamped = min(max(dailyGoalMinutes, 15), 180)
        dailyGoalMinutes = clamped
        defaults.set(clamped, forKey: Keys.dailyGoal)
    }

    private func startTicker() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tick() {
        guard isRunning else { return }
        if phase == .focus {
            focusedElapsedSeconds += 1
        }
        persistActiveSnapshotThrottled()
        guard remainingSeconds > 0 else {
            handleSegmentComplete()
            return
        }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            handleSegmentComplete()
        }
    }

    private func handleSegmentComplete() {
        pause()
        switch phase {
        case .focus:
            completeFocusSegment(recordStats: true)
        case .breakTime:
            clearActiveSnapshot()
            if autoStartNextFocus, AdEntitlementsStore.shared.hasProFeatures {
                phase = .idle
                remainingSeconds = selectedFocusMinutes * 60
                segmentDurationSeconds = remainingSeconds
                startOrResume()
            } else {
                phase = .idle
                remainingSeconds = selectedFocusMinutes * 60
                segmentDurationSeconds = remainingSeconds
                syncLiveActivity()
            }
        case .idle:
            break
        }
    }

    func completeMarkPrompt(status: String) {
        guard markPromptActive else { return }
        cancelMarkPrompt(logDismissed: false)
        AnalyticsService.shared.log(.focusMarkPromptUsed(status: status))
        offerPostSessionPrompt()
        startBreakSegment()
    }

    private func completeFocusSegment(recordStats: Bool) {
        if recordStats {
            accumulateRunningElapsed()
            let actualSeconds = max(focusedElapsedSeconds, segmentDurationSeconds - remainingSeconds)
            let minutes = max(1, Int(round(Double(actualSeconds) / 60.0)))
            focusedElapsedSeconds = actualSeconds
            recordCompletedFocus(minutes: minutes)

            if let subjectID = taggedSubjectID, let subjectName = taggedSubjectName {
                beginMarkPrompt(completedMinutes: minutes, subjectID: subjectID, subjectName: subjectName)
                return
            }
            offerPostSessionPrompt()
        }
        startBreakSegment()
    }

    private func beginMarkPrompt(completedMinutes: Int, subjectID: UUID, subjectName: String) {
        markPromptActive = true
        isRunning = false
        timer?.invalidate()
        timer = nil
        NotificationService.cancelFocusTimerNotification()

        let expiresAt = Date().addingTimeInterval(TimeInterval(Self.markPromptDurationSeconds))
        FocusTimerLiveActivityService.showMarkPrompt(
            completedFocusMinutes: completedMinutes,
            subjectID: subjectID,
            subjectName: subjectName,
            expiresAt: expiresAt,
            promptDurationSeconds: Self.markPromptDurationSeconds
        )

        markPromptTimer?.invalidate()
        markPromptTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(Self.markPromptDurationSeconds), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishMarkPromptWithoutMark()
            }
        }
        if let markPromptTimer {
            RunLoop.main.add(markPromptTimer, forMode: .common)
        }
    }

    private func finishMarkPromptWithoutMark() {
        guard markPromptActive else { return }
        cancelMarkPrompt(logDismissed: true)
        offerPostSessionPrompt()
        startBreakSegment()
    }

    private func cancelMarkPrompt(logDismissed: Bool) {
        markPromptTimer?.invalidate()
        markPromptTimer = nil
        guard markPromptActive else { return }
        markPromptActive = false
        if logDismissed {
            AnalyticsService.shared.log(.focusMarkPromptDismissed)
        }
    }

    private func startBreakSegment() {
        focusedElapsedSeconds = 0
        phase = .breakTime
        segmentDurationSeconds = selectedBreakMinutes * 60
        remainingSeconds = segmentDurationSeconds
        isRunning = true
        segmentStartedAt = Date()
        lastTickAt = Date()
        scheduleEndNotification()
        startTicker()
        syncLiveActivity()
        persistActiveSnapshot()
    }

    private func syncLiveActivity() {
        FocusTimerLiveActivityService.sync(
            phase: phase,
            isRunning: isRunning,
            remainingSeconds: remainingSeconds,
            segmentDurationSeconds: segmentDurationSeconds,
            subjectName: liveActivityContextLabel
        )
    }

    private var liveActivityContextLabel: String? {
        if let task = selectedTask {
            if task.subjectName.isEmpty == false {
                return "\(task.subjectName) · \(task.title)"
            }
            return task.title
        }
        let topicName = topicStore.selectedTopic?.name
        switch (taggedSubjectName, topicName) {
        case let (subject?, topic?):
            return "\(subject) · \(topic)"
        case let (subject?, nil):
            return subject
        case let (nil, topic?):
            return topic
        case (nil, nil):
            return nil
        }
    }

    private func scheduleEndNotification() {
        NotificationService.scheduleFocusTimerEnd(
            afterSeconds: remainingSeconds,
            phase: phase == .focus ? "focus" : "break",
            breakMinutes: selectedBreakMinutes
        )
    }

    private func recordCompletedFocus(minutes: Int) {
        reloadTodayStats()
        todayFocusMinutes += minutes
        todaySessionCount += 1
        defaults.set(todayFocusMinutes, forKey: Keys.minutes)
        defaults.set(todaySessionCount, forKey: Keys.sessions)
        defaults.set(Self.dayKey(), forKey: Keys.day)
        dailyMinutes[Self.dayKey()] = todayFocusMinutes
        persistHistory()
        recomputeWeekMinutes()
        topicStore.recordSession(topicID: topicStore.selectedTopicID, minutes: minutes)
        FocusSessionStore.shared.recordCompleted(
            plannedMinutes: selectedFocusMinutes,
            actualSeconds: max(minutes * 60, focusedElapsedSeconds),
            subjectID: taggedSubjectID,
            subjectName: taggedSubjectName,
            topicID: topicStore.selectedTopicID,
            topicName: topicStore.selectedTopic?.name
        )
        AnalyticsService.shared.log(
            .focusTimerCompleted(
                minutes: minutes,
                hasSubjectTag: taggedSubjectID != nil,
                hasTopicTag: topicStore.selectedTopicID != nil
            )
        )
    }

    private func offerPostSessionPrompt() {
        if let task = selectedTask, task.isDone == false {
            let next = taskStore.nextPending(after: task.id)
            pendingTaskWrapUp = TaskWrapUpPrompt(
                taskID: task.id,
                title: task.title,
                kind: task.kind,
                firstUncoveredTopic: task.uncoveredTopics.first,
                nextTaskID: next?.id,
                nextTitle: next?.title
            )
            return
        }
        offerSyllabusLearnedIfNeeded()
    }

    private func offerSyllabusLearnedIfNeeded() {
        guard let focusTopic = topicStore.selectedTopic else { return }
        if let linked = SyllabusStore.shared.topic(linkedToFocusTopicID: focusTopic.id),
           linked.topic.status != .learned {
            pendingSyllabusLearnPrompt = SyllabusLearnPrompt(
                documentID: linked.document.id,
                topicID: linked.topic.id,
                title: linked.topic.title
            )
            return
        }
        if let syllabusTopicID = focusTopic.syllabusTopicID {
            for doc in SyllabusStore.shared.documents {
                if let topic = doc.allTopics.first(where: { $0.id == syllabusTopicID }),
                   topic.status != .learned {
                    pendingSyllabusLearnPrompt = SyllabusLearnPrompt(
                        documentID: doc.id,
                        topicID: topic.id,
                        title: topic.title
                    )
                    return
                }
            }
        }
    }

    func confirmSyllabusLearned() {
        guard let prompt = pendingSyllabusLearnPrompt else { return }
        SyllabusStore.shared.setTopicStatus(
            documentID: prompt.documentID,
            topicID: prompt.topicID,
            status: .learned
        )
        AnalyticsService.shared.log(.syllabusTopicMarkedLearned(fromFocus: true))
        pendingSyllabusLearnPrompt = nil
    }

    func dismissSyllabusLearnedPrompt() {
        pendingSyllabusLearnPrompt = nil
    }

    private func reloadTodayStats() {
        let today = Self.dayKey()
        if defaults.string(forKey: Keys.day) != today {
            defaults.set(today, forKey: Keys.day)
            defaults.set(0, forKey: Keys.minutes)
            defaults.set(0, forKey: Keys.sessions)
            todayFocusMinutes = 0
            todaySessionCount = 0
        } else {
            todayFocusMinutes = defaults.integer(forKey: Keys.minutes)
            todaySessionCount = defaults.integer(forKey: Keys.sessions)
        }
        dailyMinutes[today] = todayFocusMinutes
    }

    private func loadHistory() {
        guard
            let data = defaults.data(forKey: Keys.history),
            let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            dailyMinutes = [:]
            return
        }
        dailyMinutes = decoded
    }

    private func persistHistory() {
        let cutoff = Self.dayKey(date: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date())
        dailyMinutes = dailyMinutes.filter { $0.key >= cutoff }
        if let data = try? JSONEncoder().encode(dailyMinutes) {
            defaults.set(data, forKey: Keys.history)
        }
    }

    private func recomputeWeekMinutes() {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            weekFocusMinutes = todayFocusMinutes
            return
        }
        var total = 0
        var cursor = week.start
        while cursor < week.end {
            total += dailyMinutes[Self.dayKey(date: cursor)] ?? 0
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        weekFocusMinutes = total
    }

    private func accumulateRunningElapsed() {
        guard phase == .focus, isRunning, let lastTickAt else { return }
        let delta = Int(Date().timeIntervalSince(lastTickAt))
        if delta > 0 {
            focusedElapsedSeconds += delta
        }
        self.lastTickAt = Date()
    }

    private struct ActiveSnapshot: Codable {
        var phase: String
        var remainingSeconds: Int
        var segmentDurationSeconds: Int
        var isRunning: Bool
        var focusedElapsedSeconds: Int
        var selectedFocusMinutes: Int
        var selectedBreakMinutes: Int
        var taggedSubjectID: String?
        var taggedSubjectName: String?
        var selectedTopicID: String?
        var savedAt: Date
    }

    private var lastSnapshotWrite: Date?

    private func persistActiveSnapshotThrottled() {
        let now = Date()
        if let lastSnapshotWrite, now.timeIntervalSince(lastSnapshotWrite) < 5 { return }
        persistActiveSnapshot()
    }

    private func persistActiveSnapshot() {
        guard phase != .idle || markPromptActive else {
            clearActiveSnapshot()
            return
        }
        let snap = ActiveSnapshot(
            phase: markPromptActive ? "markPrompt" : phase.rawValue,
            remainingSeconds: remainingSeconds,
            segmentDurationSeconds: segmentDurationSeconds,
            isRunning: isRunning && markPromptActive == false,
            focusedElapsedSeconds: focusedElapsedSeconds,
            selectedFocusMinutes: selectedFocusMinutes,
            selectedBreakMinutes: selectedBreakMinutes,
            taggedSubjectID: taggedSubjectID?.uuidString,
            taggedSubjectName: taggedSubjectName,
            selectedTopicID: topicStore.selectedTopicID?.uuidString,
            savedAt: Date()
        )
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: Keys.activeSnapshot)
            lastSnapshotWrite = Date()
        }
    }

    private func clearActiveSnapshot() {
        defaults.removeObject(forKey: Keys.activeSnapshot)
    }

    private func restoreActiveSnapshotIfNeeded() {
        guard let data = defaults.data(forKey: Keys.activeSnapshot),
              let snap = try? JSONDecoder().decode(ActiveSnapshot.self, from: data) else { return }
        guard Date().timeIntervalSince(snap.savedAt) < 6 * 3600 else {
            clearActiveSnapshot()
            return
        }
        if snap.phase == "markPrompt" {
            clearActiveSnapshot()
            return
        }
        guard let restoredPhase = Phase(rawValue: snap.phase), restoredPhase != .idle else {
            clearActiveSnapshot()
            return
        }

        selectedFocusMinutes = snap.selectedFocusMinutes
        selectedBreakMinutes = snap.selectedBreakMinutes
        phase = restoredPhase
        remainingSeconds = max(0, snap.remainingSeconds)
        segmentDurationSeconds = max(1, snap.segmentDurationSeconds)
        focusedElapsedSeconds = max(0, snap.focusedElapsedSeconds)
        taggedSubjectID = snap.taggedSubjectID.flatMap(UUID.init(uuidString:))
        taggedSubjectName = snap.taggedSubjectName
        if let topicRaw = snap.selectedTopicID, let topicID = UUID(uuidString: topicRaw) {
            topicStore.selectTopic(id: topicID)
        }
        if snap.isRunning, remainingSeconds > 0 {
            let elapsedAway = Int(Date().timeIntervalSince(snap.savedAt))
            if restoredPhase == .focus {
                focusedElapsedSeconds += max(0, elapsedAway)
            }
            remainingSeconds = max(0, remainingSeconds - elapsedAway)
            if remainingSeconds == 0 {
                handleSegmentComplete()
            } else {
                isRunning = true
                lastTickAt = Date()
                segmentStartedAt = Date()
                startTicker()
                scheduleEndNotification()
                syncLiveActivity()
            }
        } else {
            isRunning = false
            syncLiveActivity()
        }
    }

    private static func dayKey(date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
