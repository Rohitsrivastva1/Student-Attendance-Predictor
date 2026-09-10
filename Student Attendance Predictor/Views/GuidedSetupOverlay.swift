//
//  GuidedSetupOverlay.swift
//  Student Attendance Predictor
//

import SwiftUI

struct GuidedSetupBanner: View {
    let step: GuidedSetupStep
    var onAction: () -> Void

    private let cyan = BrandColor.colorAccentPrimary
    private let green = BrandColor.colorAttend

    var body: some View {
        Button(action: onAction) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent.opacity(0.45), lineWidth: 1.5)
                )
        )
        .accessibilityHint("Opens the next setup step")
    }

    private var accent: Color {
        switch step {
        case .addSubject: return cyan
        case .setClassDays: return BrandColor.colorPremium
        case .markToday: return green
        }
    }

    private var iconName: String {
        switch step {
        case .addSubject: return "books.vertical.fill"
        case .setClassDays: return "calendar"
        case .markToday: return "hand.tap.fill"
        }
    }

    private var title: String {
        switch step {
        case .addSubject: return "1 · Add a subject"
        case .setClassDays: return "2 · Which days is class?"
        case .markToday: return "3 · Attend or Missed?"
        }
    }

    private var subtitle: String {
        switch step {
        case .addSubject:
            return "Name one paper — Maths, DSA, anything. Tap here."
        case .setClassDays:
            return "Tap the days you have this class. Today will hide the rest."
        case .markToday:
            return "Attend if you went. Missed if you skipped. No class if it was off."
        }
    }
}

struct SemesterProgressStrip: View {
    let progress: SemesterSettings.Progress

    private let cyan = BrandColor.colorAccentPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Semester")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("Week \(progress.currentWeek) of \(progress.totalWeeks)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(cyan)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [cyan, BrandColor.colorAttend],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * progress.fractionComplete))
                }
            }
            .frame(height: 8)

            Text("\(progress.weeksRemaining) week\(progress.weeksRemaining == 1 ? "" : "s") left in semester")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .background(BrandColor.cardFill(cornerRadius: 16))
    }
}
