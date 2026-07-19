//
//  CelebrationBurst.swift
//  Student Attendance Predictor
//
//  Lightweight confetti + scale celebration for daily wins.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct CelebrationBurst: View {
    var isActive: Bool

    @State private var particles: [ConfettiParticle] = []
    @State private var burstScale: CGFloat = 0.6
    @State private var burstOpacity: Double = 0

    private let palette: [Color] = [
        Color(red: 0.32, green: 0.84, blue: 1.0),
        Color(red: 0.2, green: 0.9, blue: 0.5),
        Color(red: 1.0, green: 0.78, blue: 0.28),
        Color(red: 1.0, green: 0.45, blue: 0.55),
        Color.white
    ]

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Capsule()
                    .fill(particle.color)
                    .frame(width: particle.size.width, height: particle.size.height)
                    .rotationEffect(.degrees(particle.rotation))
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.5))
                .scaleEffect(burstScale)
                .opacity(burstOpacity)
                .shadow(color: Color(red: 0.2, green: 0.9, blue: 0.5).opacity(0.45), radius: 18)
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active {
                trigger()
            }
        }
    }

    private func trigger() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif

        particles = (0..<22).map { index in
            let angle = Double(index) / 22.0 * .pi * 2
            let distance = CGFloat.random(in: 70...140)
            return ConfettiParticle(
                color: palette[index % palette.count],
                size: CGSize(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 10...18)),
                rotation: Double.random(in: 0...360),
                x: 0,
                y: 0,
                opacity: 1,
                targetX: cos(angle) * distance,
                targetY: sin(angle) * distance - CGFloat.random(in: 20...60)
            )
        }

        burstScale = 0.55
        burstOpacity = 1

        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
            burstScale = 1.08
        }
        withAnimation(.easeOut(duration: 0.85)) {
            for index in particles.indices {
                particles[index].x = particles[index].targetX
                particles[index].y = particles[index].targetY
                particles[index].opacity = 0
                particles[index].rotation += Double.random(in: 40...120)
            }
            burstOpacity = 0
            burstScale = 1.2
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGSize
    var rotation: Double
    var x: CGFloat
    var y: CGFloat
    var opacity: Double
    let targetX: CGFloat
    let targetY: CGFloat
}

/// Simple toast that appears after a successful Mark Today save.
struct CelebrationToast: View {
    let message: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}
