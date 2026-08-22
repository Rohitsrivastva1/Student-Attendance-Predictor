//
//  SemesterSettings.swift
//  Student Attendance Predictor
//
//  Lightweight semester date range used to auto-fill forecast weeks remaining.
//

import Foundation

enum SemesterSettings {
    struct Progress: Equatable {
        let currentWeek: Int
        let totalWeeks: Int
        let weeksRemaining: Int
        let fractionComplete: Double
    }

    private enum Keys {
        static let start = "semester.startDate"
        static let end = "semester.endDate"
        static let fallbackWeeks = "semester.fallbackWeeks"
    }

    private static let defaults = UserDefaults.standard

    static var startDate: Date? {
        get { date(forKey: Keys.start) }
        set { setDate(newValue, forKey: Keys.start) }
    }

    static var endDate: Date? {
        get { date(forKey: Keys.end) }
        set { setDate(newValue, forKey: Keys.end) }
    }

    /// Manual override when semester dates are not set.
    static var fallbackWeeks: Int {
        get {
            let stored = defaults.object(forKey: Keys.fallbackWeeks) as? Int
            return min(max(stored ?? 8, 1), 24)
        }
        set {
            defaults.set(min(max(newValue, 1), 24), forKey: Keys.fallbackWeeks)
        }
    }

    /// Weeks left until semester end (inclusive of the current week). Falls back to `fallbackWeeks`.
    static func weeksRemaining(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let end = endDate else {
            return fallbackWeeks
        }

        let startOfToday = calendar.startOfDay(for: referenceDate)
        let endDay = calendar.startOfDay(for: end)

        if endDay < startOfToday {
            return 1
        }

        let days = calendar.dateComponents([.day], from: startOfToday, to: endDay).day ?? 0
        let weeks = Int(ceil(Double(days + 1) / 7.0))
        return min(max(weeks, 1), 24)
    }

    static var hasSemesterDates: Bool {
        endDate != nil
    }

    /// Week N of M for the semester progress strip. Nil when end date is missing.
    static func progress(referenceDate: Date = Date(), calendar: Calendar = .current) -> Progress? {
        guard let start = startDate, let end = endDate else { return nil }

        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let today = calendar.startOfDay(for: referenceDate)

        guard endDay >= startDay else { return nil }

        let spanDays = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        let totalWeeks = min(max(Int(ceil(Double(spanDays) / 7.0)), 1), 24)

        let elapsedDays = max(0, calendar.dateComponents([.day], from: startDay, to: today).day ?? 0)
        let currentWeek = min(totalWeeks, max(1, elapsedDays / 7 + 1))
        let remaining = weeksRemaining(referenceDate: referenceDate, calendar: calendar)
        let denominator = max(totalWeeks - 1, 1)
        let fraction = min(1, max(0, Double(currentWeek - 1) / Double(denominator)))

        return Progress(
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            weeksRemaining: remaining,
            fractionComplete: fraction
        )
    }

    /// Seeds a default semester window (today → +16 weeks) once, so weeks can auto-detect.
    static func ensureDefaultDatesIfNeeded(referenceDate: Date = Date(), calendar: Calendar = .current) {
        guard endDate == nil else { return }
        startDate = calendar.startOfDay(for: referenceDate)
        endDate = calendar.date(byAdding: .weekOfYear, value: 16, to: startDate ?? referenceDate)
    }

    private static func date(forKey key: String) -> Date? {
        guard let interval = defaults.object(forKey: key) as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func setDate(_ date: Date?, forKey key: String) {
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
