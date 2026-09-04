//
//  InsightsCoach.swift
//  Student Attendance Predictor
//
//  One next action for Insights — recover, protect buffer, or skip safely.
//

import Foundation

struct InsightsAdvice: Equatable {
    enum Kind: Equatable {
        case empty
        case recover
        case protect
        case skipSoon
        case onTrack
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let subjectID: UUID?
}

enum InsightsCoach {
    static func advice(
        subjects: [SubjectSummary],
        skipVerb: String,
        skipNounPlural: String,
        isPro: Bool
    ) -> InsightsAdvice {
        let active = subjects.filter { $0.totalClasses > 0 }
        guard active.isEmpty == false else {
            return InsightsAdvice(
                kind: .empty,
                title: "Mark a few classes",
                subtitle: "Insights tells you what to attend or \(skipVerb) once there’s a real log.",
                subjectID: nil
            )
        }

        let atRisk = active
            .filter { $0.status == .risk }
            .sorted { lhs, rhs in
                (lhs.currentPercentage - lhs.requiredPercentage) < (rhs.currentPercentage - rhs.requiredPercentage)
            }

        if let worst = atRisk.first {
            let need = max(1, worst.recoveryNeeded)
            return InsightsAdvice(
                kind: .recover,
                title: "Attend \(need) more in \(worst.name)",
                subtitle: "\(Int(worst.currentPercentage.rounded()))% now · need \(Int(worst.requiredPercentage.rounded()))%. Don’t \(skipVerb) this one until you’re back.",
                subjectID: worst.id
            )
        }

        let tightest = active.min { lhs, rhs in
            lhs.bunkAllowed < rhs.bunkAllowed
        }
        if let tightest, tightest.bunkAllowed == 0 {
            return InsightsAdvice(
                kind: .protect,
                title: "\(tightest.name) has no \(skipVerb) buffer",
                subtitle: "You’re at \(Int(tightest.currentPercentage.rounded()))% — exactly on target. One miss drops you.",
                subjectID: tightest.id
            )
        }

        if let safest = SkipPlanner.rankedSkipDays(subjects: subjects, limit: 7).first,
           safest.riskLevel == .safe {
            if isPro {
                let day = safest.date.formatted(.dateTime.weekday(.wide))
                return InsightsAdvice(
                    kind: .skipSoon,
                    title: "\(day) is the safest \(skipVerb)",
                    subtitle: "All \(safest.scheduledSubjectCount) subjects stay above target if you miss that day. Tap it in Skip planner.",
                    subjectID: nil
                )
            }
            return InsightsAdvice(
                kind: .skipSoon,
                title: "You have a safe \(skipVerb) this week",
                subtitle: "Skip planner below ranks the days. Unlock to see which one won’t drop you.",
                subjectID: nil
            )
        }

        let bunks = active.map(\.bunkAllowed).max() ?? 0
        return InsightsAdvice(
            kind: .onTrack,
            title: "You’re in the safe zone",
            subtitle: bunks > 0
                ? "Up to \(bunks) \(skipNounPlural) left on your strongest subject. Use Skip planner before you pick a day."
                : "Stay consistent. Check Skip planner before you miss a day.",
            subjectID: nil
        )
    }

    static func rankedSubjects(_ subjects: [SubjectSummary]) -> [SubjectSummary] {
        subjects
            .filter { $0.totalClasses > 0 }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .risk && rhs.status != .risk
                }
                return lhs.currentPercentage < rhs.currentPercentage
            }
    }
}
