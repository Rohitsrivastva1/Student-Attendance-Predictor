//
//  TermsOfUseView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(
                    title: "App Use",
                    body: "Bunk Planner helps you track attendance, run what-if scenarios, view trends and forecasts, manage subjects, and set weekly timetables. All data stays on your device unless you choose to share it."
                )

                section(
                    title: "Features",
                    body: "Free includes up to \(ProPurchaseConfiguration.freeSubjectLimit) subjects, attendance calculator, scenario simulator, trend graphs, timetable editor, risk alerts, and local notifications. Bunk Planner Pro unlocks unlimited subjects, ad-free use, subject forecasts, skip planner, custom Focus Timer, weekly digest, and PDF + CSV export."
                )

                section(
                    title: "Contact",
                    body: "For support or terms questions, contact info@schoolabe.com."
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.1).ignoresSafeArea())
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(body)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
