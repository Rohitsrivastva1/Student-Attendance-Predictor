//
//  PrivacyPolicyView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(
                    title: "Overview",
                    body: "Bunk Planner stores your subject and attendance information locally on your device. No attendance data is sent to SchoolAbe servers."
                )

                section(
                    title: "Local Data Storage",
                    body: "The app uses Core Data and local device storage to save your subjects, attendance stats, and app settings."
                )

                section(
                    title: "Purchases & Subscriptions",
                    body: """
                    Bunk Planner Pro is available as a monthly subscription, annual subscription, or lifetime purchase processed securely by Apple via the App Store. We do not collect, store, or have access to your payment information. All billing is handled entirely by Apple.

                    Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can manage or cancel your subscription anytime in your Apple ID settings.

                    We do not share any purchase or subscription data with third parties.
                    """
                )

                section(
                    title: "Analytics",
                    body: "Bunk Planner does not use third-party analytics SDKs to track your activity."
                )

                section(
                    title: "Contact",
                    body: "For support or privacy questions, contact info@schoolabe.com."
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.1).ignoresSafeArea())
        .navigationTitle("Privacy Policy")
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
