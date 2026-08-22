//
//  AppStoreReviewPromptCoordinator.swift
//  Student Attendance Predictor
//
//  One-time review prompt starting on the user's second calendar day.
//

import Combine
import Foundation

@MainActor
final class AppStoreReviewPromptCoordinator: ObservableObject {
    static let shared = AppStoreReviewPromptCoordinator()

    @Published var shouldPresentDayTwoPrompt = false

    private enum Keys {
        static let didShowDayTwo = "review.didShowDayTwo"
    }

    private var evaluateTask: Task<Void, Never>?

    private init() {}

    /// Call after Home is visible and onboarding is finished.
    func scheduleDayTwoPromptIfNeeded() {
        guard isEligible else { return }

        evaluateTask?.cancel()
        evaluateTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard Task.isCancelled == false, isEligible else { return }
            shouldPresentDayTwoPrompt = true
            AnalyticsService.shared.log(.dayTwoReviewPromptShown)
        }
    }

    func handleRated() {
        markShown()
        AnalyticsService.shared.log(.dayTwoReviewPromptAction(action: "rated"))
        Task {
            _ = await AppStoreReviewOpener.openWriteReview()
        }
    }

    func handleDismissed() {
        markShown()
        AnalyticsService.shared.log(.dayTwoReviewPromptAction(action: "dismissed"))
    }

    private var isEligible: Bool {
        guard UserDefaults.standard.bool(forKey: "onboarding.didComplete") else { return false }
        guard UserDefaults.standard.bool(forKey: Keys.didShowDayTwo) == false else { return false }
        guard AnalyticsService.shared.daysSinceInstall >= 1 else { return false }
        return true
    }

    private func markShown() {
        UserDefaults.standard.set(true, forKey: Keys.didShowDayTwo)
        shouldPresentDayTwoPrompt = false
        evaluateTask?.cancel()
    }

    var dayTwoPromptMessage: String {
        let first = NotificationPersonalization.firstName()
        if first.isEmpty {
            return "A quick App Store rating helps other students discover Bunk Planner."
        }
        return "\(first), a quick App Store rating helps other students discover Bunk Planner."
    }
}
