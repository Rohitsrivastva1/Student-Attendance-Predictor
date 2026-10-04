//
//  PostMarkFocusSheet.swift
//  Student Attendance Predictor
//
//  After Mark Today: homework camera first, then optional Focus.
//

import SwiftUI

struct PostMarkFocusSheet: View {
    let subjectName: String?
    var onCaptureHomework: () -> Void
    var onStart: (Int) -> Void
    var onDismiss: () -> Void

    private let cyan = BrandColor.colorAccentPrimary
    private let panel = BrandColor.colorSurface

    private var homeworkLine: String {
        if let subjectName, subjectName.isEmpty == false {
            return "Any homework from \(subjectName) today?"
        }
        return "Any homework from today?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(homeworkLine)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Photograph the diary or notice. It goes on your task list and into Focus Timer.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Button(action: onCaptureHomework) {
                Label("Take a photo", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(BrandColor.colorOnAccent)
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
                    onStart(25)
                } label: {
                    Text(subjectName.map { "Focus 25 on \($0)" } ?? "Start 25 min")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
