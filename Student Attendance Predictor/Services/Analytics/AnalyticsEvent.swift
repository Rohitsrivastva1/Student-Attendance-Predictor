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
    case appOpenSource(source: String, campaign: String?, medium: String?, detail: String?)

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
    case streakShared(days: Int)

    // MARK: Subject management
    case subjectAdded(totalSubjects: Int)
    case subjectRenamed
    case subjectDeleted(totalSubjects: Int)
    case subjectSelected
    case subjectLimitHit(totalSubjects: Int)
    case timetableUpdated(classesPerWeek: Int)
    case timetableProjectionApplied

    // MARK: Feature usage
    case forecastViewed
    case trendViewed
    case dashboardViewed
    case forecastUnlockRequested
    case forecastUnlocked
    case lockedForecastViewed
    case pdfExportTapped
    case pdfExportShared(subjectCount: Int)
    case csvExportTapped
    case csvExportShared(rowCount: Int)
    case skipPlannerViewed(dayCount: Int)
    case skipPlannerLocked
    case guidedSetupStarted
    case guidedSetupStepShown(step: String)
    case guidedSetupCompleted
    case guidedSetupDismissed(step: String)
    case holidayPresetApplied(presetID: String, cancelledClasses: Int)
    case widgetPromptShown
    case postMarkFocusPromptShown(subjectName: String)
    case postMarkFocusPromptAccepted(minutes: Int)
    case postMarkFocusPromptDismissed
    case atRiskSharePromptShown
    case atRiskSharePromptTapped
    case siriShortcutsTipShown
    case homePromoCardShown(kind: String)
    case homePromoCardTapped(kind: String, action: String)
    case multiFeatureWeeklyUser(featureCount: Int, features: String)

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
    case bannerAdRequested(placement: String, isRetry: Bool)
    case bannerAdLoaded(placement: String)
    case bannerAdShown(placement: String)
    case bannerAdFailed(placement: String, reason: String, isRetry: Bool)
    /// Banner load deferred (consent/SDK not ready) — not a fill failure.
    case bannerAdSkipped(placement: String, reason: String)
    /// User tapped a banner (placement-level CTR in Firebase).
    case bannerAdClicked(placement: String)
    /// Seconds a filled banner stayed on-screen (for revenue / visible-minute).
    case bannerVisibleSeconds(placement: String, seconds: Int)
    case interstitialSkipped(placement: String, reason: String)
    /// User tapped a full-screen interstitial (placement-level).
    case interstitialAdClicked(placement: String)
    case appOpenSkipped(reason: String)
    case sessionAdImpressions(banner: Int, interstitial: Int, appOpen: Int)
    /// Per-placement interstitial counts for the session (join to AdMob weekly $).
    case sessionInterstitialByPlacement(insights: Int, overview: Int, subjects: Int, other: Int, clicks: Int)

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
    case personalityNotificationScheduled(
        category: String,
        templateID: String,
        variant: String,
        slot: String,
        attendancePct: Int,
        safeBunks: Int
    )
    case personalityNotificationOpened(category: String, templateID: String, variant: String)
    case personalityNotificationDismissed(category: String, templateID: String)
    case notificationDeepLinkOpened(destination: String)

    // MARK: Academics
    case academicCourseAdded(market: String, total: Int)
    case academicCourseUpdated
    case academicCourseDeleted(total: Int)
    case academicDeadlineAdded(kind: String)
    case academicDeadlineUpdated
    case academicDeadlineDeleted
    case academicTargetViewed(market: String)
    case academicExamAttendanceWarningShown
    case academicExamAttendanceWarningTapped
    case academicTermArchived
    case academicsViewed(
        market: String,
        courseCount: Int,
        deadlineCount: Int,
        focusMinutesToday: Int,
        focusSessionsToday: Int,
        mode: String
    )
    case toolsViewed(focusMinutesToday: Int, courseCount: Int, deadlineCount: Int)
    case academicCourseAddTapped(market: String)
    case academicDeadlineAddTapped

    // MARK: Focus timer (Academics tab)
    case focusTimerStarted(minutes: Int, hasSubjectTag: Bool, hasTopicTag: Bool)
    case focusTimerPaused(phase: String, remainingSeconds: Int)
    case focusTimerReset(phase: String)
    case focusTimerCompleted(minutes: Int, hasSubjectTag: Bool, hasTopicTag: Bool)
    case focusTopicAdded(hasSubjectLink: Bool, total: Int)
    case focusProDurationTapped
    case focusLiveActivityStarted(phase: String)
    case focusLiveActivityEnded
    case focusMarkPromptShown(minutes: Int, subjectName: String)
    case focusMarkPromptUsed(status: String)
    case focusMarkPromptDismissed
    case siriSafestSkipRequested
    case siriMarkAllAttended(count: Int)

    // MARK: Engagement
    case streakUpdated(days: Int)
    case onboardingShown
    case onboardingSkipped(reason: String)
    case onboardingCompleted(via: String)
    case studentProfileCompleted(skipped: Bool)
    case studentProfileUpdated(source: String)
    case schoolabeSyncSucceeded(subjectCount: Int)
    case schoolabeSyncFailed(reason: String)
    case schoolabeUserDataDeleted
    case userDataRemoveFailed(reason: String)
    case softPaywallTriggered(source: String)

    // MARK: Settings & misc
    case rateUsTapped
    case adPrivacyChoicesOpened
    case reviewPromptShown
    case dayTwoReviewPromptShown
    case dayTwoReviewPromptAction(action: String)

    // MARK: Pro IAP
    case proPaywallViewed(source: String)
    /// StoreKit price rendered on the paywall (or confirmed unavailable).
    case proPriceShown(source: String, price: String, currency: String, available: Bool)
    /// Left paywall via X / swipe without a successful purchase.
    case proPaywallDismissed(source: String, hadPrice: Bool, didStartPurchase: Bool, secondsVisible: Int)
    /// Soft / alert Pro CTA became visible (before tap).
    case proCtaShown(surface: String)
    /// Soft / alert Pro CTA action (`go_pro`, `not_now`, …).
    case proCtaTapped(surface: String, action: String)
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
        case .streakShared: return "streak_shared"

        case .subjectAdded: return "subject_added"
        case .subjectRenamed: return "subject_renamed"
        case .subjectDeleted: return "subject_deleted"
        case .subjectSelected: return "subject_selected"
        case .subjectLimitHit: return "subject_limit_hit"
        case .timetableUpdated: return "timetable_updated"
        case .timetableProjectionApplied: return "timetable_projection_applied"

        case .forecastViewed: return "forecast_viewed"
        case .trendViewed: return "trend_viewed"
        case .dashboardViewed: return "dashboard_viewed"
        case .forecastUnlockRequested: return "forecast_unlock_requested"
        case .forecastUnlocked: return "forecast_unlocked"
        case .lockedForecastViewed: return "locked_forecast_viewed"
        case .pdfExportTapped: return "pdf_export_tapped"
        case .pdfExportShared: return "pdf_export_shared"
        case .csvExportTapped: return "csv_export_tapped"
        case .csvExportShared: return "csv_export_shared"
        case .skipPlannerViewed: return "skip_planner_viewed"
        case .skipPlannerLocked: return "skip_planner_locked"
        case .guidedSetupStarted: return "guided_setup_started"
        case .guidedSetupStepShown: return "guided_setup_step"
        case .guidedSetupCompleted: return "guided_setup_completed"
        case .guidedSetupDismissed: return "guided_setup_dismissed"
        case .holidayPresetApplied: return "holiday_preset_applied"
        case .widgetPromptShown: return "widget_prompt_shown"
        case .postMarkFocusPromptShown: return "post_mark_focus_prompt_shown"
        case .postMarkFocusPromptAccepted: return "post_mark_focus_prompt_accepted"
        case .postMarkFocusPromptDismissed: return "post_mark_focus_prompt_dismissed"
        case .atRiskSharePromptShown: return "at_risk_share_prompt_shown"
        case .atRiskSharePromptTapped: return "at_risk_share_prompt_tapped"
        case .siriShortcutsTipShown: return "siri_shortcuts_tip_shown"
        case .homePromoCardShown: return "home_promo_shown"
        case .homePromoCardTapped: return "home_promo_tapped"
        case .multiFeatureWeeklyUser: return "multi_feature_weekly"

        case .markTodayFirstUse: return "mark_today_first_use"
        case .weeklyActiveDays: return "weekly_active_days"
        case .attendanceAtRiskShown: return "attendance_at_risk_shown"
        case .fabBannerShown: return "fab_banner_shown"
        case .logDayEdited: return "log_day_edited"
        case .subjectSwitched: return "subject_switched"
        case .retentionDay7: return "retention_day_7"
        case .retentionDay30: return "retention_day_30"

        case .academicCourseAdded: return "academic_course_added"
        case .academicCourseUpdated: return "academic_course_updated"
        case .academicCourseDeleted: return "academic_course_deleted"
        case .academicDeadlineAdded: return "academic_deadline_added"
        case .academicDeadlineUpdated: return "academic_deadline_updated"
        case .academicDeadlineDeleted: return "academic_deadline_deleted"
        case .academicTargetViewed: return "academic_target_viewed"
        case .academicExamAttendanceWarningShown: return "exam_attendance_warning"
        case .academicExamAttendanceWarningTapped: return "exam_attendance_warning_tapped"
        case .academicTermArchived: return "academic_term_archived"
        case .academicsViewed: return "academics_viewed"
        case .toolsViewed: return "tools_viewed"
        case .academicCourseAddTapped: return "academic_course_add_tapped"
        case .academicDeadlineAddTapped: return "academic_deadline_add_tapped"
        case .focusTimerStarted: return "focus_timer_started"
        case .focusTimerPaused: return "focus_timer_paused"
        case .focusTimerReset: return "focus_timer_reset"
        case .focusTimerCompleted: return "focus_timer_completed"
        case .focusTopicAdded: return "focus_topic_added"
        case .focusProDurationTapped: return "focus_pro_duration_tapped"
        case .focusLiveActivityStarted: return "focus_live_activity_started"
        case .focusLiveActivityEnded: return "focus_live_activity_ended"
        case .focusMarkPromptShown: return "focus_mark_prompt_shown"
        case .focusMarkPromptUsed: return "focus_mark_prompt_used"
        case .focusMarkPromptDismissed: return "focus_mark_prompt_dismissed"
        case .siriSafestSkipRequested: return "siri_safest_skip_requested"
        case .siriMarkAllAttended: return "siri_mark_all_attended"

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
        case .bannerAdSkipped: return "banner_ad_skipped"
        case .bannerAdClicked: return "banner_ad_clicked"
        case .bannerVisibleSeconds: return "banner_visible_seconds"
        case .interstitialSkipped: return "interstitial_skipped"
        case .interstitialAdClicked: return "interstitial_ad_clicked"
        case .appOpenSkipped: return "app_open_skipped"
        case .sessionAdImpressions: return "session_ad_impressions"
        case .sessionInterstitialByPlacement: return "session_interstitial_by_placement"

        case .attTrackingResult: return "att_tracking_result"
        case .umpConsentResult: return "ump_consent_result"

        case .settingsOpened: return "settings_opened"
        case .timetableEditorOpened: return "timetable_editor_opened"
        case .shareCancelled: return "share_cancelled"

        case .notificationPermissionResult: return "notif_permission_result"
        case .notificationScheduled: return "notif_scheduled"
        case .notificationOpened: return "notif_opened"
        case .notificationsToggled: return "notif_toggled"
        case .personalityNotificationScheduled: return "personality_notif_scheduled"
        case .personalityNotificationOpened: return "personality_notif_opened"
        case .personalityNotificationDismissed: return "personality_notif_dismissed"
        case .notificationDeepLinkOpened: return "notif_deep_link_opened"

        case .streakUpdated: return "streak_updated"
        case .onboardingShown: return "onboarding_shown"
        case .onboardingSkipped: return "onboarding_skipped"
        case .onboardingCompleted: return "onboarding_completed"
        case .studentProfileCompleted: return "student_profile_completed"
        case .studentProfileUpdated: return "student_profile_updated"
        case .schoolabeSyncSucceeded: return "schoolabe_sync_succeeded"
        case .schoolabeSyncFailed: return "schoolabe_sync_failed"
        case .schoolabeUserDataDeleted: return "schoolabe_user_data_deleted"
        case .userDataRemoveFailed: return "user_data_remove_failed"
        case .softPaywallTriggered: return "soft_paywall_triggered"

        case .rateUsTapped: return "rate_us_tapped"
        case .adPrivacyChoicesOpened: return "ad_privacy_opened"
        case .reviewPromptShown: return "review_prompt_shown"
        case .dayTwoReviewPromptShown: return "day_two_review_prompt_shown"
        case .dayTwoReviewPromptAction: return "day_two_review_prompt_action"

        case .proPaywallViewed: return "pro_paywall_viewed"
        case .proPriceShown: return "pro_price_shown"
        case .proPaywallDismissed: return "pro_paywall_dismissed"
        case .proCtaShown: return "pro_cta_shown"
        case .proCtaTapped: return "pro_cta_tapped"
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
             .csvExportTapped, .skipPlannerLocked, .focusProDurationTapped,
             .guidedSetupStarted, .guidedSetupCompleted, .widgetPromptShown, .focusLiveActivityEnded,
             .academicExamAttendanceWarningShown, .academicExamAttendanceWarningTapped,
             .focusMarkPromptDismissed, .siriSafestSkipRequested,
             .postMarkFocusPromptDismissed, .atRiskSharePromptShown,
             .atRiskSharePromptTapped,
             .siriShortcutsTipShown,
             .rateUsTapped, .adPrivacyChoicesOpened, .reviewPromptShown,
             .dayTwoReviewPromptShown,
             .settingsOpened, .timetableEditorOpened, .shareCancelled,
             .appOpenAdRequested, .appOpenAdShown,
             .proRestoreStarted, .proRestoreSucceeded, .proRestoreFailed,
             .onboardingShown, .pdfExportTapped,
             .academicCourseUpdated, .academicDeadlineUpdated, .academicDeadlineDeleted,
             .academicTermArchived,
             .academicDeadlineAddTapped:
            return [:]

        case let .academicsViewed(market, courseCount, deadlineCount, focusMinutesToday, focusSessionsToday, mode):
            return [
                "market": market,
                "course_count": courseCount,
                "deadline_count": deadlineCount,
                "focus_minutes_today": focusMinutesToday,
                "focus_sessions_today": focusSessionsToday,
                "mode": mode
            ]

        case let .toolsViewed(focusMinutesToday, courseCount, deadlineCount):
            return [
                "focus_minutes_today": focusMinutesToday,
                "course_count": courseCount,
                "deadline_count": deadlineCount
            ]

        case let .academicCourseAddTapped(market):
            return ["market": market]

        case let .focusTimerStarted(minutes, hasSubjectTag, hasTopicTag):
            return ["minutes": minutes, "has_subject_tag": hasSubjectTag, "has_topic_tag": hasTopicTag]

        case let .focusTimerPaused(phase, remainingSeconds):
            return ["phase": phase, "remaining_seconds": remainingSeconds]

        case let .focusTimerReset(phase):
            return ["phase": phase]

        case let .focusTimerCompleted(minutes, hasSubjectTag, hasTopicTag):
            return ["minutes": minutes, "has_subject_tag": hasSubjectTag, "has_topic_tag": hasTopicTag]

        case let .focusTopicAdded(hasSubjectLink, total):
            return ["has_subject_link": hasSubjectLink, "total": total]

        case let .focusLiveActivityStarted(phase):
            return ["phase": phase]

        case let .focusMarkPromptShown(minutes, subjectName):
            return ["minutes": minutes, "subject_name": subjectName]

        case let .focusMarkPromptUsed(status):
            return ["status": status]

        case let .siriMarkAllAttended(count):
            return ["count": count]

        case let .academicCourseAdded(market, total):
            return ["market": market, "total": total]

        case let .academicCourseDeleted(total):
            return ["total": total]

        case let .academicDeadlineAdded(kind):
            return ["kind": kind]

        case let .academicTargetViewed(market):
            return ["market": market]

        case let .onboardingSkipped(reason):
            return ["reason": reason]

        case let .onboardingCompleted(via):
            return ["via": via]

        case let .studentProfileCompleted(skipped):
            return ["skipped": skipped]

        case let .studentProfileUpdated(source):
            return ["source": source]

        case let .dayTwoReviewPromptAction(action):
            return ["action": action]

        case let .schoolabeSyncSucceeded(subjectCount):
            return ["subject_count": subjectCount]

        case let .schoolabeSyncFailed(reason):
            return ["reason": String(reason.prefix(80))]

        case .schoolabeUserDataDeleted:
            return [:]

        case let .userDataRemoveFailed(reason):
            return ["reason": String(reason.prefix(80))]

        case let .softPaywallTriggered(source):
            return ["source": source]

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

        case let .appOpenSource(source, campaign, medium, detail):
            var p: [String: Any] = ["source": source]
            if let campaign, campaign.isEmpty == false { p["campaign"] = String(campaign.prefix(40)) }
            if let medium, medium.isEmpty == false { p["medium"] = String(medium.prefix(40)) }
            if let detail, detail.isEmpty == false { p["detail"] = String(detail.prefix(40)) }
            return p

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

        case let .streakShared(days):
            return ["days": days]

        case let .subjectAdded(totalSubjects):
            return ["total_subjects": totalSubjects]

        case let .subjectDeleted(totalSubjects):
            return ["total_subjects": totalSubjects]

        case let .subjectLimitHit(totalSubjects):
            return ["total_subjects": totalSubjects]

        case let .pdfExportShared(subjectCount):
            return ["subject_count": subjectCount]

        case let .csvExportShared(rowCount):
            return ["row_count": rowCount]

        case let .skipPlannerViewed(dayCount):
            return ["day_count": dayCount]

        case let .guidedSetupDismissed(step):
            return ["step": step]

        case let .guidedSetupStepShown(step):
            return ["step": step]

        case let .holidayPresetApplied(presetID, cancelledClasses):
            return ["preset_id": String(presetID.prefix(24)), "cancelled": cancelledClasses]

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

        case let .bannerAdRequested(placement, isRetry):
            return ["placement": placement, "is_retry": isRetry]

        case let .bannerAdLoaded(placement):
            return ["placement": placement]

        case let .bannerAdShown(placement):
            return ["placement": placement]

        case let .bannerAdFailed(placement, reason, isRetry):
            return ["placement": placement, "reason": reason, "is_retry": isRetry]

        case let .bannerAdSkipped(placement, reason):
            return ["placement": placement, "reason": reason]

        case let .bannerAdClicked(placement):
            return ["placement": placement]

        case let .bannerVisibleSeconds(placement, seconds):
            return ["placement": placement, "seconds": seconds]

        case let .interstitialSkipped(placement, reason):
            return ["placement": placement, "reason": reason]

        case let .interstitialAdClicked(placement):
            return ["placement": placement]

        case let .appOpenSkipped(reason):
            return ["reason": reason]

        case let .sessionAdImpressions(banner, interstitial, appOpen):
            return [
                "banner": banner,
                "interstitial": interstitial,
                "app_open": appOpen,
                "total": banner + interstitial + appOpen
            ]

        case let .sessionInterstitialByPlacement(insights, overview, subjects, other, clicks):
            return [
                "insights": insights,
                "overview": overview,
                "subjects": subjects,
                "other": other,
                "clicks": clicks,
                "total": insights + overview + subjects + other
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

        case let .personalityNotificationScheduled(category, templateID, variant, slot, attendancePct, safeBunks):
            return [
                "category": category,
                "template_id": String(templateID.prefix(36)),
                "variant": String(variant.prefix(8)),
                "slot": slot,
                "attendance_pct": attendancePct,
                "safe_bunks": safeBunks
            ]

        case let .personalityNotificationOpened(category, templateID, variant):
            return [
                "category": category,
                "template_id": String(templateID.prefix(36)),
                "variant": String(variant.prefix(8))
            ]

        case let .personalityNotificationDismissed(category, templateID):
            return [
                "category": category,
                "template_id": String(templateID.prefix(36))
            ]

        case let .notificationDeepLinkOpened(destination):
            return ["destination": destination]

        case let .streakUpdated(days):
            return ["days": days]

        case let .proPaywallViewed(source):
            return ["source": source]

        case let .proPriceShown(source, price, currency, available):
            return [
                "source": source,
                "price": String(price.prefix(20)),
                "currency": String(currency.prefix(8)),
                "available": available
            ]

        case let .proPaywallDismissed(source, hadPrice, didStartPurchase, secondsVisible):
            return [
                "source": source,
                "had_price": hadPrice,
                "did_start_purchase": didStartPurchase,
                "seconds_visible": secondsVisible
            ]

        case let .proCtaShown(surface):
            return ["surface": surface]

        case let .proCtaTapped(surface, action):
            return ["surface": surface, "action": action]

        case let .proPurchaseStarted(source):
            return ["source": source]

        case let .proPurchaseSucceeded(source):
            return ["source": source]

        case let .proPurchaseFailed(source, reason):
            return ["source": source, "reason": reason]

        case let .proPurchaseCancelled(source):
            return ["source": source]

        case let .postMarkFocusPromptShown(subjectName):
            return ["subject_name": String(subjectName.prefix(24))]

        case let .postMarkFocusPromptAccepted(minutes):
            return ["minutes": minutes]

        case let .homePromoCardShown(kind):
            return ["kind": kind]

        case let .homePromoCardTapped(kind, action):
            return ["kind": kind, "action": action]

        case let .multiFeatureWeeklyUser(featureCount, features):
            return ["feature_count": featureCount, "features": String(features.prefix(60))]
        }
    }
}
