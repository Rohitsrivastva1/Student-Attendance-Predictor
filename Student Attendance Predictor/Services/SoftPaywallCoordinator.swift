//
//  SoftPaywallCoordinator.swift
//  Student Attendance Predictor
//
//  Soft paywalls at high-intent moments. Dismissible Pro sheet only —
//  never a hard block. Auto sheets wait for engagement (marks or session time)
//  so the paywall does not appear on cold open.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class SoftPaywallCoordinator: ObservableObject {
    static let shared = SoftPaywallCoordinator()

    /// When set, HomeView should present `ProPaywallView` with this analytics source.
    @Published private(set) var pendingSource: String?

    #if DEBUG
    static let streakThreshold = 2
    static let cooldownHours: Double = 24
    static let habitValueMinDays = 1
    static let atRiskWeekThreshold = 1
    /// Faster gate while developing.
    static let minDaysBeforeAtRiskSoftPaywall = 1
    static let minMarksBeforeSoftPaywall = 2
    static let minSessionSecondsBeforeSoftPaywall: TimeInterval = 45
    #else
    static let streakThreshold = 7
    /// 48h — 5-day cooldown cut paywall views ~40% and sales went to zero.
    static let cooldownHours: Double = 2 * 24
    /// Earliest day to auto-show habit paywall (after first value, not install day).
    static let habitValueMinDays = 5
    /// First at-risk week can auto-present soft paywall (revenue bet / Start CTA ship).
    static let atRiskWeekThreshold = 1
    /// Earliest day for at-risk auto soft paywall (protect day-0/1 habit loop).
    static let minDaysBeforeAtRiskSoftPaywall = 2
    /// Wait for real use before any auto soft paywall on launch.
    static let minMarksBeforeSoftPaywall = 3
    static let minSessionSecondsBeforeSoftPaywall: TimeInterval = 7 * 60
    #endif

    private let defaults: UserDefaults
    private let lastShownKey = "paywall.lastShownAt"
    private let atRiskWeekKeysKey = "paywall.atRiskWeekKeys"
    /// Legacy once-forever flags — still read so we don't immediately spam on update.
    private let didShowStreak7Key = "paywall.didShowStreak7"
    private let didShowAtRiskWeek3Key = "paywall.didShowAtRiskWeek3"
    private let didShowSubjectLimitKey = "paywall.didShowSubjectLimit"
    private let didShowLockedForecastKey = "paywall.didShowLockedForecast"
    private let didShowHabitValueKey = "paywall.didShowHabitValue"
    private let sessionAccumulatedKey = "paywall.sessionAccumulatedSeconds"

    private var sessionStartedAt: Date?
    private var accumulatedSessionSeconds: TimeInterval = 0
    private var engagementWaitTask: Task<Void, Never>?
    private var lifecycleObservers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accumulatedSessionSeconds = defaults.double(forKey: sessionAccumulatedKey)
        observeLifecycle()
    }

    deinit {
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func clearPending() {
        pendingSource = nil
    }

    /// Call from ProPaywallView.onAppear so cooldown only starts when the sheet is visible.
    func confirmPresented(source: String) {
        markShown(source: source)
    }

    /// Start / resume session clock when Home is visible.
    func noteHomeAppeared() {
        beginSessionIfNeeded()
        scheduleEngagementRecheckIfNeeded()
    }

    /// Call after Mark Today when attendance streak may have changed.
    func evaluateAfterDayMarked(streak: Int) {
        guard AdEntitlementsStore.shared.hasProFeatures == false else { return }
        guard pendingSource == nil else { return }
        guard hasMetEngagementGate else { return }
        guard cooldownElapsed else { return }
        guard streak >= Self.streakThreshold else { return }
        queue(source: "streak_7")
    }

    /// Call when the user has any at-risk subject (after marks / recalculation).
    func recordAtRiskWeekIfNeeded(isAtRisk: Bool) {
        guard isAtRisk else { return }
        guard AdEntitlementsStore.shared.hasProFeatures == false else { return }

        let weekKey = Self.currentISOWeekKey()
        var weeks = Set(defaults.stringArray(forKey: atRiskWeekKeysKey) ?? [])
        _ = weeks.insert(weekKey).inserted
        defaults.set(Array(weeks).sorted(), forKey: atRiskWeekKeysKey)
        presentAtRiskPaywallIfReady()
    }

    /// Home appear: once per install after value + engagement — never on cold open alone.
    func evaluateHabitValuePaywall(daysSinceInstall: Int, hasMarkedDay: Bool) {
        beginSessionIfNeeded()
        guard AdEntitlementsStore.shared.hasProFeatures == false else { return }
        guard pendingSource == nil else { return }
        guard hasMarkedDay else { return }
        guard daysSinceInstall >= Self.habitValueMinDays else { return }
        guard defaults.bool(forKey: didShowHabitValueKey) == false else { return }
        guard cooldownElapsed else { return }
        guard hasMetEngagementGate else {
            scheduleEngagementRecheckIfNeeded()
            return
        }
        queue(source: "habit_value")
    }

    /// Once per cooldown when free subject cap is hit. Returns `true` if the
    /// caller should auto-present Pro now (instead of only showing an alert).
    /// User-initiated — not gated by session time.
    @discardableResult
    func consumeSubjectLimitTrigger() -> Bool {
        guard AdEntitlementsStore.shared.hasProFeatures == false else { return false }
        let firstTime = defaults.bool(forKey: didShowSubjectLimitKey) == false
        if firstTime {
            defaults.set(true, forKey: didShowSubjectLimitKey)
            AnalyticsService.shared.log(
                .softPaywallTriggered(
                    source: "subject_limit",
                    daysSinceInstall: AnalyticsService.shared.daysSinceInstall,
                    markCount: attendanceMarkCount,
                    sessionSeconds: Int(currentSessionSeconds)
                )
            )
            return true
        }
        guard cooldownElapsed else { return false }
        AnalyticsService.shared.log(
            .softPaywallTriggered(
                source: "subject_limit",
                daysSinceInstall: AnalyticsService.shared.daysSinceInstall,
                markCount: attendanceMarkCount,
                sessionSeconds: Int(currentSessionSeconds)
            )
        )
        return true
    }

    private func presentAtRiskPaywallIfReady() {
        guard pendingSource == nil else { return }
        guard AdEntitlementsStore.shared.hasProFeatures == false else { return }
        // Protect W1 habit loop — don't auto soft-paywall on day 0–1 from at-risk alone.
        guard AnalyticsService.shared.daysSinceInstall >= Self.minDaysBeforeAtRiskSoftPaywall else { return }
        guard hasMetEngagementGate else {
            scheduleEngagementRecheckIfNeeded()
            return
        }
        guard atRiskWeekCount >= Self.atRiskWeekThreshold else { return }
        guard cooldownElapsed else { return }
        let source = atRiskWeekCount >= 3 ? "at_risk_week_3" : "at_risk_week"
        queue(source: source)
    }

    func shouldPresentStreakPaywall(streak: Int) -> Bool {
        AdEntitlementsStore.shared.hasProFeatures == false
            && hasMetEngagementGate
            && cooldownElapsed
            && streak >= Self.streakThreshold
    }

    func shouldPresentAtRiskPaywall() -> Bool {
        AdEntitlementsStore.shared.hasProFeatures == false
            && hasMetEngagementGate
            && cooldownElapsed
            && atRiskWeekCount >= Self.atRiskWeekThreshold
    }

    /// 3 Attend/Missed marks **or** ~7 minutes of active session.
    var hasMetEngagementGate: Bool {
        if attendanceMarkCount >= Self.minMarksBeforeSoftPaywall { return true }
        return currentSessionSeconds >= Self.minSessionSecondsBeforeSoftPaywall
    }

    private var attendanceMarkCount: Int {
        AppStoreReviewPromptCoordinator.shared.attendanceMarkCount
    }

    private var currentSessionSeconds: TimeInterval {
        var total = accumulatedSessionSeconds
        if let started = sessionStartedAt {
            total += Date().timeIntervalSince(started)
        }
        return total
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
        pendingSource = source
        AnalyticsService.shared.log(
            .softPaywallTriggered(
                source: source,
                daysSinceInstall: AnalyticsService.shared.daysSinceInstall,
                markCount: attendanceMarkCount,
                sessionSeconds: Int(currentSessionSeconds)
            )
        )
        ProPurchaseService.shared.start()
        Task { await ProPurchaseService.shared.loadProduct() }
    }

    private func markShown(source: String) {
        defaults.set(Date(), forKey: lastShownKey)
        switch source {
        case "streak_7":
            defaults.set(true, forKey: didShowStreak7Key)
        case "at_risk_week", "at_risk_week_3":
            defaults.set(true, forKey: didShowAtRiskWeek3Key)
        case "locked_forecast":
            defaults.set(true, forKey: didShowLockedForecastKey)
        case "habit_value":
            defaults.set(true, forKey: didShowHabitValueKey)
        case "subject_limit":
            defaults.set(true, forKey: didShowSubjectLimitKey)
        default:
            break
        }
    }

    private func beginSessionIfNeeded() {
        if sessionStartedAt == nil {
            sessionStartedAt = Date()
        }
    }

    private func pauseSession() {
        guard let started = sessionStartedAt else { return }
        accumulatedSessionSeconds += Date().timeIntervalSince(started)
        defaults.set(accumulatedSessionSeconds, forKey: sessionAccumulatedKey)
        sessionStartedAt = nil
    }

    private func scheduleEngagementRecheckIfNeeded() {
        guard hasMetEngagementGate == false else { return }
        engagementWaitTask?.cancel()
        let remaining = max(
            1,
            Self.minSessionSecondsBeforeSoftPaywall - currentSessionSeconds
        )
        engagementWaitTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard let self, Task.isCancelled == false else { return }
            guard self.hasMetEngagementGate else { return }
            self.evaluateHabitValuePaywall(
                daysSinceInstall: AnalyticsService.shared.daysSinceInstall,
                hasMarkedDay: AnalyticsService.shared.hasMarkedAtLeastOnce
            )
            self.presentAtRiskPaywallIfReady()
        }
    }

    private func observeLifecycle() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.pauseSession() }
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.beginSessionIfNeeded()
                    self?.scheduleEngagementRecheckIfNeeded()
                }
            }
        )
        #endif
    }

    static func currentISOWeekKey(date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }
}
