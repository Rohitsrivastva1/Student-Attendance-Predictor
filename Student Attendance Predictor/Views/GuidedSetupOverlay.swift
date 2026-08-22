//
//  GuidedSetupOverlay.swift
//  Student Attendance Predictor
//

import SwiftUI

struct GuidedSetupBanner: View {
    let step: GuidedSetupStep
    var onDismiss: () -> Void

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step == .addSubject ? "books.vertical.fill" : "hand.tap.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(step == .addSubject ? cyan : green)
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

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .accessibilityLabel("Dismiss guide")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke((step == .addSubject ? cyan : green).opacity(0.45), lineWidth: 1.5)
                )
        )
    }

    private var title: String {
        switch step {
        case .addSubject: return "Step 1 · Add a subject"
        case .markToday: return "Step 2 · Mark today"
        }
    }

    private var subtitle: String {
        switch step {
        case .addSubject:
            return "Tap the book icon above to add your first \(StudentMarketStore.current.courseNoun)."
        case .markToday:
            return "Log today’s class with one tap — that’s how Bunk Planner learns your habit."
        }
    }
}

struct SemesterProgressStrip: View {
    let progress: SemesterSettings.Progress

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)

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
                                colors: [cyan, Color(red: 0.2, green: 0.9, blue: 0.5)],
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
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
