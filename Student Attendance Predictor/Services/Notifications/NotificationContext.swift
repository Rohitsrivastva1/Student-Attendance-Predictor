//
//  NotificationContext.swift
//  Student Attendance Predictor
//
//  Attendance snapshot used by the personality engine. Values come from
//  existing calculation / timetable helpers — nothing is recomputed here.
//

import Foundation

enum AttendanceTrendDirection: String, Equatable {
    case improving
    case declining
    case stable
}

struct NotificationContext: Equatable {
    var attendancePercentage: Double
    var requiredPercentage: Double
    var safeBunks: Int
    var recoveryNeeded: Int
    var subjectName: String
    var skipVerb: String
    var skipNoun: String
    var classesToday: Int
    var hasData: Bool
    var isSafe: Bool
    var hasLoggedToday: Bool
    var isWeekend: Bool
    var isWeeklyHoliday: Bool
    var streakDays: Int
    var trend: AttendanceTrendDirection
    var weeklyMissed: Int
    var weeklyAttended: Int
    var atRiskSubjects: Int
    var dayKey: String
    /// Calendar.weekday (1=Sun … 7=Sat) → classes across all subjects.
    var classesByWeekday: [Int: Int]

    var roundedPercent: Int { Int(attendancePercentage.rounded()) }
    var roundedRequired: Int { Int(requiredPercentage.rounded()) }

    var isCloseToMinimum: Bool {
        guard hasData, isSafe else { return false }
        let margin = attendancePercentage - requiredPercentage
        return margin <= NotificationPersonalityConfig.closeToMinimumPoints || safeBunks <= 1
    }

    var shortSubjectName: String {
        let trimmed = subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "this class" }
        if trimmed.count <= 16 { return trimmed }
        return String(trimmed.prefix(15)) + "…"
    }

    var skipVerbTitle: String {
        skipVerb.prefix(1).uppercased() + skipVerb.dropFirst()
    }

    var schedulingSignature: String {
        [
            dayKey,
            "\(roundedPercent)",
            "\(safeBunks)",
            "\(recoveryNeeded)",
            subjectName,
            hasLoggedToday ? "1" : "0",
            "\(classesToday)",
            NotificationPersonalityConfig.enableWittyCopy ? "w" : "p",
            UserDefaults.standard.bool(forKey: "iap.isPro") ? "pro" : "free",
            trend.rawValue
        ].joined(separator: "|")
    }

    func interpolations() -> [String: String] {
        [
            "attendance_percentage": "\(roundedPercent)%",
            "required_percentage": "\(roundedRequired)%",
            "safe_bunks": "\(max(0, safeBunks))",
            "recovery_needed": "\(max(0, recoveryNeeded))",
            "classes_today": "\(max(0, classesToday))",
            "subject_name": shortSubjectName,
            "skip_verb": skipVerb,
            "skip_noun": skipNoun,
            "skip_verb_title": skipVerbTitle,
            "streak_days": "\(max(0, streakDays))"
        ]
    }

    func classes(on date: Date, calendar: Calendar = .current) -> Int {
        classesByWeekday[calendar.component(.weekday, from: date)] ?? 0
    }

    func applying(subject: SubjectSummary, skipVerb: String, skipNoun: String) -> NotificationContext {
        var copy = self
        copy.subjectName = subject.name
        copy.attendancePercentage = subject.currentPercentage
        copy.requiredPercentage = subject.requiredPercentage
        copy.safeBunks = subject.status == .safe ? subject.bunkAllowed : 0
        copy.recoveryNeeded = subject.status == .risk ? subject.recoveryNeeded : 0
        copy.isSafe = subject.status == .safe
        copy.hasData = subject.totalClasses > 0
        copy.skipVerb = skipVerb
        copy.skipNoun = skipNoun
        return copy
    }
}

enum NotificationCopyRenderer {
    static func render(_ template: String, context: NotificationContext) -> String {
        var result = template
        for (key, value) in context.interpolations() {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return collapseSpaces(result)
    }

    static func maybeStripEmoji(_ text: String, keep: Bool) -> String {
        guard keep == false else { return text }
        let filtered = text.unicodeScalars.filter { scalar in
            if scalar.properties.isEmojiPresentation { return false }
            if scalar.properties.isEmojiModifier || scalar.properties.isEmojiModifierBase { return false }
            if scalar.value == 0xFE0F { return false }
            return true
        }
        return collapseSpaces(String(String.UnicodeScalarView(filtered)))
    }

    private static func collapseSpaces(_ text: String) -> String {
        text
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " +([,.!?])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
