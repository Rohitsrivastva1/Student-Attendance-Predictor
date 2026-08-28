//
//  SkipPlannerView.swift
//  Student Attendance Predictor
//
//  Pro skip-day analysis: calendar sheet + Insights week map.
//

import SwiftUI

struct SkipPlannerSheet: View {
    let result: SkipPlannerResult
    var subjectFilterName: String? = nil

    @Environment(\.dismiss) private var dismiss

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)
    private var skipVerb: String { StudentMarketStore.current.skipVerb }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    if result.impacts.isEmpty {
                        Text("No classes on the timetable this day. Add a weekly schedule to plan \(skipVerb)s.")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    } else {
                        ForEach(result.impacts) { impact in
                            impactRow(impact)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.1).ignoresSafeArea())
            .navigationTitle("Skip planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            AnalyticsService.shared.log(.skipPlannerViewed(dayCount: result.scheduledSubjectCount))
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(cyan)
            Text(heroTitle)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(heroSubtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(heroTint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(heroTint.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var heroTint: Color {
        switch result.riskLevel {
        case .safe: return green
        case .mixed: return Color.orange
        case .unsafe: return Color.red
        case .noClass: return .white
        }
    }

    private var heroTitle: String {
        switch result.riskLevel {
        case .noClass:
            return "Nothing scheduled"
        case .safe:
            return "Safe to \(skipVerb)"
        case .mixed:
            return "Mixed — check subjects"
        case .unsafe:
            return "Don't \(skipVerb)"
        }
    }

    private var heroSubtitle: String {
        if result.impacts.isEmpty { return "Set a timetable first." }
        if let name = subjectFilterName {
            return "If you miss \(result.totalClasses) \(name) class\(result.totalClasses == 1 ? "" : "es") this day."
        }
        return "If you miss all \(result.totalClasses) class\(result.totalClasses == 1 ? "" : "es") across \(result.scheduledSubjectCount) subject\(result.scheduledSubjectCount == 1 ? "" : "s")."
    }

    private func impactRow(_ impact: SkipPlannerImpact) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(impact.staysSafe ? green : Color.red)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(impact.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(impact.classesThatDay) class\(impact.classesThatDay == 1 ? "" : "es") · \(String(format: "%.0f%%", impact.currentPercentage)) → \(String(format: "%.0f%%", impact.afterSkipPercentage))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text(impact.staysSafe
                     ? (impact.bunksLeftAfter > 0
                        ? "Still above \(Int(impact.requiredPercentage.rounded()))% · \(impact.bunksLeftAfter) \(skipVerb) left after"
                        : "Still above \(Int(impact.requiredPercentage.rounded()))% — no buffer left")
                     : "Drops below your \(Int(impact.requiredPercentage.rounded()))% target")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(impact.staysSafe ? green.opacity(0.9) : Color.red.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct SkipPlannerWeekCard: View {
    let subjects: [SubjectSummary]
    let isPro: Bool
    var onUnlock: () -> Void
    var onSelectDay: (Date) -> Void

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)
    private var skipVerb: String { StudentMarketStore.current.skipVerb }
    private var days: [Date] { SkipPlanner.upcomingClassDays(subjects: subjects) }

    private var safeDayCount: Int {
        days.filter { SkipPlanner.evaluate(date: $0, subjects: subjects).riskLevel == .safe }.count
    }

    private var lockedTeaser: String {
        if days.isEmpty {
            return "Add a timetable — then we’ll tell you which days stay safe."
        }
        if safeDayCount == 0 {
            return "We already ran this week. Unlock to see which days you should not \(skipVerb)."
        }
        if safeDayCount == 1 {
            return "1 day this week looks safe. Unlock to see which — before you \(skipVerb) the wrong one."
        }
        return "\(safeDayCount) days this week look safe. Unlock to see which — before you \(skipVerb) the wrong one."
    }

    private var lockedCTA: String {
        safeDayCount > 0 ? "Reveal the safe days" : "Unlock skip planner"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skip planner")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(isPro
                         ? "Tap a day to see if you can \(skipVerb)."
                         : lockedTeaser)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                if isPro == false {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.28))
                }
            }

            if days.isEmpty {
                Text("Add a weekly timetable to plan upcoming \(skipVerb)s.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(days, id: \.timeIntervalSince1970) { day in
                            dayChip(day)
                                .frame(width: 52)
                        }
                    }
                }
            }

            if isPro == false {
                Button(action: onUnlock) {
                    Label(lockedCTA, systemImage: "crown.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(cyan)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func dayChip(_ day: Date) -> some View {
        let result = SkipPlanner.evaluate(date: day, subjects: subjects)
        let tint: Color = {
            switch result.riskLevel {
            case .safe: return green
            case .mixed: return Color.orange
            case .unsafe: return Color.red
            case .noClass: return .white.opacity(0.3)
            }
        }()
        let weekday = day.formatted(.dateTime.weekday(.abbreviated))
        let number = Calendar.current.component(.day, from: day)

        return Button {
            if isPro {
                onSelectDay(day)
            } else {
                onUnlock()
            }
        } label: {
            VStack(spacing: 6) {
                Text(weekday)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(number)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Circle()
                    .fill(isPro ? tint : Color.white.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isPro ? tint.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(weekday) \(number), \(isPro ? result.riskLevel.accessibilityLabel : "locked")")
    }
}

private extension SkipDayRisk {
    var accessibilityLabel: String {
        switch self {
        case .noClass: return "no class"
        case .safe: return "safe to skip"
        case .mixed: return "mixed"
        case .unsafe: return "not safe"
        }
    }
}
