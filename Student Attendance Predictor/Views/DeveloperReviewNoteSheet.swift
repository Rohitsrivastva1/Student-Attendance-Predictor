//
//  DeveloperReviewNoteSheet.swift
//  Student Attendance Predictor
//
//  A quiet note from the person building the app — not a generic rate dialog.
//

import SwiftUI

struct DeveloperReviewNoteSheet: View {
    var onReview: () -> Void
    var onLater: () -> Void

    private var greeting: String {
        let first = NotificationPersonalization.firstName()
        if first.isEmpty {
            return "Hey,"
        }
        return "Hey \(first),"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            mainStack
        }
        .background(BrandColor.colorSurface.ignoresSafeArea())
    }

    private var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 18)

            Text("A note from the developer")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(BrandColor.colorAccentPrimary.opacity(0.9))
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 12) {
                Text(greeting)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Text("We're constantly improving Bunk Planner — clearer numbers, faster marking, a calmer way to stay on top of attendance.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                Text("If it's helped you, a quick App Store rating (15 seconds!) would mean a lot — it helps other students find us and tells us what to keep building.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                Text("Thanks for being here.\n— Rohit")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                    .padding(.top, 2)
            }
            .padding(.bottom, 22)

            Button(action: onReview) {
                Text("Leave a kind review")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(BrandColor.colorOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(BrandColor.colorAccentPrimary)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)

            Button(action: onLater) {
                Text("Maybe later")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
