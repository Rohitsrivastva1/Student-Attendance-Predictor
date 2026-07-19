//
//  NotificationService.swift
//  Student Attendance Predictor
//

import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                AnalyticsService.shared.log(.notificationPermissionResult(granted: granted))
            }
        }
    }

    static func scheduleRiskAlert(
        subjectName: String,
        currentPercentage: Double,
        recoveryNeeded: Int
    ) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-risk-\(subjectName.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard recoveryNeeded > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subjectName): Attendance Alert"
        content.body = "Your attendance is \(String(format: "%.1f", currentPercentage))% — attend next \(recoveryNeeded) classes."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "risk"))
    }

    static func scheduleLowBufferAlert(
        subjectName: String,
        currentPercentage: Double,
        bunkAllowed: Int
    ) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-buffer-\(subjectName.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard bunkAllowed <= 2 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subjectName): Low Attendance Buffer"
        content.body = bunkAllowed > 0
            ? "You can safely skip \(bunkAllowed) class\(bunkAllowed == 1 ? "" : "es") next week — stay mindful."
            : "Current attendance is \(String(format: "%.1f", currentPercentage))%. You can miss only \(max(0, bunkAllowed)) more classes safely."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "low_buffer"))
    }

    /// Evening habit reminder — "Did you attend today's classes?"
    static func scheduleClassReminder(hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-class-reminder-daily"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        var dateComponents = DateComponents()
        dateComponents.hour = min(max(hour, 0), 23)
        dateComponents.minute = min(max(minute, 0), 59)

        let content = UNMutableNotificationContent()
        content.title = "Did you attend today's classes?"
        content.body = "Tap to log today's attendance in one tap."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "class_reminder"))
    }

    static func scheduleWeeklyEngagementReminders() {
        let center = UNUserNotificationCenter.current()

        // Monday morning — new week
        scheduleWeekly(
            center: center,
            identifier: "attendance-monday-kickoff",
            weekday: 2,
            hour: 9,
            title: "New week, keep your attendance on track",
            body: "Log classes as you go — small taps keep you safe all semester.",
            type: "monday_kickoff"
        )

        // Friday — bunk buffer nudge
        scheduleWeekly(
            center: center,
            identifier: "attendance-friday-buffer",
            weekday: 6,
            hour: 17,
            title: "Weekend check-in",
            body: "Open Bunk Planner to see how many classes you can safely skip next week.",
            type: "friday_buffer"
        )
    }

    static func scheduleHolidayWeekHint() {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-holiday-hint"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Holiday week won't affect your attendance"
        content.body = "Mark holidays in Today's Classes so they don't count against you."
        content.sound = .default

        // Soft nudge ~36h after scheduling (used opportunistically).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 36, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "holiday_hint"))
    }

    static func scheduleRecoveryDeadlineAlert(subjectName: String, recoveryNeeded: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-deadline-\(subjectName.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard recoveryNeeded > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subjectName): Recovery Deadline"
        content.body = "Plan a recovery streak. You still need \(recoveryNeeded) attended classes to get back on track."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 8, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "recovery_deadline"))
    }

    private static func scheduleWeekly(
        center: UNUserNotificationCenter,
        identifier: String,
        weekday: Int,
        hour: Int,
        title: String,
        body: String,
        type: String
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: type))
    }
}
