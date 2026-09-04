//
//  AttendanceModel.swift
//  Student Attendance Predictor
//

import Foundation

/// One-hour lecture slots from 8am–5pm. Students tap chips; we never ask for start *and* end.
struct CollegePeriod: Hashable, Identifiable, Comparable {
    let startHour: Int
    var id: Int { startHour }

    static let firstHour = 8
    static let lastHour = 16
    static let gridHours: [Int] = Array(firstHour...lastHour)
    static let grid: [CollegePeriod] = gridHours.map { CollegePeriod(startHour: $0) }

    var endHour: Int { startHour + 1 }

    var chipLabel: String { Self.hourLabel(startHour) }

    var rangeLabel: String {
        "\(Self.hourLabel(startHour))–\(Self.hourLabel(endHour))"
    }

    static func hourLabel(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        if h == 0 || h == 12 { return "12" }
        if h < 12 { return "\(h)" }
        return "\(h - 12)"
    }

    static func current(at date: Date = Date(), calendar: Calendar = .current) -> CollegePeriod? {
        let hour = calendar.component(.hour, from: date)
        guard gridHours.contains(hour) else { return nil }
        return CollegePeriod(startHour: hour)
    }

    static func < (lhs: CollegePeriod, rhs: CollegePeriod) -> Bool {
        lhs.startHour < rhs.startHour
    }
}

struct WeeklySchedule: Equatable {
    var monday: Int
    var tuesday: Int
    var wednesday: Int
    var thursday: Int
    var friday: Int
    var saturday: Int
    var sunday: Int
    /// Start hours (8…16) this subject occupies. Empty = count-only legacy day.
    var mondayHours: [Int]
    var tuesdayHours: [Int]
    var wednesdayHours: [Int]
    var thursdayHours: [Int]
    var fridayHours: [Int]
    var saturdayHours: [Int]
    var sundayHours: [Int]

    static let empty = WeeklySchedule(
        monday: 0,
        tuesday: 0,
        wednesday: 0,
        thursday: 0,
        friday: 0,
        saturday: 0,
        sunday: 0,
        mondayHours: [],
        tuesdayHours: [],
        wednesdayHours: [],
        thursdayHours: [],
        fridayHours: [],
        saturdayHours: [],
        sundayHours: []
    )

    var totalPerWeek: Int {
        monday + tuesday + wednesday + thursday + friday + saturday + sunday
    }

    var hasAnyPeriodTimes: Bool {
        mondayHours.isEmpty == false
            || tuesdayHours.isEmpty == false
            || wednesdayHours.isEmpty == false
            || thursdayHours.isEmpty == false
            || fridayHours.isEmpty == false
            || saturdayHours.isEmpty == false
            || sundayHours.isEmpty == false
    }
}

extension WeeklySchedule: Codable {
    enum CodingKeys: String, CodingKey {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday
        case mondayHours, tuesdayHours, wednesdayHours, thursdayHours
        case fridayHours, saturdayHours, sundayHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        monday = try container.decodeIfPresent(Int.self, forKey: .monday) ?? 0
        tuesday = try container.decodeIfPresent(Int.self, forKey: .tuesday) ?? 0
        wednesday = try container.decodeIfPresent(Int.self, forKey: .wednesday) ?? 0
        thursday = try container.decodeIfPresent(Int.self, forKey: .thursday) ?? 0
        friday = try container.decodeIfPresent(Int.self, forKey: .friday) ?? 0
        saturday = try container.decodeIfPresent(Int.self, forKey: .saturday) ?? 0
        sunday = try container.decodeIfPresent(Int.self, forKey: .sunday) ?? 0
        mondayHours = Self.sanitizedHours(try container.decodeIfPresent([Int].self, forKey: .mondayHours) ?? [])
        tuesdayHours = Self.sanitizedHours(try container.decodeIfPresent([Int].self, forKey: .tuesdayHours) ?? [])
        wednesdayHours = Self.sanitizedHours(try container.decodeIfPresent([Int].self, forKey: .wednesdayHours) ?? [])
        thursdayHours = Self.sanitizedHours(try container.decodeIfPresent([Int].self, forKey: .thursdayHours) ?? [])
        fridayHours = Self.sanitizedHours(try container.decodeIfPresent([Int].self, forKey: .fridayHours) ?? [])
        saturdayHours = Self.sanitizedHours(try container.decodeIfPresent([Int].self, forKey: .saturdayHours) ?? [])
        sundayHours = Self.sanitizedHours(try container.decodeIfPresent([Int].self, forKey: .sundayHours) ?? [])
        syncCountsFromHours()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(monday, forKey: .monday)
        try container.encode(tuesday, forKey: .tuesday)
        try container.encode(wednesday, forKey: .wednesday)
        try container.encode(thursday, forKey: .thursday)
        try container.encode(friday, forKey: .friday)
        try container.encode(saturday, forKey: .saturday)
        try container.encode(sunday, forKey: .sunday)
        try container.encode(mondayHours, forKey: .mondayHours)
        try container.encode(tuesdayHours, forKey: .tuesdayHours)
        try container.encode(wednesdayHours, forKey: .wednesdayHours)
        try container.encode(thursdayHours, forKey: .thursdayHours)
        try container.encode(fridayHours, forKey: .fridayHours)
        try container.encode(saturdayHours, forKey: .saturdayHours)
        try container.encode(sundayHours, forKey: .sundayHours)
    }

    private static func sanitizedHours(_ hours: [Int]) -> [Int] {
        Array(Set(hours.filter { CollegePeriod.gridHours.contains($0) })).sorted()
    }

    mutating func syncCountsFromHours() {
        if mondayHours.isEmpty == false { monday = mondayHours.count }
        if tuesdayHours.isEmpty == false { tuesday = tuesdayHours.count }
        if wednesdayHours.isEmpty == false { wednesday = wednesdayHours.count }
        if thursdayHours.isEmpty == false { thursday = thursdayHours.count }
        if fridayHours.isEmpty == false { friday = fridayHours.count }
        if saturdayHours.isEmpty == false { saturday = saturdayHours.count }
        if sundayHours.isEmpty == false { sunday = sundayHours.count }
    }
}

struct AttendanceInput {
    let totalClasses: Int
    let attendedClasses: Int
    let requiredPercentage: Double
}

struct AttendanceResult: Equatable {
    let currentPercentage: Double
    let bunkAllowed: Int
    let recoveryNeeded: Int
    let status: AttendanceStatus
}

struct AttendanceTrendPoint: Codable, Equatable, Identifiable {
    let timestamp: Date
    let percentage: Double

    var id: TimeInterval { timestamp.timeIntervalSince1970 }
}

enum AttendanceStatus: String, Equatable {
    case safe = "Safe"
    case risk = "Risk"
}

enum RiskAlertLevel: String {
    case stable = "Safe"
    case warning = "Warning"
    case critical = "Critical"
}

struct SubjectSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let totalClasses: Int
    let attendedClasses: Int
    let requiredPercentage: Double
    let weeklySchedule: WeeklySchedule
    let createdAt: Date

    var currentPercentage: Double {
        CalculationService.currentPercentage(attended: attendedClasses, total: totalClasses)
    }

    var status: AttendanceStatus {
        currentPercentage >= requiredPercentage ? .safe : .risk
    }

    var bunkAllowed: Int {
        CalculationService.maxBunk(
            attended: attendedClasses,
            total: totalClasses,
            required: requiredPercentage
        )
    }

    var recoveryNeeded: Int {
        CalculationService.requiredClasses(
            attended: attendedClasses,
            total: totalClasses,
            required: requiredPercentage
        )
    }

    /// Short action chip for Overview cards: "Safe", "Skip N", or "Recover".
    var actionChipLabel: String {
        guard totalClasses > 0 else { return "Start" }
        if status == .safe {
            return bunkAllowed > 0 ? "Skip \(bunkAllowed)" : "Safe"
        }
        return "Recover"
    }
}

struct SubjectForecast: Identifiable, Equatable {
    let id: UUID
    let subjectName: String
    let currentPercentage: Double
    let forecastedPercentage: Double
    let requiredPercentage: Double
    let expectedClasses: Int
    let forecastAttended: Int
    let forecastTotal: Int
    let riskLevel: RiskAlertLevel
    /// True when this subject has no weekly timetable and the forecast used the shared classes/week estimate.
    let usedFallbackSchedule: Bool

    var recoveryNeeded: Int {
        CalculationService.requiredClasses(
            attended: forecastAttended,
            total: forecastTotal,
            required: requiredPercentage
        )
    }

    var bunkAllowedAfterProjection: Int {
        CalculationService.maxBunk(
            attended: forecastAttended,
            total: forecastTotal,
            required: requiredPercentage
        )
    }

    var isStableProjection: Bool {
        abs(forecastedPercentage - currentPercentage) < 0.5
    }

    var willFallBelowTarget: Bool {
        forecastedPercentage < requiredPercentage
    }

    /// The one-line answer students care about after projecting.
    var primaryActionMessage: String {
        if expectedClasses == 0 {
            return "Set semester dates or a timetable to project."
        }
        if willFallBelowTarget || riskLevel == .critical {
            let need = max(1, recoveryNeeded)
            return "Attend \(need) consecutive class\(need == 1 ? "" : "es")"
        }
        let bunks = bunkAllowedAfterProjection
        if bunks > 0 {
            return "You can safely bunk \(bunks) more class\(bunks == 1 ? "" : "es")"
        }
        return "Stay on the safe line — no bunk buffer left"
    }
}

struct WeeklyAttendanceSummary: Equatable {
    let attendedClasses: Int
    let missedClasses: Int
    let holidayDays: Int
    let percentageDelta: Double
}

struct FacultyDashboardSummary: Equatable {
    let totalSubjects: Int
    let safeSubjects: Int
    let riskSubjects: Int
    let averageAttendance: Double
    let mostAtRiskSubject: SubjectSummary?
}
