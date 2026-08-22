//
//  AnalyticsService.swift
//  Student Attendance Predictor
//
//  Central product-analytics facade. The rest of the app only ever calls
//  `AnalyticsService.shared.log(...)` / `.setScreen(...)`; this type owns the
//  anonymous identity, session lifecycle, screen/navigation state, common
//  metadata, and fans events out to all registered backends.
//
//  This app has NO login, so there is no real user identity. We generate a
//  stable anonymous device id (persisted in UserDefaults) and treat each
//  foreground period as a session.
//
//  ─────────────────────────────────────────────────────────────────────────
//  FIREBASE_SETUP (one-time, do this in Xcode):
//  1. File ▸ Add Package Dependencies… ▸ https://github.com/firebase/firebase-ios-sdk
//  2. Add the product "FirebaseAnalytics" to the app target.
//  3. Download GoogleService-Info.plist from the Firebase console and drag it
//     into the "Student Attendance Predictor" folder (added to the app target).
//  Once those exist, `canImport(FirebaseAnalytics)` becomes true and analytics
//  starts flowing automatically — no other code changes needed.
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Captured as early as possible so we can measure cold-launch time.
enum AppLaunchClock {
    static let start = Date()
}

final class AnalyticsService {
    static let shared = AnalyticsService()

    // MARK: Identity
    let userId: String
    let isFirstLaunch: Bool

    // MARK: Session state
    private(set) var sessionId = UUID().uuidString
    private var sessionStartedAt: Date?
    private var lastBackgroundedAt: Date?
    private var didLogLaunch = false
    /// When the user last tapped a notification, used to attribute app-open source.
    private var notificationOpenedAt: Date?
    /// How close a notification tap must be to a session start to count as the open source.
    private let notificationOpenWindow: TimeInterval = 5

    // MARK: Screen state
    private(set) var currentScreen: AppScreen?
    private var previousScreen: AppScreen?
    private var screenEnteredAt: Date?

    // MARK: Backends
    private var backends: [AnalyticsBackend] = []
    private var isStarted = false

    private let defaults: UserDefaults

    private enum Keys {
        static let userId = "analytics.userId"
        static let didLaunchBefore = "analytics.didLaunchBefore"
        static let installDate = "analytics.installDate"
        static let lastSessionEnd = "analytics.lastSessionEnd"
        static let sessionsTodayCount = "analytics.sessionsTodayCount"
        static let sessionsTodayDay = "analytics.sessionsTodayDay"
        static let streakDays = "analytics.streakDays"
        static let streakLastDay = "analytics.streakLastDay"
        static let didLogFirstMark = "analytics.didLogFirstMark"
        static let didLogRetentionDay7 = "analytics.didLogRetentionDay7"
        static let didLogRetentionDay30 = "analytics.didLogRetentionDay30"
        static let activeWeekKey = "analytics.activeWeekKey"
        static let activeDaysInWeek = "analytics.activeDaysInWeek"
        static let lastLoggedWeeklyActiveDays = "analytics.lastLoggedWeeklyActiveDays"
        static let lastProPaywallSource = "analytics.lastProPaywallSource"
    }

    private var sessionBannerImpressions = 0
    private var sessionInterstitialImpressions = 0
    private var sessionAppOpenImpressions = 0
    private var sessionInterstitialInsights = 0
    private var sessionInterstitialOverview = 0
    private var sessionInterstitialSubjects = 0
    private var sessionInterstitialOther = 0
    private var sessionBannerClicks = 0
    private var sessionInterstitialClicks = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let existing = defaults.string(forKey: Keys.userId) {
            userId = existing
            isFirstLaunch = defaults.bool(forKey: Keys.didLaunchBefore) == false
        } else {
            let generated = UUID().uuidString
            defaults.set(generated, forKey: Keys.userId)
            defaults.set(Date(), forKey: Keys.installDate)
            userId = generated
            isFirstLaunch = true
        }
        defaults.set(true, forKey: Keys.didLaunchBefore)
    }

    // MARK: - Start

    /// Registers backends and identity. Call once, as early as possible (App.init),
    /// after FirebaseApp.configure() has run.
    func start() {
        guard isStarted == false else { return }
        isStarted = true

        #if canImport(FirebaseAnalytics)
        backends.append(FirebaseAnalyticsBackend())
        #endif
        #if DEBUG
        backends.append(ConsoleAnalyticsBackend())
        #endif

        backends.forEach { $0.setCollectionEnabled(true) }
        setUserID(userId)
        applyUserProperty(Self.deviceModel, forName: "device_model")
        applyUserProperty(Self.osVersion, forName: "os_version")
        applyUserProperty(Self.appVersion, forName: "app_version")
        applyUserProperty(Self.appBuild, forName: "app_build")
        applyUserProperty(daysSinceInstallBucket, forName: "days_since_install")

        if isFirstLaunch {
            log(.appFirstLaunch)
        }
    }

    // MARK: - Logging

    /// Surfaces that already logged `pro_cta_shown` this process — avoids inflating
    /// impression counts when Home/Insights redraw on every tab switch.
    private var proCtaShownThisLaunch = Set<String>()

    func log(_ event: AnalyticsEvent) {
        let name = event.name
        let params = event.parameters
        recordMultiFeatureIfNeeded(for: event)
        runOnMain { [weak self] in
            guard let self else { return }
            var merged = self.commonParameters()
            for (key, value) in params { merged[key] = value }
            for backend in self.backends {
                backend.log(name: name, parameters: merged)
            }
        }
    }

    /// Maps high-value events into weekly multi-feature engagement tracking.
    private func recordMultiFeatureIfNeeded(for event: AnalyticsEvent) {
        switch event {
        case .dayMarked:
            MultiFeatureEngagementStore.record(.mark)
        case .skipPlannerViewed:
            MultiFeatureEngagementStore.record(.skipPlanner)
        case .focusTimerStarted, .postMarkFocusPromptAccepted:
            MultiFeatureEngagementStore.record(.focus)
        case .forecastViewed, .lockedForecastViewed:
            MultiFeatureEngagementStore.record(.forecast)
        case .widgetPromptShown:
            MultiFeatureEngagementStore.record(.widget)
        default:
            break
        }
    }

    /// Logs `pro_cta_shown` at most once per surface per app launch.
    func logProCtaShownOnce(surface: String) {
        runOnMain { [weak self] in
            guard let self else { return }
            guard self.proCtaShownThisLaunch.insert(surface).inserted else { return }
            self.log(.proCtaShown(surface: surface))
        }
    }

    /// Firebase / GA4 standard purchase event so revenue appears in Analytics reports.
    func logPurchase(value: Double, currency: String, productID: String) {
        runOnMain { [weak self] in
            guard let self else { return }
            for backend in self.backends {
                backend.logPurchase(value: value, currency: currency, productID: productID)
            }
        }
    }

    private func setUserID(_ id: String?) {
        backends.forEach { $0.setUserID(id) }
    }

    private func applyUserProperty(_ value: String?, forName name: String) {
        backends.forEach { $0.setUserProperty(value, forName: name) }
    }

    /// Public for `AnalyticsUserProfile` to sync Firebase user properties.
    func setUserProperty(_ value: String?, forName name: String) {
        runOnMain { [weak self] in
            self?.applyUserProperty(value, forName: name)
        }
    }

    var daysSinceInstall: Int {
        guard let installDate = defaults.object(forKey: Keys.installDate) as? Date else {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }

    /// True after the user logs Mark Today at least once (`mark_today_first_use`).
    var hasMarkedAtLeastOnce: Bool {
        defaults.bool(forKey: Keys.didLogFirstMark)
    }

    /// Consecutive days with at least one app session (analytics streak).
    var currentStreakDays: Int {
        defaults.integer(forKey: Keys.streakDays)
    }

    /// Last paywall analytics source — used when StoreKit completes outside the paywall UI.
    func setLastProPaywallSource(_ source: String) {
        defaults.set(source, forKey: Keys.lastProPaywallSource)
    }

    var lastProPaywallSource: String {
        defaults.string(forKey: Keys.lastProPaywallSource) ?? "storekit_update"
    }

    var daysSinceInstallBucket: String {
        switch daysSinceInstall {
        case 0: return "0"
        case 1: return "1"
        case 2...7: return "2-7"
        case 8...30: return "8-30"
        default: return "31+"
        }
    }

    func recordAdImpression(_ type: String, placement: String? = nil) {
        runOnMain { [weak self] in
            guard let self else { return }
            switch type {
            case "banner":
                self.sessionBannerImpressions += 1
            case "interstitial":
                self.sessionInterstitialImpressions += 1
                switch placement {
                case AdMobConfiguration.Placement.afterInsightsOpened:
                    self.sessionInterstitialInsights += 1
                case AdMobConfiguration.Placement.afterOverviewOpened:
                    self.sessionInterstitialOverview += 1
                case AdMobConfiguration.Placement.afterSubjectsOpened:
                    self.sessionInterstitialSubjects += 1
                default:
                    self.sessionInterstitialOther += 1
                }
            case "app_open":
                self.sessionAppOpenImpressions += 1
            case "banner_click":
                self.sessionBannerClicks += 1
            case "interstitial_click":
                self.sessionInterstitialClicks += 1
            default:
                break
            }
        }
    }

    func recordFirstMarkIfNeeded() {
        guard defaults.bool(forKey: Keys.didLogFirstMark) == false else { return }
        defaults.set(true, forKey: Keys.didLogFirstMark)
        NotificationService.cancelDayTwoMarkNudge()
        NotificationService.cancelEveningMarkNudge()
        log(.markTodayFirstUse)
    }

    func recordWeeklyActiveDay() {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: Date())
        let year = calendar.component(.yearForWeekOfYear, from: Date())
        let weekKey = "\(year)-W\(weekOfYear)"
        let todayOrdinal = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0

        let storedWeek = defaults.string(forKey: Keys.activeWeekKey)
        var activeDays = Set(defaults.array(forKey: Keys.activeDaysInWeek) as? [Int] ?? [])
        if storedWeek != weekKey {
            activeDays = []
            defaults.set(weekKey, forKey: Keys.activeWeekKey)
        }
        guard activeDays.contains(todayOrdinal) == false else { return }
        activeDays.insert(todayOrdinal)
        defaults.set(Array(activeDays), forKey: Keys.activeDaysInWeek)

        let count = activeDays.count
        let lastLogged = defaults.integer(forKey: Keys.lastLoggedWeeklyActiveDays)
        guard count != lastLogged else { return }
        defaults.set(count, forKey: Keys.lastLoggedWeeklyActiveDays)
        log(.weeklyActiveDays(count: count))
    }

    func checkRetentionMilestones() {
        guard let installDate = defaults.object(forKey: Keys.installDate) as? Date else { return }
        let days = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0

        if days >= 7, defaults.bool(forKey: Keys.didLogRetentionDay7) == false {
            defaults.set(true, forKey: Keys.didLogRetentionDay7)
            log(.retentionDay7)
        }
        if days >= 30, defaults.bool(forKey: Keys.didLogRetentionDay30) == false {
            defaults.set(true, forKey: Keys.didLogRetentionDay30)
            log(.retentionDay30)
        }
    }

    // MARK: - Screen / navigation tracking

    /// Records a screen transition: logs time-on-screen for the previous screen,
    /// then a screen view (with previous screen) for the new one.
    func setScreen(_ screen: AppScreen) {
        runOnMain { [weak self] in
            guard let self else { return }
            guard screen != self.currentScreen else { return }

            if let current = self.currentScreen, let enteredAt = self.screenEnteredAt {
                self.log(.screenExit(screen: current, secondsSpent: Int(Date().timeIntervalSince(enteredAt))))
            }

            self.previousScreen = self.currentScreen
            self.currentScreen = screen
            self.screenEnteredAt = Date()
            self.log(.screenView(screen: screen, previous: self.previousScreen))
        }
    }

    // MARK: - Lifecycle

    #if canImport(UIKit)
    func handleScenePhase(_ phase: ScenePhaseLike) {
        switch phase {
        case .active:
            handleForeground()
        case .background:
            handleBackground()
        case .inactive:
            break
        }
    }
    #endif

    func handleForeground() {
        runOnMain { [weak self] in
            guard let self else { return }
            if let backgroundedAt = self.lastBackgroundedAt {
                let gap = Int(Date().timeIntervalSince(backgroundedAt))
                self.log(.appForegrounded(secondsSinceBackground: gap))
            }
            if self.sessionStartedAt == nil {
                self.startSession()
            }
        }
    }

    func handleBackground() {
        runOnMain { [weak self] in
            guard let self else { return }
            self.lastBackgroundedAt = Date()
            if self.sessionStartedAt != nil {
                self.log(.appBackgrounded)
                self.endSession()
            }
        }
    }

    /// Call once the first interactive screen is on-screen, to record launch time.
    func appBecameReady() {
        runOnMain { [weak self] in
            guard let self else { return }
            guard self.didLogLaunch == false else { return }
            self.didLogLaunch = true
            let launchMs = Int(Date().timeIntervalSince(AppLaunchClock.start) * 1000)
            self.log(.appLaunched(isReturningUser: !self.isFirstLaunch, launchTimeMs: launchMs))
        }
    }

    /// Called by the notification delegate when the user taps a notification.
    /// Records the tap (for app-open attribution) and logs the open event.
    func handleNotificationOpened(type: String) {
        runOnMain { [weak self] in
            guard let self else { return }
            self.notificationOpenedAt = Date()
            self.log(.notificationOpened(type: type))
        }
    }

    private func startSession() {
        sessionId = UUID().uuidString
        sessionStartedAt = Date()

        let sessionsToday = incrementSessionsToday()
        var secondsSinceLast: Int?
        if let lastEnd = defaults.object(forKey: Keys.lastSessionEnd) as? Date {
            secondsSinceLast = Int(Date().timeIntervalSince(lastEnd))
        }
        log(.sessionStart(sessionsToday: sessionsToday, secondsSinceLastSession: secondsSinceLast))
        updateStreak()
        recordWeeklyActiveDay()
        checkRetentionMilestones()
        attributeOpenSource()
    }

    /// Classifies how this app-open started. Prefers notification → deep link / UTM →
    /// Apple Search Ads → organic. The small delay absorbs ordering differences between
    /// scene activation and notification / URL callbacks.
    private func attributeOpenSource() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            let attribution = AcquisitionAttribution.shared.resolveForSession(
                notificationOpenedAt: self.notificationOpenedAt,
                notificationWindow: self.notificationOpenWindow
            )
            self.log(.appOpenSource(
                source: attribution.source,
                campaign: attribution.campaign,
                medium: attribution.medium,
                detail: attribution.detail
            ))
            if let campaign = attribution.campaign {
                self.setUserProperty(String(campaign.prefix(36)), forName: "acq_campaign")
            }
            self.setUserProperty(attribution.source, forName: "acq_source")
        }
    }

    private func endSession() {
        guard let startedAt = sessionStartedAt else { return }
        let duration = Int(Date().timeIntervalSince(startedAt))
        log(.sessionEnd(durationSeconds: duration))

        let totalAds = sessionBannerImpressions + sessionInterstitialImpressions + sessionAppOpenImpressions
        if totalAds > 0 {
            log(.sessionAdImpressions(
                banner: sessionBannerImpressions,
                interstitial: sessionInterstitialImpressions,
                appOpen: sessionAppOpenImpressions
            ))
        }
        let interstitialPlacementTotal = sessionInterstitialInsights
            + sessionInterstitialOverview
            + sessionInterstitialSubjects
            + sessionInterstitialOther
        if interstitialPlacementTotal > 0 || sessionInterstitialClicks > 0 {
            log(.sessionInterstitialByPlacement(
                insights: sessionInterstitialInsights,
                overview: sessionInterstitialOverview,
                subjects: sessionInterstitialSubjects,
                other: sessionInterstitialOther,
                clicks: sessionInterstitialClicks
            ))
        }
        sessionBannerImpressions = 0
        sessionInterstitialImpressions = 0
        sessionAppOpenImpressions = 0
        sessionInterstitialInsights = 0
        sessionInterstitialOverview = 0
        sessionInterstitialSubjects = 0
        sessionInterstitialOther = 0
        sessionBannerClicks = 0
        sessionInterstitialClicks = 0

        defaults.set(Date(), forKey: Keys.lastSessionEnd)
        sessionStartedAt = nil
    }

    // MARK: - Engagement helpers

    private func incrementSessionsToday() -> Int {
        let today = Self.dayKey(for: Date())
        let storedDay = defaults.string(forKey: Keys.sessionsTodayDay)
        let count: Int
        if storedDay == today {
            count = defaults.integer(forKey: Keys.sessionsTodayCount) + 1
        } else {
            count = 1
            defaults.set(today, forKey: Keys.sessionsTodayDay)
        }
        defaults.set(count, forKey: Keys.sessionsTodayCount)
        return count
    }

    /// Maintains a "consecutive days used" streak and logs it when it changes.
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let lastDay = defaults.object(forKey: Keys.streakLastDay) as? Date
        var streak = defaults.integer(forKey: Keys.streakDays)

        if let lastDay {
            let last = calendar.startOfDay(for: lastDay)
            if calendar.isDate(last, inSameDayAs: today) {
                return // already counted today
            }
            if let dayBefore = calendar.date(byAdding: .day, value: 1, to: last),
               calendar.isDate(dayBefore, inSameDayAs: today) {
                streak += 1
            } else {
                streak = 1
            }
        } else {
            streak = 1
        }

        defaults.set(streak, forKey: Keys.streakDays)
        defaults.set(today, forKey: Keys.streakLastDay)
        log(.streakUpdated(days: streak))
    }

    // MARK: - Common metadata

    private func commonParameters() -> [String: Any] {
        var params: [String: Any] = [
            "platform": "iOS",
            "app_version": Self.appVersion,
            "app_build": Self.appBuild,
            "os_version": Self.osVersion,
            "device_model": Self.deviceModel,
            "session_id": sessionId,
            "user_id": userId
        ]
        if let currentScreen {
            params["current_screen"] = currentScreen.analyticsName
        }
        return params
    }

    // MARK: - Static device info

    static let appVersion: String =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"

    static let appBuild: String =
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"

    static var osVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafeBytes(of: &systemInfo.machine) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return identifier.isEmpty ? "unknown" : identifier
    }()

    private static func dayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    // MARK: - Threading

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

/// Mirror of SwiftUI's ScenePhase so non-SwiftUI callers (and this service) don't
/// need to import SwiftUI. HomeView/App map ScenePhase -> ScenePhaseLike.
enum ScenePhaseLike {
    case active
    case inactive
    case background
}
