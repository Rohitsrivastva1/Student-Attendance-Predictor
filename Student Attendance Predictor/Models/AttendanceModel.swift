//
//  AttendanceModel.swift
//  Student Attendance Predictor
//

import Foundation

struct WeeklySchedule: Codable, Equatable {
    var monday: Int
    var tuesday: Int
    var wednesday: Int
    var thursday: Int
    var friday: Int
    var saturday: Int
    var sunday: Int

    static let empty = WeeklySchedule(
        monday: 0,
        tuesday: 0,
        wednesday: 0,
        thursday: 0,
        friday: 0,
        saturday: 0,
        sunday: 0
    )

    var totalPerWeek: Int {
        monday + tuesday + wednesday + thursday + friday + saturday + sunday
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
