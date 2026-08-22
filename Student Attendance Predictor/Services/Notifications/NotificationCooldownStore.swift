//
//  NotificationCooldownStore.swift
//  Student Attendance Predictor
//
//  Frequency caps, per-category cooldowns, and template rotation.
//  High-priority alerts are never blocked by low-priority humorous ones.
//

import Foundation

struct PersonalitySendRecord: Codable, Equatable {
    var dateKey: String
    var category: PersonalityNotificationCategory
    var templateID: String
    var slot: NotificationSlot
    var timestamp: TimeInterval
    var reserved: Bool
}

enum NotificationCooldownStore {
    private static let recordsKey = "notif.personality.records"
    private static let recentTemplatesKey = "notif.personality.recentTemplates"
    private static let maxRecentTemplates = 12
    private static let maxRecordAgeDays = 21

    private static var defaults: UserDefaults { .standard }

    static func canSend(
        category: PersonalityNotificationCategory,
        slot: NotificationSlot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        prune(now: now, calendar: calendar)
        let records = loadRecords()
        let dayKey = Self.dayKey(now, calendar: calendar)
        let priority = category.priority

        if slot != .immediate {
            guard NotificationEngagementStore.canSendHabitNotification(now: now, calendar: calendar) else {
                return false
            }
            // Habit slots are the planned 1–2/day. Allow them even if an
            // immediate warning already fired, unless this category is cooling down.
            return categoryCooldownElapsed(category, records: records, now: now)
        }

        if categoryCooldownElapsed(category, records: records, now: now) == false {
            return false
        }

        let todaysCount = records.filter { $0.dateKey == dayKey }.count
        if priority == .high {
            return true
        }
        return todaysCount < NotificationPersonalityConfig.maxDailyNotifications
    }

    static func record(
        payload: PersonalityNotificationPayload,
        on date: Date,
        reserved: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        prune(now: now, calendar: calendar)
        var records = loadRecords()
        records.append(
            PersonalitySendRecord(
                dateKey: dayKey(date, calendar: calendar),
                category: payload.category,
                templateID: payload.templateID,
                slot: payload.slot,
                timestamp: now.timeIntervalSince1970,
                reserved: reserved
            )
        )
        saveRecords(records)
        rebuildRecentTemplates(from: records)
    }

    /// Drop booked-but-unsent slots before a reschedule so rotation isn't
    /// filled with templates that never fired.
    static func clearReserved(now: Date = Date(), calendar: Calendar = .current) {
        prune(now: now, calendar: calendar)
        let kept = loadRecords().filter { $0.reserved == false }
        saveRecords(kept)
        rebuildRecentTemplates(from: kept)
    }

    static func recentlyUsedTemplateIDs() -> Set<String> {
        Set(loadRecentTemplates())
    }

    private static func rebuildRecentTemplates(from records: [PersonalitySendRecord]) {
        var unique: [String] = []
        var seen = Set<String>()
        for record in records.reversed() {
            if seen.insert(record.templateID).inserted {
                unique.append(record.templateID)
            }
            if unique.count >= maxRecentTemplates { break }
        }
        defaults.set(Array(unique.reversed()), forKey: recentTemplatesKey)
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    private static func categoryCooldownElapsed(
        _ category: PersonalityNotificationCategory,
        records: [PersonalitySendRecord],
        now: Date
    ) -> Bool {
        let hours = NotificationPersonalityConfig.cooldownHours(for: category)
        let window = hours * 3600
        return records.contains {
            $0.category == category
                && $0.reserved == false
                && now.timeIntervalSince1970 - $0.timestamp < window
        } == false
    }

    private static func prune(now: Date, calendar: Calendar) {
        let cutoff = calendar.date(byAdding: .day, value: -maxRecordAgeDays, to: now) ?? now
        let cutoffStamp = cutoff.timeIntervalSince1970
        let trimmed = loadRecords().filter { $0.timestamp >= cutoffStamp }
        saveRecords(trimmed)
    }

    private static func loadRecords() -> [PersonalitySendRecord] {
        guard let data = defaults.data(forKey: recordsKey) else { return [] }
        return (try? JSONDecoder().decode([PersonalitySendRecord].self, from: data)) ?? []
    }

    private static func saveRecords(_ records: [PersonalitySendRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    private static func loadRecentTemplates() -> [String] {
        defaults.stringArray(forKey: recentTemplatesKey) ?? []
    }
}
