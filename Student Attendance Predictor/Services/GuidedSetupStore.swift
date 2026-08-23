//
//  GuidedSetupStore.swift
//  Student Attendance Predictor
//
//  First-run coach marks: add a subject → Mark Today.
//

import Foundation
import Combine

enum GuidedSetupStep: String, Equatable {
    case addSubject
    case markToday
}

@MainActor
final class GuidedSetupStore: ObservableObject {
    static let shared = GuidedSetupStore()

    @Published private(set) var activeStep: GuidedSetupStep?

    private enum Keys {
        static let completed = "guided.didComplete"
        static let didLogStarted = "guided.didLogStarted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether the user has meaningful attendance data (Mark Today or legacy log).
    static func hasUserMarked(subjectCount: Int, hasAnalyticsMark: Bool, hasLegacyAttendance: Bool) -> Bool {
        guard subjectCount > 0 else { return false }
        return hasAnalyticsMark || hasLegacyAttendance
    }

    func refresh(subjectCount: Int, hasMarked: Bool) {
        guard defaults.bool(forKey: Keys.completed) == false else {
            activeStep = nil
            return
        }
        guard UserDefaults.standard.bool(forKey: "onboarding.didComplete") else {
            activeStep = nil
            return
        }

        if hasMarked {
            finishFlow(logCompleted: AnalyticsService.shared.hasMarkedAtLeastOnce)
            return
        }

        if subjectCount == 0 {
            showStep(.addSubject)
            return
        }

        showStep(.markToday)
    }

    /// Call when onboarding finishes so the coach mark can appear on first Home visit.
    func refreshAfterOnboarding(subjectCount: Int, hasMarked: Bool) {
        refresh(subjectCount: subjectCount, hasMarked: hasMarked)
    }

    func subjectWasAdded() {
        guard defaults.bool(forKey: Keys.completed) == false else { return }
        guard UserDefaults.standard.bool(forKey: "onboarding.didComplete") else { return }
        showStep(.markToday)
    }

    func complete() {
        finishFlow(logCompleted: true)
    }

    func dismiss(step: GuidedSetupStep) {
        AnalyticsService.shared.log(.guidedSetupDismissed(step: step.rawValue))
        finishFlow(logCompleted: false)
    }

    /// Returning users with attendance history — skip coach marks without a completion event.
    func markCompleteSilently() {
        finishFlow(logCompleted: false)
    }

    #if DEBUG
    func resetForDebug() {
        defaults.set(false, forKey: Keys.completed)
        defaults.set(false, forKey: Keys.didLogStarted)
        activeStep = nil
    }
    #endif

    private func showStep(_ step: GuidedSetupStep) {
        guard activeStep != step else { return }
        activeStep = step
        logStartedIfNeeded()
        AnalyticsService.shared.log(.guidedSetupStepShown(step: step.rawValue))
    }

    private func finishFlow(logCompleted: Bool) {
        guard defaults.bool(forKey: Keys.completed) == false else {
            activeStep = nil
            return
        }
        defaults.set(true, forKey: Keys.completed)
        activeStep = nil
        if logCompleted {
            AnalyticsService.shared.log(.guidedSetupCompleted)
        }
    }

    private func logStartedIfNeeded() {
        guard defaults.bool(forKey: Keys.didLogStarted) == false else { return }
        defaults.set(true, forKey: Keys.didLogStarted)
        AnalyticsService.shared.log(.guidedSetupStarted)
    }
}
