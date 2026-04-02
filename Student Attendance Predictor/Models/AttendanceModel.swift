//
//  AttendanceModel.swift
//  Student Attendance Predictor
//

import Foundation

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

enum AttendanceStatus: String {
    case safe = "Safe"
    case risk = "Risk"
}
