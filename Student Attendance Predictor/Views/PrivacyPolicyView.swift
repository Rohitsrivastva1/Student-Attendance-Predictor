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
                    body: "Bunk Planner helps you plan attendance and bunk safely. Attendance is stored on your device and may also sync to Schoolabe so we can improve the product, as described below. During setup we ask for your name, class, and school or college."
                )

                section(
                    title: "Profile & attendance sync",
                    body: "When you use Bunk Planner, we may send to Schoolabe (info@schoolabe.com): your name, optional age, class or degree, school or college; the subjects you create; your full attendance log (date, scheduled/attended class counts, holiday flag per subject-day); whether you opened the app on a given day (last active date); and whether you have Bunk Planner Pro. We do not sell this data. CGPA details are not uploaded through this sync."
                )

                section(
                    title: "Remove your data",
                    body: "Settings → About you → Remove my data clears your profile on this device and sets a removal flag on Schoolabe for tracking. Your local attendance history on this phone is not deleted by that action."
                )

                section(
                    title: "Local Data Storage",
                    body: "The app uses Core Data, UserDefaults, and on-device storage for subjects, attendance history, trends, default settings, and notification preferences. This data stays on your iPhone or iPad unless you back up the device through Apple. If you export a PDF or CSV, that file is created on your device and only leaves it if you choose to share it."
                )

                section(
                    title: "Advertising",
                    body: "Bunk Planner is free and supported by ads from Google AdMob. Ads may appear as labeled “Ad” cards in the app, as short full-screen videos after you mark attendance, or when you open or return to the app. Google may collect device and ad interaction data to deliver and measure ads. We do not sell your attendance data to advertisers."
                )

                section(
                    title: "Analytics",
                    body: "To understand how the app is used and to improve it, Bunk Planner uses Google Firebase Analytics. It collects anonymous, aggregated usage data such as which screens you open, which features you use (for example marking a day), session length, app version, device model, and OS version. This data is tied only to a random, app-generated identifier — not your name, email, or Apple ID — and is not used to read your subject names or attendance numbers. Analytics helps us see which features matter and where the app can be better."
                )

                section(
                    title: "App Tracking Transparency",
                    body: "On supported iOS versions, Apple may ask whether Bunk Planner can track you across other companies’ apps and websites for advertising. If you allow tracking, ads may be more personalized. If you decline, the app works the same and ads are less personalized (contextual ads). You can change this anytime in Settings → Privacy & Security → Tracking."
                )

                section(
                    title: "Ad Privacy & Consent",
                    body: "Where required by law (for example in the EEA/UK), Google’s consent tools may ask about personalized ads and cookies before ads load. You can review or change ad privacy choices later in Bunk Planner Settings when “Ad Privacy Choices” is shown, or through your device privacy settings."
                )

                section(
                    title: "Notifications",
                    body: "Optional local reminders (attendance alerts, daily mark reminders, and for Pro a Sunday weekly digest) are scheduled on your device only. They do not upload your data to SchoolAbe or third-party servers. You can switch witty copy off in Settings."
                )

                section(
                    title: "What We Do Not Collect",
                    body: "We do not upload your subject names or attendance records to our servers, and we do not sell your data. Analytics is anonymous and aggregated (see “Analytics”). We do not require tracking permission to use attendance planning, subject management, or core app features."
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
