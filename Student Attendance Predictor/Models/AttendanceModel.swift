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

struct AttendanceResult {
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

enum AttendanceStatus: String {
    case safe = "Safe"
    case risk = "Risk"
}

enum RiskAlertLevel: String {
    case stable = "Stable"
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
}

struct SubjectForecast: Identifiable, Equatable {
    let id: UUID
    let subjectName: String
    let currentPercentage: Double
    let forecastedPercentage: Double
    let requiredPercentage: Double
    let expectedClasses: Int
    let riskLevel: RiskAlertLevel
}

struct FacultyDashboardSummary: Equatable {
    let totalSubjects: Int
    let safeSubjects: Int
    let riskSubjects: Int
    let averageAttendance: Double
    let mostAtRiskSubject: SubjectSummary?
}
