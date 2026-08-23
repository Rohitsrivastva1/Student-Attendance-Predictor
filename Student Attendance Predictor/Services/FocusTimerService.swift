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

    @Published private(set) var todayFocusMinutes: Int = 0
    @Published private(set) var todaySessionCount: Int = 0
    @Published private(set) var weekFocusMinutes: Int = 0
    @Published private(set) var markPromptActive = false

    private var timer: Timer?
    private var markPromptTimer: Timer?
    private var segmentStartedAt: Date?
    private var segmentDurationSeconds: Int = defaultFocusMinutes * 60
    private var dailyMinutes: [String: Int] = [:]

    private enum Keys {
        static let day = "focus.stats.day"
        static let minutes = "focus.stats.minutes"
        static let sessions = "focus.stats.sessions"
        static let preferredMinutes = "focus.preferredMinutes"
        static let preferredBreak = "focus.preferredBreak"
        static let dailyGoal = "focus.dailyGoalMinutes"
        static let history = "focus.dailyHistory"
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
        loadHistory()
        reloadTodayStats()
        recomputeWeekMinutes()
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

    func startOrResume() {
        if phase == .idle {
            phase = .focus
            segmentDurationSeconds = selectedFocusMinutes * 60
            remainingSeconds = segmentDurationSeconds
            defaults.set(selectedFocusMinutes, forKey: Keys.preferredMinutes)
            defaults.set(selectedBreakMinutes, forKey: Keys.preferredBreak)
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
        scheduleEndNotification()
        startTicker()
        syncLiveActivity()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        NotificationService.cancelFocusTimerNotification()
        if phase != .idle {
            AnalyticsService.shared.log(
                .focusTimerPaused(phase: phase.rawValue, remainingSeconds: remainingSeconds)
            )
        }
        syncLiveActivity()
    }

    func reset() {
        let previousPhase = phase
        cancelMarkPrompt(logDismissed: false)
        pause()
        phase = .idle
        remainingSeconds = selectedFocusMinutes * 60
        segmentDurationSeconds = remainingSeconds
        if previousPhase != .idle {
            AnalyticsService.shared.log(.focusTimerReset(phase: previousPhase.rawValue))
        }
        syncLiveActivity()
    }

    func skipToBreak() {
        guard phase == .focus else { return }
        completeFocusSegment(recordStats: false)
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
            phase = .idle
            remainingSeconds = selectedFocusMinutes * 60
            segmentDurationSeconds = remainingSeconds
            syncLiveActivity()
        case .idle:
            break
        }
    }

    func completeMarkPrompt(status: String) {
        guard markPromptActive else { return }
        cancelMarkPrompt(logDismissed: false)
        AnalyticsService.shared.log(.focusMarkPromptUsed(status: status))
        startBreakSegment()
    }

    private func completeFocusSegment(recordStats: Bool) {
        if recordStats {
            let minutes = max(1, selectedFocusMinutes)
            recordCompletedFocus(minutes: minutes)

            if let subjectID = taggedSubjectID, let subjectName = taggedSubjectName {
                beginMarkPrompt(completedMinutes: minutes, subjectID: subjectID, subjectName: subjectName)
                return
            }
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
        phase = .breakTime
        segmentDurationSeconds = selectedBreakMinutes * 60
        remainingSeconds = segmentDurationSeconds
        isRunning = true
        segmentStartedAt = Date()
        scheduleEndNotification()
        startTicker()
        syncLiveActivity()
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
        AnalyticsService.shared.log(
            .focusTimerCompleted(
                minutes: minutes,
                hasSubjectTag: taggedSubjectID != nil,
                hasTopicTag: topicStore.selectedTopicID != nil
            )
        )
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

    private static func dayKey(date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
