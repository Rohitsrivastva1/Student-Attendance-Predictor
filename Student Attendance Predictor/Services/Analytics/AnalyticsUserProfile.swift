//
//  AnalyticsUserProfile.swift
//  Student Attendance Predictor
//
//  Syncs anonymous Firebase user properties and engagement milestones.
//

import Foundation

enum AnalyticsUserProfile {
    /// Recompute and push user properties from current app state.
    @MainActor
    static func sync(
        subjectStore: SubjectStore?,
        notificationsEnabled: Bool? = nil
    ) {
        let subjects = subjectStore?.subjects ?? []
        let subjectCount = subjects.count
        let hasTimetable = subjects.contains { $0.weeklySchedule.totalPerWeek > 0 }
        let status = attendanceStatus(for: subjectStore)

        AnalyticsService.shared.setUserProperty(bucketSubjectCount(subjectCount), forName: "subject_count")
        AnalyticsService.shared.setUserProperty(hasTimetable ? "true" : "false", forName: "has_timetable")
        AnalyticsService.shared.setUserProperty(status, forName: "attendance_status")
        AnalyticsService.shared.setUserProperty(
            AnalyticsService.shared.daysSinceInstallBucket,
            forName: "days_since_install"
        )
        AnalyticsService.shared.setUserProperty(
            AdEntitlementsStore.shared.areBannersHidden ? "true" : "false",
            forName: "ads_removed_active"
        )
        AnalyticsService.shared.setUserProperty(
            AdEntitlementsStore.shared.isPro ? "true" : "false",
            forName: "is_pro"
        )

        let notifEnabled = notificationsEnabled
            ?? UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool
            ?? true
        AnalyticsService.shared.setUserProperty(notifEnabled ? "true" : "false", forName: "notif_enabled")
    }

    @MainActor
    static func recordDayMarked(source: String) {
        AnalyticsService.shared.recordWeeklyActiveDay()
        AnalyticsService.shared.checkRetentionMilestones()

        // Mark Today logs `mark_today_multi` (pager / mark-all). A strict
        // `mark_today` match dropped almost every first-use event.
        if source.hasPrefix("mark_today") {
            AnalyticsService.shared.recordFirstMarkIfNeeded()
            GuidedSetupStore.shared.complete()
        }
        if source == "day_editor" {
            AnalyticsService.shared.log(.logDayEdited)
        }
    }

    @MainActor
    private static func attendanceStatus(for subjectStore: SubjectStore?) -> String {
        guard let store = subjectStore, let selected = store.subjects.first(where: { $0.id == store.selectedSubjectID }) else {
            if let subjectStore, subjectStore.subjects.isEmpty == false {
                return subjectStore.dashboardSummary.riskSubjects > 0 ? "at_risk" : "safe"
            }
            return "unknown"
        }

        let result = AttendanceResult(
            currentPercentage: selected.currentPercentage,
            bunkAllowed: CalculationService.maxBunk(
                attended: selected.attendedClasses,
                total: selected.totalClasses,
                required: selected.requiredPercentage
            ),
            recoveryNeeded: CalculationService.requiredClasses(
                attended: selected.attendedClasses,
                total: selected.totalClasses,
                required: selected.requiredPercentage
            ),
            status: selected.status
        )

        if result.status == .safe { return "safe" }
        if result.status == .risk && result.recoveryNeeded >= 5 { return "critical" }
        return "at_risk"
    }

    private static func bucketSubjectCount(_ count: Int) -> String {
        switch count {
        case 0: return "0"
        case 1: return "1"
        case 2...4: return "2-4"
        default: return "5+"
        }
    }
}
