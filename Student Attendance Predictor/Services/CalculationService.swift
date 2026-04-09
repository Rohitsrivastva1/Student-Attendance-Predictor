//
//  CalculationService.swift
//  Student Attendance Predictor
//

import Foundation

enum CalculationService {
    static func currentPercentage(attended: Int, total: Int) -> Double {
        guard total > 0, attended >= 0 else {
            return 0
        }

        return (Double(attended) / Double(total)) * 100
    }

    static func maxBunk(attended: Int, total: Int, required: Double) -> Int {
        guard total >= 0, attended >= 0 else {
            return 0
        }

        guard required > 0 else {
            return Int.max
        }

        let requiredRatio = required / 100
        guard Double(attended) / Double(max(total, 1)) >= requiredRatio || total == 0 else {
            return 0
        }

        let maxAllowed = (Double(attended) / requiredRatio) - Double(total)
        return max(0, Int(floor(maxAllowed)))
    }

    static func requiredClasses(attended: Int, total: Int, required: Double) -> Int {
        guard total >= 0, attended >= 0 else {
            return 0
        }

        guard required > 0 else {
            return 0
        }

        // With no recorded classes yet, attending the next class establishes the ratio.
        if total == 0 {
            return 1
        }

        let current = Double(attended) / Double(total)
        let requiredRatio = required / 100

        guard current < requiredRatio else {
            return 0
        }

        let numerator = (requiredRatio * Double(total)) - Double(attended)
        let denominator = 1 - requiredRatio

        guard denominator > 0 else {
            return Int.max
        }

        return max(0, Int(ceil(numerator / denominator)))
    }

    static func projectedTotalClasses(
        schedule: WeeklySchedule,
        weeks: Int,
        holidayClassCount: Int
    ) -> Int {
        let scheduled = max(0, schedule.totalPerWeek * max(weeks, 0))
        return max(0, scheduled - max(holidayClassCount, 0))
    }

    static func riskLevel(
        attended: Int,
        total: Int,
        required: Double
    ) -> RiskAlertLevel {
        let current = currentPercentage(attended: attended, total: total)
        if current < required {
            return .critical
        }

        let bunkBuffer = maxBunk(attended: attended, total: total, required: required)
        if bunkBuffer <= 2 {
            return .warning
        }
        return .stable
    }

    static func forecast(
        attended: Int,
        total: Int,
        required: Double,
        expectedClasses: Int,
        expectedAbsences: Int
    ) -> SubjectForecastProjection {
        let boundedExpected = max(0, expectedClasses)
        let boundedAbsences = min(max(0, expectedAbsences), boundedExpected)
        let expectedAttendance = boundedExpected - boundedAbsences

        let forecastTotal = max(0, total + boundedExpected)
        let forecastAttended = max(0, attended + expectedAttendance)
        let forecastedPercentage = currentPercentage(attended: forecastAttended, total: forecastTotal)
        let riskLevel = self.riskLevel(attended: forecastAttended, total: forecastTotal, required: required)

        return SubjectForecastProjection(
            totalClasses: forecastTotal,
            attendedClasses: forecastAttended,
            forecastedPercentage: forecastedPercentage,
            riskLevel: riskLevel
        )
    }
}

struct SubjectForecastProjection {
    let totalClasses: Int
    let attendedClasses: Int
    let forecastedPercentage: Double
    let riskLevel: RiskAlertLevel
}
