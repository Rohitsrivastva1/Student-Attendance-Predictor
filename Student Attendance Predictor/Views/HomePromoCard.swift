//
//  HomePromoCard.swift
//  Student Attendance Predictor
//
//  Weekly rotating promo on Home — surfaces Tools features without a new tab.
//

import SwiftUI

struct HomePromoCard: View {
    let promo: HomePromoKind
    let market: StudentMarket
    var onAction: () -> Void

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)

    var body: some View {
        Button(action: onAction) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: promo.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(cyan)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cyan.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(promo.title(market: market))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text(promo.subtitle(market: market))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(cyan.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(promo.title(market: market))
        .accessibilityHint(promo.subtitle(market: market))
    }
}
