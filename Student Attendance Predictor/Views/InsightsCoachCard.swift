//
//  InsightsCoachCard.swift
//  Student Attendance Predictor
//
//  Insights hero: what to do next, then each subject’s one-line action.
//

import SwiftUI

struct InsightsCoachCard: View {
    let advice: InsightsAdvice
    let subjects: [SubjectSummary]
    var onSelectSubject: (UUID) -> Void

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)
    private let danger = Color(red: 1.0, green: 0.45, blue: 0.4)

    private var accent: Color {
        switch advice.kind {
        case .recover, .protect: return danger
        case .skipSoon, .onTrack: return green
        case .empty: return cyan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHAT TO DO")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.1)

            Text(advice.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(advice.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            let rows = InsightsCoach.rankedSubjects(subjects)
            if rows.isEmpty == false {
                VStack(spacing: 8) {
                    ForEach(rows) { subject in
                        Button {
                            onSelectSubject(subject.id)
                        } label: {
                            subjectRow(subject)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func subjectRow(_ subject: SubjectSummary) -> some View {
        let isRisk = subject.status == .risk
        return HStack(spacing: 10) {
            Circle()
                .fill(isRisk ? danger : green)
                .frame(width: 8, height: 8)
            Text(subject.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(Int(subject.currentPercentage.rounded()))%")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(isRisk ? danger : .white.opacity(0.85))
            Text(subject.actionChipLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isRisk ? danger : green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isRisk ? danger.opacity(0.10) : Color.white.opacity(0.04))
        )
    }
}

struct InsightsWeekPulseCard: View {
    let attended: Int
    let missed: Int
    let streak: Int
    let skipNounPlural: String
    var onShareStreak: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if streak > 0 {
                    Button(action: onShareStreak) {
                        Label("\(streak)d", systemImage: "flame.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.28))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share \(streak)-day streak")
                }
            }

            HStack(spacing: 10) {
                pulseStat(title: "Attended", value: "\(attended)")
                pulseStat(title: skipNounPlural, value: "\(missed)")
                pulseStat(title: "Streak", value: streak == 0 ? "—" : "\(streak)d")
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

    private func pulseStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
