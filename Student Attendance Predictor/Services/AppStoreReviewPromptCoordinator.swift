//
//  AppStoreReviewPromptCoordinator.swift
//  Student Attendance Predictor
//
//  Repeating review ask after a real mark. "Not now" snoozes; Rate stops it.
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
    }

    /// Soft note from the developer. Written reviews come from this path.
    static let minHoursBetweenPrompts: Double = 24
    #if DEBUG
    static let maxPrompts = 10
    static let nativeReviewMinDays = 3
    #else
    static let maxPrompts = 8
    static let nativeReviewMinDays = 7
    #endif

    private var evaluateTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private var didConsumeCurrentPrompt = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Call after Home is visible, onboarding is finished, or the user marked.
    func scheduleDayTwoPromptIfNeeded() {
        armPrompt(delayNanoseconds: 2_500_000_000)
    }

    /// Happier moment than a cold launch — ask after Attend (not Missed / holiday).
    func notePositiveMoment() {
        // Sit behind mark celebration / paywall so two dialogs don't stack.
        armPrompt(delayNanoseconds: 5_000_000_000)
    }

    func handleRated() {
        guard didConsumeCurrentPrompt == false else { return }
        didConsumeCurrentPrompt = true
        defaults.set(true, forKey: Keys.didRate)
        markPromptConsumed()
        AnalyticsService.shared.log(.dayTwoReviewPromptAction(action: "rated", promptCount: promptCount))
        Task {
            _ = await AppStoreReviewOpener.openWriteReview()
        }
    }

    func handleDismissed() {
        guard didConsumeCurrentPrompt == false else { return }
        didConsumeCurrentPrompt = true
        markPromptConsumed()
        let snooze = Date().addingTimeInterval(Self.minHoursBetweenPrompts * 60 * 60)
        defaults.set(snooze, forKey: Keys.snoozeUntil)
        AnalyticsService.shared.log(.dayTwoReviewPromptAction(action: "dismissed", promptCount: promptCount))
    }

    /// Settings → Rate Us already opened the store — stop nagging.
    func markRatedFromSettings() {
        defaults.set(true, forKey: Keys.didRate)
        shouldPresentDayTwoPrompt = false
        evaluateTask?.cancel()
    }

    /// Apple's in-app stars sheet. Use only when the custom ask is on snooze.
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
        guard AnalyticsService.shared.hasMarkedAtLeastOnce else { return false }
        guard promptCount < Self.maxPrompts else { return false }
        if let snooze = defaults.object(forKey: Keys.snoozeUntil) as? Date, Date() < snooze {
            return false
        }
        return true
    }

    private func presentPrompt() {
        didConsumeCurrentPrompt = false
        let next = promptCount + 1
        defaults.set(next, forKey: Keys.promptCount)
        shouldPresentDayTwoPrompt = true
        AnalyticsService.shared.log(.dayTwoReviewPromptShown(promptCount: next))
    }

    private func markPromptConsumed() {
        shouldPresentDayTwoPrompt = false
        evaluateTask?.cancel()
    }
}
