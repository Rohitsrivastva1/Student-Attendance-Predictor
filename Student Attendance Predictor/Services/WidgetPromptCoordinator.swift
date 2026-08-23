//
//  WidgetPromptCoordinator.swift
//  Student Attendance Predictor
//
//  One-time widget install prompt after first mark — callable from any mark path.
//

import Foundation
import Combine

@MainActor
final class WidgetPromptCoordinator: ObservableObject {
    static let shared = WidgetPromptCoordinator()

    @Published private(set) var shouldPresent = false

    private let defaultsKey = "prompt.widgetAfterFirstMark"
    private let defaults = UserDefaults.standard

    func evaluateAfterMark() {
        guard defaults.bool(forKey: defaultsKey) == false else { return }
        defaults.set(true, forKey: defaultsKey)
        AnalyticsService.shared.log(.widgetPromptShown)
        shouldPresent = true
    }

    func clear() {
        shouldPresent = false
    }

    #if DEBUG
    func resetForDebug() {
        defaults.set(false, forKey: defaultsKey)
        shouldPresent = false
    }
    #endif

    /// Promo card can re-surface widget instructions even after first-mark prompt fired.
    func presentInstructions() {
        shouldPresent = true
    }
}
