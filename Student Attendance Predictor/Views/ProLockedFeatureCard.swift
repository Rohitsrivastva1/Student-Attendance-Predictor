//
//  ProLockedFeatureCard.swift
//  Student Attendance Predictor
//

import SwiftUI

struct ProLockedFeatureCard<Content: View>: View {
    let isUnlocked: Bool
    let description: String
    let onUpgrade: () -> Void
    @ViewBuilder private let content: () -> Content

    init(
        isUnlocked: Bool,
        description: String,
        onUpgrade: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isUnlocked = isUnlocked
        self.description = description
        self.onUpgrade = onUpgrade
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
                .blur(radius: isUnlocked ? 0 : 10)
                .opacity(isUnlocked ? 1 : 0.4)
                .allowsHitTesting(isUnlocked)
                .accessibilityHidden(!isUnlocked)

            if isUnlocked == false {
                lockedOverlay
            }
        }
    }

    private var lockedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(red: 0.45, green: 0.92, blue: 0.7))

            Text("Pro Feature")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(description)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            Button(action: onUpgrade) {
                Text("Upgrade to Pro")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(ProLockPressableButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
        .padding(8)
    }
}

private struct ProLockPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
