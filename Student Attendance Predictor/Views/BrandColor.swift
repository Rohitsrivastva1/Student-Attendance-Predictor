//
//  BrandColor.swift
//  Student Attendance Predictor
//
//  Rich dark-mode palette: vivid mint accent, juicy functional colors,
//  still no neon glow. Tuned to pop on charcoal without looking dusty.
//

import SwiftUI

enum BrandColor {
    /// App canvas — `#0A0E16`
    static let colorBackground = Color(hex: 0x0A0E16)
    /// Card surface — `#1C2433` (solid so cards lift off the canvas)
    static let colorSurface = Color(hex: 0x1C2433)
    /// Hairline on cards
    static let colorBorder = Color.white.opacity(0.12)
    /// Hero stat, tabs, progress — `#3AEDC0`
    static let colorAccentPrimary = Color(hex: 0x3AEDC0)
    /// Attend — cool periwinkle, not green — `#5B8CFF`
    static let colorAttend = Color(hex: 0x5B8CFF)
    /// Missed — dark red — `#E11D48`
    static let colorMissed = Color(hex: 0xE11D48)
    /// No class / neutral — `#8FA3C4`
    static let colorNoClass = Color(hex: 0x8FA3C4)
    /// Gated Pro surfaces (skip planner lock) — `#8B7CFF`
    static let colorPro = Color(hex: 0x8B7CFF)
    /// Premium gold — `#FFD166`
    static let colorPremium = Color(hex: 0xFFD166)
    /// Premium gradient end — `#F0B429`
    static let colorPremiumDeep = Color(hex: 0xF0B429)
    /// Streak pill — `#FFB86B`
    static let colorStreakBadge = Color(hex: 0xFFB86B)
    /// Text on bright Attend / No class fills
    static let colorOnAccent = Color(hex: 0x0A1018)
    /// Neutral elevation — no colored glow
    static let colorElevation = Color.black.opacity(0.32)

    static var premiumGradient: LinearGradient {
        LinearGradient(
            colors: [colorPremium, colorPremiumDeep],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func cardFill(cornerRadius: CGFloat = 24) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(colorSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorBorder, lineWidth: 1)
            )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
