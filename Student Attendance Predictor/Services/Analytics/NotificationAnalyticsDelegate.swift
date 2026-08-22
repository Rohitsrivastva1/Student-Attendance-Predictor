//
//  NotificationAnalyticsDelegate.swift
//  Student Attendance Predictor
//
//  Acts as the UNUserNotificationCenter delegate so we can:
//  - show local notifications while the app is in the foreground, and
//  - log when a user taps (opens) or dismisses a notification.
//
//  Set as the delegate once at launch from the App entry point.
//

import Foundation
import UserNotifications

final class NotificationAnalyticsDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationAnalyticsDelegate()

    func register() {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.registerPersonalityCategory()
    }

    /// Maps a scheduled notification identifier to a stable analytics type.
    static func type(for identifier: String) -> String {
        if identifier.hasPrefix("personality-") { return "personality" }
        if identifier.hasPrefix("attendance-risk") { return "risk" }
        if identifier.hasPrefix("attendance-buffer") { return "low_buffer" }
        if identifier.hasPrefix("attendance-class-reminder") { return "class_reminder" }
        if identifier.hasPrefix("attendance-monday-kickoff") { return "monday_kickoff" }
        if identifier.hasPrefix("attendance-friday-buffer") { return "friday_buffer" }
        if identifier.hasPrefix("attendance-deadline") { return "recovery_deadline" }
        if identifier.hasPrefix("academic-deadline") { return "academic_deadline" }
        if identifier.hasPrefix("focus-timer") { return "focus_timer" }
        if identifier == "pro-weekly-digest" { return "weekly_digest" }
        if identifier == "retention-day2-mark" { return "day2_mark" }
        if identifier == "retention-evening-mark" { return "evening_mark" }
        return "other"
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        let identifier = request.identifier
        let userInfo = request.content.userInfo
        let type = Self.type(for: identifier)

        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            if let category = userInfo["category"] as? String,
               let templateID = userInfo["template_id"] as? String {
                AnalyticsService.shared.log(
                    .personalityNotificationDismissed(category: category, templateID: templateID)
                )
            }
            completionHandler()
            return
        }

        AnalyticsService.shared.handleNotificationOpened(type: type)
        NotificationEngagementStore.recordOpened()
        if let category = userInfo["category"] as? String,
           let templateID = userInfo["template_id"] as? String {
            let variant = userInfo["variant"] as? String ?? "a"
            AnalyticsService.shared.log(
                .personalityNotificationOpened(
                    category: category,
                    templateID: templateID,
                    variant: variant
                )
            )
        }

        if let route = NotificationRouteStore.route(from: userInfo) {
            Task { @MainActor in
                NotificationRouteStore.shared.setPending(route)
            }
        }
        completionHandler()
    }
}
