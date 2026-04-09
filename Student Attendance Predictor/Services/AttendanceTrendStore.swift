//
//  AttendanceTrendStore.swift
//  Student Attendance Predictor
//

import Foundation

enum AttendanceTrendStore {
    private static let keyPrefix = "attendance.trend."
    private static let maxPoints = 20
    private static let minCaptureInterval: TimeInterval = 60
    private static let minPercentageDelta = 0.05

    static func load(subjectID: UUID) -> [AttendanceTrendPoint] {
        guard let raw = UserDefaults.standard.data(forKey: key(for: subjectID)) else { return [] }
        guard let points = try? JSONDecoder().decode([AttendanceTrendPoint].self, from: raw) else { return [] }
        return points.sorted { $0.timestamp < $1.timestamp }
    }

    static func append(subjectID: UUID, percentage: Double, at date: Date = Date()) {
        var points = load(subjectID: subjectID)

        if let last = points.last {
            let isTooSoon = date.timeIntervalSince(last.timestamp) < minCaptureInterval
            let isSameValue = abs(last.percentage - percentage) < minPercentageDelta
            if isTooSoon && isSameValue {
                return
            }
        }

        points.append(AttendanceTrendPoint(timestamp: date, percentage: percentage))
        if points.count > maxPoints {
            points = Array(points.suffix(maxPoints))
        }

        guard let data = try? JSONEncoder().encode(points) else { return }
        UserDefaults.standard.set(data, forKey: key(for: subjectID))
    }

    private static func key(for subjectID: UUID) -> String {
        "\(keyPrefix)\(subjectID.uuidString)"
    }
}
