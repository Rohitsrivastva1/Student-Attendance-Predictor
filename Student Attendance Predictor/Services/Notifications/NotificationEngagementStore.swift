//
//  NotificationEngagementStore.swift
//  Student Attendance Predictor
//
//  Tracks notification sends vs opens. Disengaged users get throttled so
//  we don't train people to ignore Bunk Planner alerts.
//

import Foundation

enum NotificationEngagementStore {
    private static let scheduledKey = "notif.engagement.scheduled"
    private static let openedKey = "notif.engagement.opened"
    private static let lastOpenedKey = "notif.engagement.lastOpened"
    private static let habitWeekKey = "notif.engagement.habitWeek"
    private static let habitWeekCountKey = "notif.engagement.habitWeekCount"

    private static var defaults: UserDefaults { .standard }

    static func recordScheduled() {
        defaults.set(defaults.integer(forKey: scheduledKey) + 1, forKey: scheduledKey)
    }

    static func recordOpened() {
        defaults.set(defaults.integer(forKey: openedKey) + 1, forKey: openedKey)
        defaults.set(Date(), forKey: lastOpenedKey)
    }

    /// Five or more sends with zero opens — habit notifications become weekly-only.
    static var shouldThrottleHabitNotifications: Bool {
        let scheduled = defaults.integer(forKey: scheduledKey)
        let opened = defaults.integer(forKey: openedKey)
        return scheduled >= 5 && opened == 0
    }

    /// Disengaged users: allow at most one habit notification per ISO week.
    static func canSendHabitNotification(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard shouldThrottleHabitNotifications else { return true }
        let week = isoWeekKey(now, calendar: calendar)
        if defaults.string(forKey: habitWeekKey) != week {
            defaults.set(week, forKey: habitWeekKey)
            defaults.set(0, forKey: habitWeekCountKey)
        }
        let count = defaults.integer(forKey: habitWeekCountKey)
        guard count < 1 else { return false }
        defaults.set(count + 1, forKey: habitWeekCountKey)
        return true
    }

    private static func isoWeekKey(_ date: Date, calendar: Calendar) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = calendar.timeZone
        let year = cal.component(.yearForWeekOfYear, from: date)
        let week = cal.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }
}
