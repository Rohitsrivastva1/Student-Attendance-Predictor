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
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
        content.body = "Current attendance is \(String(format: "%.1f", currentPercentage))%. You can miss only \(max(0, bunkAllowed)) more classes safely."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func scheduleClassReminder(hour: Int = 8, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-class-reminder-daily"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        var dateComponents = DateComponents()
        dateComponents.hour = min(max(hour, 0), 23)
        dateComponents.minute = min(max(minute, 0), 59)

        let content = UNMutableNotificationContent()
        content.title = "Attendance Reminder"
        content.body = "Don't forget to mark and plan today's classes."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
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

        // Gentle follow-up reminder later in the day.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 8, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }
}
