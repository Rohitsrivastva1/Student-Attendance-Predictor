//
//  PostMarkFocusSheet.swift
//  Student Attendance Predictor
//
//  After Mark Today: a bottom sheet, not a system popover.
//

import SwiftUI

struct PostMarkFocusSheet: View {
    let subjectName: String?
    var onStart: (Int) -> Void
    var onDismiss: () -> Void

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let panel = Color(red: 0.09, green: 0.10, blue: 0.14)

    private var title: String {
        if let subjectName, subjectName.isEmpty == false {
            return "Focus on \(subjectName)?"
        }
        return "Start a focus session?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Timer stays in the app and tags this subject.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Button {
                onStart(25)
            } label: {
                Text("Start 25 min")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.06, blue: 0.1))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cyan)
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    onStart(15)
                } label: {
                    Text("15 min")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Not now")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panel.ignoresSafeArea())
    }
}
