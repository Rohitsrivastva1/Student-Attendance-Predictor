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

        let current = total == 0 ? 0 : Double(attended) / Double(total)
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
}
