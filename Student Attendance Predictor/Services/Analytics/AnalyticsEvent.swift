//
//  AnalyticsEvent.swift
//  Student Attendance Predictor
//
//  The full, type-safe analytics taxonomy for the app. Each case maps to a
//  snake_case event `name` plus a `parameters` dictionary. Common metadata
//  (session id, screen, app version, device, etc.) is added centrally by
//  AnalyticsService, so events here only carry their own specific fields.
//
//  Naming follows Firebase constraints: event/param names are <= 40 chars,
//  start with a letter, and avoid reserved prefixes (firebase_/google_/ga_).
//  Parameter values are kept to String / Int / Double / Bool.
//

import Foundation

enum AnalyticsEvent {
    // MARK: Lifecycle & session
    case appFirstLaunch
    case appLaunched(isReturningUser: Bool, launchTimeMs: Int?)
    case appForegrounded(secondsSinceBackground: Int?)
    case appBackgrounded
    case sessionStart(sessionsToday: Int, secondsSinceLastSession: Int?)
    case sessionEnd(durationSeconds: Int)
    case appOpenSource(source: String)

    // MARK: Screens & navigation
    case screenView(screen: AppScreen, previous: AppScreen?)
    case screenExit(screen: AppScreen, secondsSpent: Int)

    // MARK: Attendance actions
    case dayMarked(status: String, scheduled: Int, attended: Int, source: String)
    case dayCleared(source: String)
    case calculationCompleted(status: String, currentPercentage: Int, requiredPercentage: Int)
    case scenarioSelected(scenario: String)
    case requiredPercentagePresetApplied(value: Int)
    case inputsReset
    case defaultRequiredPercentageSaved(value: Int)
    case resultShared(status: String)

    // MARK: Subject management
    case subjectAdded(totalSubjects: Int)
    case subjectRenamed
    case subjectDeleted(totalSubjects: Int)
    case subjectSelected
    case timetableUpdated(classesPerWeek: Int)
    case timetableProjectionApplied

    // MARK: Feature usage
    case forecastViewed
    case trendViewed
    case dashboardViewed
    case forecastUnlockRequested
    case forecastUnlocked
    case lockedForecastViewed

    // MARK: Engagement depth
    case markTodayFirstUse
    case weeklyActiveDays(count: Int)
    case attendanceAtRiskShown(currentPct: Int, status: String)
    case fabBannerShown(action: String)
    case logDayEdited
    case subjectSwitched(totalSubjects: Int)
    case retentionDay7
    case retentionDay30

    // MARK: Monetization (rewarded + interstitial ads)
    case rewardedAdRequested(placement: String)
    case rewardedAdRewardEarned(placement: String)
    case rewardedAdFailed(placement: String, reason: String)
    case interstitialAdRequested(placement: String)
    case interstitialAdShown(placement: String)
    case interstitialAdFailed(placement: String, reason: String)
    case appOpenAdRequested
    case appOpenAdShown
    case appOpenAdFailed(reason: String)
    case bannerAdRequested(placement: String)
    case bannerAdLoaded(placement: String)
    case bannerAdShown(placement: String)
    case bannerAdFailed(placement: String, reason: String)
    /// Seconds a filled banner stayed on-screen (for revenue / visible-minute).
    case bannerVisibleSeconds(placement: String, seconds: Int)
    case interstitialSkipped(placement: String, reason: String)
    case appOpenSkipped(reason: String)
    case sessionAdImpressions(banner: Int, interstitial: Int, appOpen: Int)

    // MARK: Consent & privacy
    case attTrackingResult(status: String)
    case umpConsentResult(canRequestAds: Bool)

    // MARK: Feature discovery
    case settingsOpened
    case timetableEditorOpened
    case shareCancelled
    case notificationPermissionResult(granted: Bool)
    case notificationScheduled(type: String)
    case notificationOpened(type: String)
    case notificationsToggled(enabled: Bool)

    // MARK: Engagement
    case streakUpdated(days: Int)
    case onboardingCompleted

    // MARK: Settings & misc
    case rateUsTapped
    case adPrivacyChoicesOpened
    case reviewPromptShown

    // MARK: Pro IAP
    case proPaywallViewed(source: String)
    case proPurchaseStarted(source: String)
    case proPurchaseSucceeded(source: String)
    case proPurchaseFailed(source: String, reason: String)
    case proPurchaseCancelled(source: String)
    case proRestoreStarted
    case proRestoreSucceeded
    case proRestoreFailed
}

extension AnalyticsEvent {
    /// The event name sent to backends (snake_case).
    var name: String {
        switch self {
        case .appFirstLaunch: return "app_first_launch"
        case .appLaunched: return "app_launched"
        case .appForegrounded: return "app_foregrounded"
        case .appBackgrounded: return "app_backgrounded"
        case .sessionStart: return "session_start_custom"
        case .sessionEnd: return "session_end_custom"
        case .appOpenSource: return "app_open_source"

        case .screenView: return "screen_view_custom"
        case .screenExit: return "screen_exit"

        case .dayMarked: return "day_marked"
        case .dayCleared: return "day_cleared"
        case .calculationCompleted: return "calculation_completed"
        case .scenarioSelected: return "scenario_selected"
        case .requiredPercentagePresetApplied: return "required_pct_preset"
        case .inputsReset: return "inputs_reset"
        case .defaultRequiredPercentageSaved: return "default_pct_saved"
        case .resultShared: return "result_shared"

        case .subjectAdded: return "subject_added"
        case .subjectRenamed: return "subject_renamed"
        case .subjectDeleted: return "subject_deleted"
        case .subjectSelected: return "subject_selected"
        case .timetableUpdated: return "timetable_updated"
        case .timetableProjectionApplied: return "timetable_projection_applied"

        case .forecastViewed: return "forecast_viewed"
        case .trendViewed: return "trend_viewed"
        case .dashboardViewed: return "dashboard_viewed"
        case .forecastUnlockRequested: return "forecast_unlock_requested"
        case .forecastUnlocked: return "forecast_unlocked"
        case .lockedForecastViewed: return "locked_forecast_viewed"

        case .markTodayFirstUse: return "mark_today_first_use"
        case .weeklyActiveDays: return "weekly_active_days"
        case .attendanceAtRiskShown: return "attendance_at_risk_shown"
        case .fabBannerShown: return "fab_banner_shown"
        case .logDayEdited: return "log_day_edited"
        case .subjectSwitched: return "subject_switched"
        case .retentionDay7: return "retention_day_7"
        case .retentionDay30: return "retention_day_30"

        case .rewardedAdRequested: return "rewarded_ad_requested"
        case .rewardedAdRewardEarned: return "rewarded_ad_reward_earned"
        case .rewardedAdFailed: return "rewarded_ad_failed"
        case .interstitialAdRequested: return "interstitial_ad_requested"
        case .interstitialAdShown: return "interstitial_ad_shown"
        case .interstitialAdFailed: return "interstitial_ad_failed"
        case .appOpenAdRequested: return "app_open_ad_requested"
        case .appOpenAdShown: return "app_open_ad_shown"
        case .appOpenAdFailed: return "app_open_ad_failed"
        case .bannerAdRequested: return "banner_ad_requested"
        case .bannerAdLoaded: return "banner_ad_loaded"
        case .bannerAdShown: return "banner_ad_shown"
        case .bannerAdFailed: return "banner_ad_failed"
        case .bannerVisibleSeconds: return "banner_visible_seconds"
        case .interstitialSkipped: return "interstitial_skipped"
        case .appOpenSkipped: return "app_open_skipped"
        case .sessionAdImpressions: return "session_ad_impressions"

        case .attTrackingResult: return "att_tracking_result"
        case .umpConsentResult: return "ump_consent_result"

        case .settingsOpened: return "settings_opened"
        case .timetableEditorOpened: return "timetable_editor_opened"
        case .shareCancelled: return "share_cancelled"

        case .notificationPermissionResult: return "notif_permission_result"
        case .notificationScheduled: return "notif_scheduled"
        case .notificationOpened: return "notif_opened"
        case .notificationsToggled: return "notif_toggled"

        case .streakUpdated: return "streak_updated"
        case .onboardingCompleted: return "onboarding_completed"

        case .rateUsTapped: return "rate_us_tapped"
        case .adPrivacyChoicesOpened: return "ad_privacy_opened"
        case .reviewPromptShown: return "review_prompt_shown"

        case .proPaywallViewed: return "pro_paywall_viewed"
        case .proPurchaseStarted: return "pro_purchase_started"
        case .proPurchaseSucceeded: return "pro_purchase_succeeded"
        case .proPurchaseFailed: return "pro_purchase_failed"
        case .proPurchaseCancelled: return "pro_purchase_cancelled"
        case .proRestoreStarted: return "pro_restore_started"
        case .proRestoreSucceeded: return "pro_restore_succeeded"
        case .proRestoreFailed: return "pro_restore_failed"
        }
    }

    /// Event-specific parameters. Common metadata is merged in by AnalyticsService.
    var parameters: [String: Any] {
        switch self {
        case .appFirstLaunch, .appBackgrounded, .inputsReset, .subjectRenamed,
             .subjectSelected, .timetableProjectionApplied, .forecastViewed,
             .trendViewed, .dashboardViewed, .forecastUnlockRequested,
             .forecastUnlocked, .lockedForecastViewed, .markTodayFirstUse,
             .logDayEdited, .retentionDay7, .retentionDay30,
             .rateUsTapped, .adPrivacyChoicesOpened, .reviewPromptShown,
             .settingsOpened, .timetableEditorOpened, .shareCancelled,
             .appOpenAdRequested, .appOpenAdShown,
             .proRestoreStarted, .proRestoreSucceeded, .proRestoreFailed,
             .onboardingCompleted:
            return [:]

        case let .appLaunched(isReturningUser, launchTimeMs):
            var p: [String: Any] = ["is_returning_user": isReturningUser]
            if let launchTimeMs { p["launch_time_ms"] = launchTimeMs }
            return p

        case let .appForegrounded(secondsSinceBackground):
            var p: [String: Any] = [:]
            if let secondsSinceBackground { p["seconds_since_background"] = secondsSinceBackground }
            return p

        case let .sessionStart(sessionsToday, secondsSinceLastSession):
            var p: [String: Any] = ["sessions_today": sessionsToday]
            if let secondsSinceLastSession { p["seconds_since_last_session"] = secondsSinceLastSession }
            return p

        case let .sessionEnd(durationSeconds):
            return ["duration_seconds": durationSeconds]

        case let .appOpenSource(source):
            return ["source": source]

        case let .screenView(screen, previous):
            var p: [String: Any] = ["screen": screen.analyticsName]
            if let previous { p["previous_screen"] = previous.analyticsName }
            return p

        case let .screenExit(screen, secondsSpent):
            return ["screen": screen.analyticsName, "seconds_spent": secondsSpent]

        case let .dayMarked(status, scheduled, attended, source):
            return [
                "status": status,
                "scheduled": scheduled,
                "attended": attended,
                "source": source
            ]

        case let .dayCleared(source):
            return ["source": source]

        case let .calculationCompleted(status, currentPercentage, requiredPercentage):
            return [
                "status": status,
                "current_pct": currentPercentage,
                "required_pct": requiredPercentage
            ]

        case let .scenarioSelected(scenario):
            return ["scenario": scenario]

        case let .requiredPercentagePresetApplied(value):
            return ["value": value]

        case let .defaultRequiredPercentageSaved(value):
            return ["value": value]

        case let .resultShared(status):
            return ["status": status]

        case let .subjectAdded(totalSubjects):
            return ["total_subjects": totalSubjects]

        case let .subjectDeleted(totalSubjects):
            return ["total_subjects": totalSubjects]

        case let .timetableUpdated(classesPerWeek):
            return ["classes_per_week": classesPerWeek]

        case let .rewardedAdRequested(placement):
            return ["placement": placement]

        case let .rewardedAdRewardEarned(placement):
            return ["placement": placement]

        case let .rewardedAdFailed(placement, reason):
            return ["placement": placement, "reason": reason]

        case let .interstitialAdRequested(placement):
            return ["placement": placement]

        case let .interstitialAdShown(placement):
            return ["placement": placement]

        case let .interstitialAdFailed(placement, reason):
            return ["placement": placement, "reason": reason]

        case .appOpenAdRequested:
            return [:]

        case .appOpenAdShown:
            return [:]

        case let .appOpenAdFailed(reason):
            return ["reason": reason]

        case let .bannerAdRequested(placement):
            return ["placement": placement]

        case let .bannerAdLoaded(placement):
            return ["placement": placement]

        case let .bannerAdShown(placement):
            return ["placement": placement]

        case let .bannerAdFailed(placement, reason):
            return ["placement": placement, "reason": reason]

        case let .bannerVisibleSeconds(placement, seconds):
            return ["placement": placement, "seconds": seconds]

        case let .interstitialSkipped(placement, reason):
            return ["placement": placement, "reason": reason]

        case let .appOpenSkipped(reason):
            return ["reason": reason]

        case let .sessionAdImpressions(banner, interstitial, appOpen):
            return [
                "banner": banner,
                "interstitial": interstitial,
                "app_open": appOpen,
                "total": banner + interstitial + appOpen
            ]

        case let .attTrackingResult(status):
            return ["status": status]

        case let .umpConsentResult(canRequestAds):
            return ["can_request_ads": canRequestAds]

        case let .weeklyActiveDays(count):
            return ["count": count]

        case let .attendanceAtRiskShown(currentPct, status):
            return ["current_pct": currentPct, "status": status]

        case let .fabBannerShown(action):
            return ["action": action]

        case let .subjectSwitched(totalSubjects):
            return ["total_subjects": totalSubjects]

        case let .notificationPermissionResult(granted):
            return ["granted": granted]

        case let .notificationScheduled(type):
            return ["type": type]

        case let .notificationOpened(type):
            return ["type": type]

        case let .notificationsToggled(enabled):
            return ["enabled": enabled]

        case let .streakUpdated(days):
            return ["days": days]

        case let .proPaywallViewed(source):
            return ["source": source]

        case let .proPurchaseStarted(source):
            return ["source": source]

        case let .proPurchaseSucceeded(source):
            return ["source": source]

        case let .proPurchaseFailed(source, reason):
            return ["source": source, "reason": reason]

        case let .proPurchaseCancelled(source):
            return ["source": source]
        }
    }
}
