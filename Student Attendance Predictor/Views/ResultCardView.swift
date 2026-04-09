//
//  ResultCardView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct ResultCardView: View {
    let title: String
    let value: String
    let subtitle: String?
    let tint: Color
    let alignment: HorizontalAlignment
    let isEmphasized: Bool

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        tint: Color,
        alignment: HorizontalAlignment = .leading,
        isEmphasized: Bool = false
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.tint = tint
        self.alignment = alignment
        self.isEmphasized = isEmphasized
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(value)
                .font(.system(size: isEmphasized ? 26 : 22, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.6), radius: 8, x: 0, y: 0)

            Text(title)
                .font(.system(size: isEmphasized ? 15 : 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.9))

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .padding(.vertical, isEmphasized ? 18 : 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        )
    }
}

#Preview {
    ResultCardView(
        title: "Allowed Skips",
        value: "0",
        subtitle: "Classes you can miss",
        tint: .black,
        alignment: .center
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
