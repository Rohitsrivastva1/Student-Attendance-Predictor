//
//  StudentMarket.swift
//  Student Attendance Predictor
//
//  Region-aware defaults and copy for IN / US / UK audiences.
//

import Foundation

enum StudentMarket: String, CaseIterable, Identifiable {
    case india = "IN"
    case unitedStates = "US"
    case unitedKingdom = "GB"
    case other = "OTHER"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .india: return "India"
        case .unitedStates: return "United States"
        case .unitedKingdom: return "United Kingdom"
        case .other: return "Other"
        }
    }

    /// Verb for missing class intentionally.
    var skipVerb: String {
        switch self {
        case .india: return "bunk"
        case .unitedStates, .unitedKingdom, .other: return "skip"
        }
    }

    var skipVerbPast: String {
        switch self {
        case .india: return "bunked"
        default: return "skipped"
        }
    }

    var skipNounPlural: String {
        switch self {
        case .india: return "bunks"
        default: return "skips"
        }
    }

    var skipNounPluralTitle: String {
        skipNounPlural.prefix(1).uppercased() + skipNounPlural.dropFirst()
    }

    /// India: subject · US/UK: course / module
    var courseNoun: String {
        switch self {
        case .india: return "subject"
        case .unitedKingdom: return "module"
        case .unitedStates, .other: return "course"
        }
    }

    var courseNounPlural: String {
        switch self {
        case .india: return "subjects"
        case .unitedKingdom: return "modules"
        case .unitedStates, .other: return "courses"
        }
    }

    var courseNounPluralTitle: String {
        courseNounPlural.prefix(1).uppercased() + courseNounPlural.dropFirst()
    }

    /// Default attendance target % (India policies are stricter on average).
    var defaultRequiredAttendance: Double {
        switch self {
        case .india: return 75
        case .unitedStates, .unitedKingdom, .other: return 80
        }
    }

    var prefersGPA: Bool {
        self == .unitedStates || self == .unitedKingdom || self == .other
    }

    var homeMarketTip: String? {
        switch self {
        case .unitedStates:
            return "US mode: open Grades for GPA + exam deadlines. Attendance still lives on Home."
        case .unitedKingdom:
            return "UK mode: open Grades for modules + deadlines. Attendance still lives on Home."
        case .other:
            return "Open Grades for GPA + deadlines. Attendance still lives on Home."
        case .india:
            return nil
        }
    }

    var academicsHeadline: String {
        switch self {
        case .india:
            return "Academics"
        case .unitedStates:
            return "Grades & Deadlines"
        case .unitedKingdom:
            return "Modules & Deadlines"
        case .other:
            return "Grades & Deadlines"
        }
    }

    var gpaScaleLabel: String {
        switch self {
        case .unitedKingdom:
            return "UK % / classification helper"
        case .unitedStates, .other:
            return "US 4.0 GPA"
        case .india:
            return "GPA (4.0 scale)"
        }
    }

    static func detect(from locale: Locale = .current) -> StudentMarket {
        let region = locale.region?.identifier.uppercased()
            ?? locale.identifier.split(separator: "_").last.map(String.init)?.uppercased()
            ?? ""
        switch region {
        case "IN": return .india
        case "US": return .unitedStates
        case "GB", "UK": return .unitedKingdom
        default: return .other
        }
    }
}

@MainActor
enum StudentMarketStore {
    private static let key = "student.market.override"

    static var current: StudentMarket {
        get {
            if let raw = UserDefaults.standard.string(forKey: key),
               let market = StudentMarket(rawValue: raw) {
                return market
            }
            return StudentMarket.detect()
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    static var usesSystemDetection: Bool {
        UserDefaults.standard.string(forKey: key) == nil
    }

    static func resetToSystem() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
