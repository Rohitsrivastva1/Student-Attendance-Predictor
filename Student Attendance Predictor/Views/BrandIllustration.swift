//
//  BrandIllustration.swift
//  Student Attendance Predictor
//
//  3D clay art for onboarding and empty states.
//  PNGs are already on black — don’t clip them into a photo card.
//

import SwiftUI

enum BrandIllustration: String {
    case onboardKnow = "OnboardKnow"
    case onboardTap = "OnboardTap"
    case onboardAlert = "OnboardAlert"
    case emptyHome = "EmptyHome"
    case emptyInsights = "EmptyInsights"
    case emptyLog = "EmptyLog"
    case emptySubjects = "EmptySubjects"
    case markToday = "MarkTodayHero"
}

enum BrandType {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

struct BrandHeroImage: View {
    let illustration: BrandIllustration
    var size: CGFloat = 220

    var body: some View {
        Image(illustration.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct BrandEmptyState: View {
    let illustration: BrandIllustration
    var imageSize: CGFloat = 180
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            BrandHeroImage(illustration: illustration, size: imageSize)

            Text(title)
                .font(BrandType.display(26))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message)
                .font(BrandType.body(15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(BrandType.title(16))
                        .foregroundStyle(BrandColor.colorOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BrandColor.colorAccentPrimary)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }
}

struct AttendanceStatusBadge: View {
    let isSafe: Bool
    var compact: Bool = false

    var body: some View {
        Text(isSafe ? "Safe" : "At risk")
            .font(.system(size: compact ? 11 : 13, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
            )
            .accessibilityLabel(isSafe ? "Safe" : "At risk")
    }

    private var tint: Color {
        isSafe ? BrandColor.colorAccentPrimary : BrandColor.colorMissed
    }
}
