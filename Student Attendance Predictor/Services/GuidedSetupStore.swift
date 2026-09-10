//
//  GuidedSetupStore.swift
//  Student Attendance Predictor
//
//  First-run coach marks: add a subject → set class days → Mark Today.
//

import Foundation
import Combine

enum GuidedSetupStep: String, Equatable {
    case addSubject
    case setClassDays
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

    func refresh(subjectCount: Int, hasMarked: Bool, hasClassDays: Bool = true, hasSomethingToMark: Bool = true) {
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

        if hasClassDays == false {
            showStep(.setClassDays)
            return
        }

        if hasSomethingToMark == false {
            activeStep = nil
            return
        }

        showStep(.markToday)
    }

    /// Call when onboarding finishes so the coach mark can appear on first Home visit.
    func refreshAfterOnboarding(subjectCount: Int, hasMarked: Bool, hasClassDays: Bool = true, hasSomethingToMark: Bool = true) {
        refresh(
            subjectCount: subjectCount,
            hasMarked: hasMarked,
            hasClassDays: hasClassDays,
            hasSomethingToMark: hasSomethingToMark
        )
    }

    func subjectWasAdded() {
        guard defaults.bool(forKey: Keys.completed) == false else { return }
        guard UserDefaults.standard.bool(forKey: "onboarding.didComplete") else { return }
        showStep(.setClassDays)
    }

    func complete() {
        finishFlow(logCompleted: true)
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
            NotificationService.requestAuthorizationIfNeeded()
        }
    }

    private func logStartedIfNeeded() {
        guard defaults.bool(forKey: Keys.didLogStarted) == false else { return }
        defaults.set(true, forKey: Keys.didLogStarted)
        AnalyticsService.shared.log(.guidedSetupStarted)
    }
}
