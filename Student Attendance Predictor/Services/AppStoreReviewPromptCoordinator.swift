//
//  AppStoreReviewPromptCoordinator.swift
//  Student Attendance Predictor
//
//  Custom review sheet every 5 attendance marks (5, 10, 15, …) until they
//  tap Yes ("Leave a kind review") or Rate Us in Settings.
//

import Combine
import Foundation

@MainActor
final class AppStoreReviewPromptCoordinator: ObservableObject {
    static let shared = AppStoreReviewPromptCoordinator()

    @Published var shouldPresentDayTwoPrompt = false

    private enum Keys {
        static let didRate = "review.didRate"
        static let promptCount = "review.v2.promptCount"
        static let snoozeUntil = "review.v2.snoozeUntil"
        static let lastNativeAt = "review.v2.lastNativeAt"
        static let markCount = "review.attendanceMarkCount"
        static let didBackfillMarks = "review.didBackfillMarkCount"
        static let lastPromptedMarkCount = "review.lastPromptedMarkCount"
    }

    /// Ask on every Nth real attendance mark (not holidays).
    static let minMarks = 5
    #if DEBUG
    static let nativeReviewMinDays = 3
    #else
    static let nativeReviewMinDays = 7
    #endif

    private var evaluateTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private var didConsumeCurrentPrompt = false
    private var pendingTrigger = "launch"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var attendanceMarkCount: Int {
        defaults.integer(forKey: Keys.markCount)
    }

    var hasRated: Bool {
        defaults.bool(forKey: Keys.didRate)
    }

    /// Call after Home is visible, onboarding is finished, or the app returns.
    func scheduleDayTwoPromptIfNeeded() {
        pendingTrigger = "launch"
        armPrompt(delayNanoseconds: 2_500_000_000)
    }

    /// Seed the counter from logs that existed before this tracker shipped.
    func backfillIfNeeded(nonHolidayMarkCount: Int) {
        guard defaults.bool(forKey: Keys.didBackfillMarks) == false else { return }
        defaults.set(true, forKey: Keys.didBackfillMarks)
        let current = attendanceMarkCount
        if nonHolidayMarkCount > current {
            defaults.set(nonHolidayMarkCount, forKey: Keys.markCount)
        }
        AnalyticsService.shared.setUserProperty(
            "\(min(max(nonHolidayMarkCount, current), 99))",
            forName: "review_mark_count"
        )
    }

    /// Count a new non-holiday attendance log. Asks on the 5th, 10th, 15th, …
    func recordAttendanceMark(isNewEntry: Bool) {
        guard isNewEntry else { return }

        let count = attendanceMarkCount + 1
        defaults.set(count, forKey: Keys.markCount)
        AnalyticsService.shared.setUserProperty("\(min(count, 99))", forName: "review_mark_count")

        if count == Self.minMarks {
            AnalyticsService.shared.log(.reviewAskUnlocked(markCount: count))
        }
        guard Self.isAskMilestone(count) else { return }
        pendingTrigger = count == Self.minMarks ? "fifth_mark" : "every_5_marks"
        armPrompt(delayNanoseconds: 5_000_000_000)
    }

    func handleRated() {
        guard didConsumeCurrentPrompt == false else { return }
        didConsumeCurrentPrompt = true
        defaults.set(true, forKey: Keys.didRate)
        AnalyticsService.shared.setUserProperty("yes", forName: "review_funnel")
        markPromptConsumed()
        logPromptAction(action: "yes")
        Task {
            _ = await AppStoreReviewOpener.openWriteReview()
        }
    }

    func handleDismissed() {
        guard didConsumeCurrentPrompt == false else { return }
        didConsumeCurrentPrompt = true
        markPromptConsumed()
        logPromptAction(action: "later")
    }

    /// Settings → Rate Us already opened the store — stop nagging.
    func markRatedFromSettings() {
        defaults.set(true, forKey: Keys.didRate)
        AnalyticsService.shared.setUserProperty("yes", forName: "review_funnel")
        shouldPresentDayTwoPrompt = false
        evaluateTask?.cancel()
    }

    /// Apple's in-app stars sheet. Use only when the custom ask is not eligible.
    var canRequestNativeReview: Bool {
        guard defaults.bool(forKey: Keys.didRate) == false else { return false }
        guard AnalyticsService.shared.hasMarkedAtLeastOnce else { return false }
        guard AttendanceViewModel.appSessionCount >= 2 else { return false }
        guard isEligible == false else { return false }
        guard shouldPresentDayTwoPrompt == false else { return false }
        guard let last = defaults.object(forKey: Keys.lastNativeAt) as? Date else {
            return true
        }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return days >= Self.nativeReviewMinDays
    }

    func markNativeReviewRequested() {
        defaults.set(Date(), forKey: Keys.lastNativeAt)
    }

    private func armPrompt(delayNanoseconds: UInt64) {
        guard isEligible else { return }

        evaluateTask?.cancel()
        evaluateTask = Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            for _ in 0..<16 {
                guard Task.isCancelled == false else { return }
                if AdMobFullScreenGate.isOccupied {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    continue
                }
                guard isEligible else { return }
                presentPrompt()
                return
            }
        }
    }

    private var promptCount: Int {
        defaults.integer(forKey: Keys.promptCount)
    }

    private var isEligible: Bool {
        guard shouldPresentDayTwoPrompt == false else { return false }
        guard UserDefaults.standard.bool(forKey: "onboarding.didComplete") else { return false }
        guard defaults.bool(forKey: Keys.didRate) == false else { return false }
        let count = attendanceMarkCount
        guard Self.isAskMilestone(count) else { return false }
        guard defaults.integer(forKey: Keys.lastPromptedMarkCount) < count else { return false }
        // Screenshot / debug seeding still uses snooze; Later no longer writes it.
        if let snooze = defaults.object(forKey: Keys.snoozeUntil) as? Date, Date() < snooze {
            return false
        }
        return true
    }

    private static func isAskMilestone(_ count: Int) -> Bool {
        count >= minMarks && count % minMarks == 0
    }

    private func presentPrompt() {
        didConsumeCurrentPrompt = false
        let next = promptCount + 1
        defaults.set(next, forKey: Keys.promptCount)
        defaults.set(attendanceMarkCount, forKey: Keys.lastPromptedMarkCount)
        shouldPresentDayTwoPrompt = true
        AnalyticsService.shared.setUserProperty("asking", forName: "review_funnel")
        AnalyticsService.shared.log(.dayTwoReviewPromptShown(
            promptCount: next,
            markCount: attendanceMarkCount,
            trigger: pendingTrigger
        ))
        AnalyticsService.shared.log(.reviewAskShown(
            markCount: attendanceMarkCount,
            promptCount: next,
            trigger: pendingTrigger
        ))
    }

    private func logPromptAction(action: String) {
        AnalyticsService.shared.log(.dayTwoReviewPromptAction(
            action: action,
            promptCount: promptCount,
            markCount: attendanceMarkCount
        ))
        AnalyticsService.shared.log(.reviewAskAction(
            action: action,
            markCount: attendanceMarkCount,
            promptCount: promptCount
        ))
    }

    private func markPromptConsumed() {
        shouldPresentDayTwoPrompt = false
        evaluateTask?.cancel()
    }
}
