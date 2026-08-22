//
//  AdMobConfiguration.swift
//  Student Attendance Predictor
//

import Foundation

enum AdMobConfiguration {
    /// Bunk Planner: Attendance Track — production app ID.
    static let applicationID = "ca-app-pub-6782814088719675~7481844312"

    /// Placement identifiers passed to `AdMobBannerCard`. Used to resolve per-slot ad units.
    enum Placement {
        static let home = "home-total-classes"
        /// Mapped to a dedicated unit configured for third-party mediation.
        static let insights = "insights-trend-forecast"
        static let overview = "overview-dashboard-subjects"
        /// Natural break after the user marks attendance (interstitial) — deprecated / unused.
        static let afterDayMarked = "after_day_marked"
        /// Natural break on first Insights visit in a session (interstitial).
        static let afterInsightsOpened = "after_insights_opened"
        /// Natural break on first Overview visit in a session (interstitial).
        static let afterOverviewOpened = "after_overview_opened"
        /// Natural break on first Subjects screen open in a session (interstitial).
        static let afterSubjectsOpened = "after_subjects_opened"
    }

    /// Default anchored adaptive banner (production) — Home slot.
    /// Refresh interval is set in the AdMob console (recommend 60–90s for current traffic).
    static let bannerAdUnitID = "ca-app-pub-6782814088719675/3617786775"

    /// Insights banner (production) — mapped on a third-party mediation platform.
    static let insightsBannerAdUnitID = "ca-app-pub-6782814088719675/2282542811"

    /// Overview banner (production).
    static let overviewBannerAdUnitID = "ca-app-pub-6782814088719675/9493185513"

    /// Rewarded ad (production) — powers short-lived ad removal and forecast unlock.
    static let rewardedAdUnitID = "ca-app-pub-6782814088719675/9859604331"

    /// Interstitial ad (production) — shown after marking attendance (frequency-capped).
    static let interstitialAdUnitID = "ca-app-pub-6782814088719675/2384255214"

    /// App open ad (production) — shown when the app returns to the foreground.
    static let appOpenAdUnitID = "ca-app-pub-6782814088719675/2791449322"

    #if DEBUG
    /// Google test units — use while developing to avoid invalid traffic.
    static let usesTestAds = true
    static let resolvedBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let resolvedInsightsBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let resolvedOverviewBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let resolvedRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    static let resolvedInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    static let resolvedAppOpenAdUnitID = "ca-app-pub-3940256099942544/5575463023"
    #else
    static let usesTestAds = false
    static let resolvedBannerAdUnitID = bannerAdUnitID
    static let resolvedInsightsBannerAdUnitID = insightsBannerAdUnitID
    static let resolvedOverviewBannerAdUnitID = overviewBannerAdUnitID
    static let resolvedRewardedAdUnitID = rewardedAdUnitID
    static let resolvedInterstitialAdUnitID = interstitialAdUnitID
    static let resolvedAppOpenAdUnitID = appOpenAdUnitID
    #endif

    /// Resolves the banner ad unit for a given placement.
    /// All slots share the Home unit so thin India demand is not split across
    /// multiple units (Insights mediation was starving fill at ~16% load rate).
    /// `insightsBannerAdUnitID` / `overviewBannerAdUnitID` kept for console remapping later.
    static func resolvedBannerAdUnitID(for placement: String) -> String {
        _ = placement
        return resolvedBannerAdUnitID
    }
}
