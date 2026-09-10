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
    var isPro: Bool = true
    var onSelectSubject: (UUID) -> Void
    var onEmptyAction: (() -> Void)? = nil
    var onLockedRecover: (() -> Void)? = nil

    private let cyan = BrandColor.colorAccentPrimary
    private let green = BrandColor.colorAttend
    private let danger = BrandColor.colorMissed

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

            if advice.kind == .empty {
                BrandHeroImage(illustration: .emptyInsights, size: 140)
                    .frame(maxWidth: .infinity)
            }
            Text(advice.title)
                .font(BrandType.display(24))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(advice.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            if advice.kind == .empty, let onEmptyAction {
                Button(action: onEmptyAction) {
                    Text("Add a subject")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(cyan)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }

            let rankedRows = InsightsCoach.rankedSubjects(subjects)
            if rankedRows.isEmpty == false {
                VStack(spacing: 8) {
                    ForEach(rankedRows) { subject in
                        subjectRow(subject)
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
        .onAppear {
            if isPro == false, subjects.contains(where: \.isAtRisk) {
                AnalyticsService.shared.logProCtaShownOnce(surface: "plan_recover")
            }
        }
    }

    private func subjectRow(_ subject: SubjectSummary) -> some View {
        let isRisk = subject.isAtRisk
        return HStack(spacing: 10) {
            Button {
                onSelectSubject(subject.id)
            } label: {
                HStack(spacing: 10) {
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
                        .foregroundStyle(isRisk ? danger : green)
                }
            }
            .buttonStyle(.plain)

            if isRisk {
                recoverChip(for: subject)
            } else {
                Text(subject.actionChipLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isRisk ? danger.opacity(0.16) : Color.white.opacity(0.04))
        )
    }

    private func recoverChip(for subject: SubjectSummary) -> some View {
        Button {
            if isPro {
                onSelectSubject(subject.id)
            } else {
                onLockedRecover?()
            }
        } label: {
            HStack(spacing: 4) {
                if isPro == false {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text("Recover")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(danger.opacity(0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPro ? "Recover \(subject.name)" : "Recover \(subject.name), Pro")
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
                            .foregroundStyle(BrandColor.colorPremium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share \(streak)-day streak")
                }
            }

            HStack(spacing: 10) {
                pulseStat(title: "Attended", value: "\(attended)")
                pulseStat(title: skipNounPlural, value: "\(missed)")
                pulseStat(
                    title: "Streak",
                    value: streak == 0 ? "0 days" : "\(streak)d",
                    muted: streak == 0
                )
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

    private func pulseStat(title: String, value: String, muted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(muted ? .white.opacity(0.38) : .white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
