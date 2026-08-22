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
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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

        if subjectCount == 0 {
            if activeStep != .addSubject {
                activeStep = .addSubject
                AnalyticsService.shared.log(.guidedSetupStepShown(step: GuidedSetupStep.addSubject.rawValue))
            }
            return
        }

        if hasMarked == false {
            if activeStep != .markToday {
                activeStep = .markToday
                AnalyticsService.shared.log(.guidedSetupStepShown(step: GuidedSetupStep.markToday.rawValue))
            }
            return
        }

        complete()
    }

    func subjectWasAdded() {
        guard activeStep == .addSubject else { return }
        activeStep = .markToday
        AnalyticsService.shared.log(.guidedSetupStepShown(step: GuidedSetupStep.markToday.rawValue))
    }

    func complete() {
        guard defaults.bool(forKey: Keys.completed) == false else {
            activeStep = nil
            return
        }
        defaults.set(true, forKey: Keys.completed)
        activeStep = nil
        AnalyticsService.shared.log(.guidedSetupCompleted)
    }
}
