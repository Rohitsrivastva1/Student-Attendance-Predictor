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
                .font(.system(size: isEmphasized ? 24 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: isEmphasized ? 15 : 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .padding(.vertical, isEmphasized ? 18 : 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
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
