//
//  NotificationAnalyticsDelegate.swift
//  Student Attendance Predictor
//
//  Acts as the UNUserNotificationCenter delegate so we can:
//  - show local notifications while the app is in the foreground, and
//  - log when a user taps (opens) a notification, with its category type.
//
//  Set as the delegate once at launch from the App entry point.
//

import Foundation
import UserNotifications

final class NotificationAnalyticsDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationAnalyticsDelegate()

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Maps a scheduled notification identifier to a stable analytics type.
    static func type(for identifier: String) -> String {
        if identifier.hasPrefix("attendance-risk") { return "risk" }
        if identifier.hasPrefix("attendance-buffer") { return "low_buffer" }
        if identifier.hasPrefix("attendance-class-reminder") { return "class_reminder" }
        if identifier.hasPrefix("attendance-deadline") { return "recovery_deadline" }
        return "other"
    }

    // Show banners/sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // The user tapped a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let type = Self.type(for: identifier)
        AnalyticsService.shared.handleNotificationOpened(type: type)
        completionHandler()
    }
}
