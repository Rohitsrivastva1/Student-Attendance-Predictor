//
//  MultiFeatureEngagementStore.swift
//  Student Attendance Predictor
//
//  Tracks how many distinct product areas a user touches each ISO week.
//  North-star: multi-feature WAU (2+ of mark / skip / focus / forecast / widget).
//

import Foundation

enum MultiFeatureKind: String, CaseIterable, Codable {
    case mark
    case skipPlanner = "skip_planner"
    case focus
    case forecast
    case widget
}

enum MultiFeatureEngagementStore {
    private static let weekKey = "multiFeature.week"
    private static let usedKey = "multiFeature.used"
    private static let didLogMultiKey = "multiFeature.didLogMulti"

    private static var defaults: UserDefaults { .standard }

    static func record(_ kind: MultiFeatureKind) {
        rotateWeekIfNeeded()
        var used = Set(loadUsed())
        guard used.insert(kind.rawValue).inserted else {
            syncUserProperty(count: used.count)
            return
        }
        saveUsed(Array(used))
        syncUserProperty(count: used.count)

        if used.count >= 2, defaults.bool(forKey: didLogMultiKey) == false {
            defaults.set(true, forKey: didLogMultiKey)
            AnalyticsService.shared.log(
                .multiFeatureWeeklyUser(featureCount: used.count, features: Array(used).sorted().joined(separator: ","))
            )
        }
    }

    static func currentWeekFeatureCount() -> Int {
        rotateWeekIfNeeded()
        return loadUsed().count
    }

    static func currentWeekFeatures() -> Set<MultiFeatureKind> {
        rotateWeekIfNeeded()
        return Set(loadUsed().compactMap { MultiFeatureKind(rawValue: $0) })
    }

    #if DEBUG
    static func resetForDebug() {
        defaults.removeObject(forKey: weekKey)
        defaults.removeObject(forKey: usedKey)
        defaults.removeObject(forKey: didLogMultiKey)
    }
    #endif

    private static func rotateWeekIfNeeded() {
        let week = isoWeekKey()
        if defaults.string(forKey: weekKey) != week {
            defaults.set(week, forKey: weekKey)
            defaults.set([], forKey: usedKey)
            defaults.set(false, forKey: didLogMultiKey)
        }
    }

    private static func loadUsed() -> [String] {
        defaults.stringArray(forKey: usedKey) ?? []
    }

    private static func saveUsed(_ values: [String]) {
        defaults.set(values, forKey: usedKey)
    }

    private static func syncUserProperty(count: Int) {
        AnalyticsService.shared.setUserProperty(String(count), forName: "multi_feature_count_week")
        AnalyticsService.shared.setUserProperty(count >= 2 ? "true" : "false", forName: "is_multi_feature_user")
    }

    private static func isoWeekKey(date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }
}
