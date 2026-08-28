//
//  SoftPaywallCoordinator.swift
//  Student Attendance Predictor
//
//  Soft paywalls at high-intent moments. Dismissible Pro sheet only —
//  never a hard block. Re-prompts on a cooldown so a skipped sheet
//  is not a lifetime miss.
//

import Foundation
import Combine

@MainActor
final class SoftPaywallCoordinator: ObservableObject {
    static let shared = SoftPaywallCoordinator()

    /// When set, HomeView should present `ProPaywallView` with this analytics source.
    @Published private(set) var pendingSource: String?

    #if DEBUG
    static let streakThreshold = 2
    static let cooldownHours: Double = 24
    static let habitValueMinDays = 1
    #else
    static let streakThreshold = 7
    /// 48h — 5-day cooldown cut paywall views ~40% and sales went to zero.
    static let cooldownHours: Double = 2 * 24
    /// Earliest day to auto-show habit paywall (after first value, not install day).
    static let habitValueMinDays = 5
    #endif

    private let defaults: UserDefaults
    private let lastShownKey = "paywall.lastShownAt"
    private let atRiskWeekKeysKey = "paywall.atRiskWeekKeys"
    /// Legacy once-forever flags — still read so we don't immediately spam on update.
    private let didShowStreak7Key = "paywall.didShowStreak7"
    private let didShowAtRiskWeek3Key = "paywall.didShowAtRiskWeek3"
    private let didShowSubjectLimitKey = "paywall.didShowSubjectLimit"
    private let didShowLockedForecastKey = "paywall.didShowLockedForecast"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func clearPending() {
        pendingSource = nil
    }

    /// Call after Mark Today when attendance streak may have changed.
    func evaluateAfterDayMarked(streak: Int) {
        guard AdEntitlementsStore.shared.isPro == false else { return }
        guard pendingSource == nil else { return }
        guard cooldownElapsed else { return }
        guard streak >= Self.streakThreshold else { return }
        queue(source: "streak_7")
    }

    /// Call when the user has any at-risk subject (after marks / recalculation).
    func recordAtRiskWeekIfNeeded(isAtRisk: Bool) {
        guard isAtRisk else { return }
        guard AdEntitlementsStore.shared.isPro == false else { return }

        let weekKey = Self.currentISOWeekKey()
        var weeks = Set(defaults.stringArray(forKey: atRiskWeekKeysKey) ?? [])
        _ = weeks.insert(weekKey).inserted
        defaults.set(Array(weeks).sorted(), forKey: atRiskWeekKeysKey)
        presentAtRiskPaywallIfReady()
    }

    /// Home appear: users who marked at least once and had a few days of value — not fresh installs.
    func evaluateHabitValuePaywall(daysSinceInstall: Int, hasMarkedDay: Bool) {
        guard AdEntitlementsStore.shared.isPro == false else { return }
        guard pendingSource == nil else { return }
        guard hasMarkedDay else { return }
        guard daysSinceInstall >= Self.habitValueMinDays else { return }
        guard cooldownElapsed else { return }
        queue(source: "habit_value")
    }

    /// Once per cooldown when free subject cap is hit. Returns `true` if the
    /// caller should auto-present Pro now (instead of only showing an alert).
    @discardableResult
    func consumeSubjectLimitTrigger() -> Bool {
        guard AdEntitlementsStore.shared.isPro == false else { return false }
        let firstTime = defaults.bool(forKey: didShowSubjectLimitKey) == false
        if firstTime {
            defaults.set(true, forKey: didShowSubjectLimitKey)
            AnalyticsService.shared.log(.softPaywallTriggered(source: "subject_limit"))
            markShown(source: "subject_limit")
            return true
        }
        guard cooldownElapsed else { return false }
        AnalyticsService.shared.log(.softPaywallTriggered(source: "subject_limit"))
        markShown(source: "subject_limit")
        return true
    }

    private func presentAtRiskPaywallIfReady() {
        guard pendingSource == nil else { return }
        guard AdEntitlementsStore.shared.isPro == false else { return }
        guard atRiskWeekCount >= 1 else { return }
        guard cooldownElapsed else { return }
        let source = atRiskWeekCount >= 3 ? "at_risk_week_3" : "at_risk_week"
        queue(source: source)
    }

    func shouldPresentStreakPaywall(streak: Int) -> Bool {
        AdEntitlementsStore.shared.isPro == false
            && cooldownElapsed
            && streak >= Self.streakThreshold
    }

    func shouldPresentAtRiskPaywall() -> Bool {
        AdEntitlementsStore.shared.isPro == false
            && cooldownElapsed
            && atRiskWeekCount >= 1
    }

    private var atRiskWeekCount: Int {
        (defaults.stringArray(forKey: atRiskWeekKeysKey) ?? []).count
    }

    private var cooldownElapsed: Bool {
        guard let last = defaults.object(forKey: lastShownKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= Self.cooldownHours * 3600
    }

    private func queue(source: String) {
        markShown(source: source)
        pendingSource = source
        AnalyticsService.shared.log(.softPaywallTriggered(source: source))
    }

    private func markShown(source: String) {
        defaults.set(Date(), forKey: lastShownKey)
        // Only stamp the flag for this trigger — writing every legacy key
        // from habit_value / subject_limit permanently suppressed other prompts.
        switch source {
        case "streak_7":
            defaults.set(true, forKey: didShowStreak7Key)
        case "at_risk_week", "at_risk_week_3":
            defaults.set(true, forKey: didShowAtRiskWeek3Key)
        case "locked_forecast":
            defaults.set(true, forKey: didShowLockedForecastKey)
        default:
            break
        }
    }

    static func currentISOWeekKey(date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }
}
