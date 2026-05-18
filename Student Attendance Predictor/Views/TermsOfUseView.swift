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
                    title: "Subscriptions",
                    body: "Paid plans are billed through your Apple ID account and renew automatically unless canceled before the end of the current billing period."
                )

                section(
                    title: "Cancellation",
                    body: "You can manage or cancel subscriptions anytime in your App Store account settings on iPhone."
                )

                section(
                    title: "Free Tier",
                    body: "The free plan includes up to 2 subjects, attendance calculator, scenario simulator, risk alerts, and local notifications."
                )

                section(
                    title: "Pro Tier",
                    body: "Pro unlocks unlimited subjects, attendance trend graphs, subject-wise forecasts, weekly timetable editor, and the faculty/admin dashboard."
                )

                section(
                    title: "Contact",
                    body: "For billing or terms questions, contact info@schoolabe.com."
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
