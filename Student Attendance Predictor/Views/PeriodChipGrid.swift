//
//  PeriodChipGrid.swift
//  Student Attendance Predictor
//
//  One-tap hour chips. Selected = this subject has class then.
//

import SwiftUI

struct PeriodChipGrid: View {
    let selectedHours: Set<Int>
    var onToggle: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            chipRow(Array(CollegePeriod.grid.prefix(5)))
            chipRow(Array(CollegePeriod.grid.dropFirst(5)))
        }
    }

    private func chipRow(_ periods: [CollegePeriod]) -> some View {
        HStack(spacing: 6) {
            ForEach(periods) { period in
                let isOn = selectedHours.contains(period.startHour)
                Button {
                    onToggle(period.startHour)
                } label: {
                    Text(period.chipLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isOn ? Color(red: 0.05, green: 0.06, blue: 0.1) : Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isOn ? Color(red: 0.32, green: 0.84, blue: 1.0) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    isOn ? Color.clear : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(period.rangeLabel)\(isOn ? ", class" : ", free")")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
