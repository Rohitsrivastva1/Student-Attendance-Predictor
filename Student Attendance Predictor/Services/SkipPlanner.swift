//
//  SkipPlanner.swift
//  Student Attendance Predictor
//
//  Pro: what-if skip for a future timetable day without writing the log.
//

import Foundation

struct SkipPlannerImpact: Identifiable, Equatable {
    let id: UUID
    let name: String
    let classesThatDay: Int
    let currentPercentage: Double
    let afterSkipPercentage: Double
    let requiredPercentage: Double
    let staysSafe: Bool
    let currentlySafe: Bool
    let bunksLeftAfter: Int
}

struct SkipPlannerResult: Equatable {
    let date: Date
    let impacts: [SkipPlannerImpact]

    var scheduledSubjectCount: Int { impacts.count }
    var safeCount: Int { impacts.filter(\.staysSafe).count }
    var unsafeCount: Int { scheduledSubjectCount - safeCount }
    var totalClasses: Int { impacts.reduce(0) { $0 + $1.classesThatDay } }
    var isOverallSafe: Bool { scheduledSubjectCount > 0 && unsafeCount == 0 }

    var riskLevel: SkipDayRisk {
        if scheduledSubjectCount == 0 { return .noClass }
        if isOverallSafe { return .safe }
        if safeCount == 0 { return .unsafe }
        return .mixed
    }
}

enum SkipDayRisk: Equatable {
    case noClass
    case safe
    case mixed
    case unsafe
}

enum SkipPlanner {
    static func evaluate(date: Date, subjects: [SubjectSummary]) -> SkipPlannerResult {
        let impacts = subjects.compactMap { subject -> SkipPlannerImpact? in
            let classes = subject.weeklySchedule.classes(on: date)
            guard classes > 0 else { return nil }
            let newTotal = subject.totalClasses + classes
            let after = CalculationService.currentPercentage(
                attended: subject.attendedClasses,
                total: newTotal
            )
            let staysSafe = after >= subject.requiredPercentage
            let bunksLeft = CalculationService.maxBunk(
                attended: subject.attendedClasses,
                total: newTotal,
                required: subject.requiredPercentage
            )
            return SkipPlannerImpact(
                id: subject.id,
                name: subject.name,
                classesThatDay: classes,
                currentPercentage: subject.currentPercentage,
                afterSkipPercentage: after,
                requiredPercentage: subject.requiredPercentage,
                staysSafe: staysSafe,
                currentlySafe: subject.status == .safe,
                bunksLeftAfter: bunksLeft
            )
        }
        return SkipPlannerResult(date: date, impacts: impacts)
    }

    static func upcomingClassDays(
        subjects: [SubjectSummary],
        from date: Date = Date(),
        count: Int = 7,
        calendar: Calendar = .current
    ) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: date)
        for _ in 0..<21 where days.count < count {
            let result = evaluate(date: cursor, subjects: subjects)
            if result.scheduledSubjectCount > 0 {
                days.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Upcoming class days ranked safest-first for Siri / Shortcuts.
    static func rankedSkipDays(
        subjects: [SubjectSummary],
        from date: Date = Date(),
        limit: Int = 7
    ) -> [SkipPlannerResult] {
        let days = upcomingClassDays(subjects: subjects, from: date, count: limit)
        return days
            .map { evaluate(date: $0, subjects: subjects) }
            .sorted { lhs, rhs in
                let order: (SkipDayRisk) -> Int = { risk in
                    switch risk {
                    case .safe: return 0
                    case .mixed: return 1
                    case .unsafe: return 2
                    case .noClass: return 3
                    }
                }
                let left = order(lhs.riskLevel)
                let right = order(rhs.riskLevel)
                if left != right { return left < right }
                return lhs.date < rhs.date
            }
    }

    static func safestSkipDay(
        subjects: [SubjectSummary],
        from date: Date = Date()
    ) -> SkipPlannerResult? {
        rankedSkipDays(subjects: subjects, from: date).first { $0.riskLevel != .noClass }
    }
}
