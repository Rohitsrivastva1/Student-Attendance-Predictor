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
                    body: "Bunk Planner helps you plan attendance and bunk safely. Your data is stored on this device. Some of it may also sync to Schoolabe so we can run and improve the app. We do not sell your data."
                )

                section(
                    title: "Cloud sync",
                    body: "We may sync the profile you enter, plus your subjects and attendance, to Schoolabe. This is linked to a random identifier on this device — not your Apple ID, email, or phone number. Some things stay only on this device, like CGPA, Focus Timer notes, and your syllabus checklist. If you use Make better with AI on a syllabus, only the text you confirmed is sent to Schoolabe (not the photo)."
                )

                section(
                    title: "Remove your data",
                    body: "Use Settings → About you → Remove my data to clear your profile on this phone and ask Schoolabe to stop using your synced copy. Attendance on this device stays unless you delete it in the app. For any other request, email info@schoolabe.com."
                )

                section(
                    title: "On this device",
                    body: "Subjects, attendance, settings, and reminders stay on your iPhone or iPad. If you back up with Apple, that backup follows Apple’s privacy policy. Files you export (PDF or CSV) leave the device only if you share them."
                )

                section(
                    title: "Advertising",
                    body: "Bunk Planner is free and supported by ads from Google AdMob. Ads may appear as labeled “Ad” cards in the app, as short full-screen videos after you mark attendance, or when you open or return to the app. Google may collect device and ad interaction data to deliver and measure ads. We do not sell your attendance data to advertisers."
                )

                section(
                    title: "Analytics",
                    body: "We collect anonymous usage data to understand how the app is used and to improve it. This may include general app activity and session information. It is processed by Google Firebase Analytics and by Schoolabe, and is tied to a random identifier on this device — not your Apple ID, email, or phone number. Advertising measurement stays with Google. We do not sell this data."
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
                    title: "Invites",
                    body: "If you share or redeem an invite, we store your anonymous app id and the invite code on Schoolabe so we can credit both of you with a short ad-free period. We do not collect your name, email, or phone number for invites. You can still use the app without inviting anyone."
                )

                section(
                    title: "Syllabus",
                    body: "You can photograph or type a syllabus. Text is read on this device first. If you tap Make better with AI, only the text you confirmed is sent to Schoolabe so we can structure units and topics with Groq. Syllabus photos stay on your phone. Your checklist and progress stay on this device."
                )

                section(
                    title: "Homework and exams",
                    body: "You can photograph a diary, notice, or datesheet. Text is read on this device first. If we use AI to turn that text into a task list, only the text is sent to Schoolabe. Photos stay on your phone. The task list, reminders, and Focus Timer picks stay on this device."
                )

                section(
                    title: "Notifications",
                    body: "Optional local reminders stay on this device. They are not sent to Schoolabe. You can turn them off in Settings."
                )

                section(
                    title: "What We Do Not Collect",
                    body: "We do not sell your data. We do not collect your Apple ID, email, or phone number. We do not require tracking permission to use the app."
                )

                section(
                    title: "Contact",
                    body: "For support or privacy questions, contact info@schoolabe.com."
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BrandColor.colorBackground.ignoresSafeArea())
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
