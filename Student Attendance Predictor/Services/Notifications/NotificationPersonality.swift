//
//  NotificationPersonality.swift
//  Student Attendance Predictor
//
//  Categories, priority, slots, routes, and user-facing config.
//  Copy lives in NotificationTemplates; selection lives in NotificationEngine.
//

import Foundation

enum PersonalityNotificationCategory: String, CaseIterable, Codable {
    case funny
    case curiosity
    case savage
    case bunkAvailable = "bunk_available"
    case bunkNotAvailable = "bunk_not_available"
    case lowAttendance = "low_attendance"
    case attendanceWarning = "attendance_warning"
    case classReminder = "class_reminder"
    case streak

    var priority: NotificationPriority {
        switch self {
        case .lowAttendance, .attendanceWarning:
            return .high
        case .classReminder, .bunkAvailable, .bunkNotAvailable:
            return .normal
        case .funny, .curiosity, .savage, .streak:
            return .low
        }
    }

    var route: NotificationRoute {
        switch self {
        case .bunkAvailable, .lowAttendance, .attendanceWarning:
            return .skipPlanner
        case .bunkNotAvailable, .classReminder:
            return .markToday
        case .streak:
            return .insights
        case .funny, .curiosity, .savage:
            return .markToday
        }
    }
}

enum NotificationPriority: String, Codable {
    case low
    case normal
    case high
}

enum NotificationSlot: String, Codable {
    case immediate
    case evening
    case morning
    case monday
    case friday
}

enum NotificationRoute: String, Codable {
    case home
    case insights
    case log
    case overview
    case markToday = "mark_today"
    case skipPlanner = "skip_planner"
    case tools
}

struct PersonalityNotificationPayload: Equatable {
    var category: PersonalityNotificationCategory
    var templateID: String
    var variant: String
    var title: String
    var body: String
    var route: NotificationRoute
    var priority: NotificationPriority
    var slot: NotificationSlot

    var userInfo: [AnyHashable: Any] {
        [
            "type": "personality",
            "category": category.rawValue,
            "template_id": templateID,
            "variant": variant,
            "deep_link": route.rawValue,
            "slot": slot.rawValue,
            "priority": priority.rawValue
        ]
    }
}

enum NotificationPersonalityConfig {
    private enum Keys {
        static let witty = "feature.wittyNotificationsEnabled"
        static let humor = "feature.notificationHumorEnabled"
        static let savage = "feature.notificationSavageEnabled"
        static let curiosity = "feature.notificationCuriosityEnabled"
    }

    static let maxDailyNotifications = 3
    static let emojiProbability = 0.35
    static let closeToMinimumPoints = 3.0
    static let eveningHour = 20
    static let morningHour = 8
    static let mondayHour = 9
    static let fridayHour = 17
    static let weeklyDigestHour = 19
    static let upcomingEveningCount = 3
    static let upcomingMorningCount = 2
    static let categoryIdentifier = "bunk_planner_personality"

    static var enableWittyCopy: Bool {
        get { UserDefaults.standard.object(forKey: Keys.witty) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.witty) }
    }

    static var enableHumor: Bool {
        get { UserDefaults.standard.object(forKey: Keys.humor) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.humor) }
    }

    static var enableSavageMode: Bool {
        get { UserDefaults.standard.object(forKey: Keys.savage) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.savage) }
    }

    static var enableCuriosity: Bool {
        get { UserDefaults.standard.object(forKey: Keys.curiosity) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.curiosity) }
    }

    static func cooldownHours(for category: PersonalityNotificationCategory) -> Double {
        switch category {
        case .funny: return 48
        case .curiosity: return 24
        case .savage: return 36
        case .bunkAvailable: return 24
        case .bunkNotAvailable: return 24
        case .lowAttendance: return 24
        case .attendanceWarning: return 24
        case .classReminder: return 18
        case .streak: return 48
        }
    }
}
