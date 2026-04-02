//
//  SettingsSheetView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct SettingsSheetView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var defaultRequiredPercentage: String

    init(viewModel: AttendanceViewModel) {
        self.viewModel = viewModel
        _defaultRequiredPercentage = State(
            initialValue: SettingsSheetView.formattedPercentage(viewModel.defaultRequiredPercentage)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Defaults") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Required Attendance (%)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        TextField("75", text: $defaultRequiredPercentage)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: defaultRequiredPercentage) { _, newValue in
                                defaultRequiredPercentage = sanitizePercentage(newValue)
                            }

                        Text("Used when the app opens fresh or after reset.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Button("Save Default") {
                        saveDefault()
                    }

                    Button("Reset Inputs", role: .destructive) {
                        viewModel.resetInputs()
                        dismiss()
                    }
                }

                Section("Privacy") {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }

                    Text("Publish this same policy on a public URL and use that link in your App Store listing.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveDefault() {
        guard let value = Double(defaultRequiredPercentage), (0...100).contains(value) else {
            return
        }

        viewModel.updateDefaultRequiredPercentage(value)
        defaultRequiredPercentage = SettingsSheetView.formattedPercentage(value)
        dismiss()
    }

    private func sanitizePercentage(_ value: String) -> String {
        var result = ""
        var hasDecimalSeparator = false

        for character in value {
            if character.isNumber {
                result.append(character)
                continue
            }

            if character == ".", !hasDecimalSeparator {
                hasDecimalSeparator = true
                result.append(character)
            }
        }

        return result
    }

    private static func formattedPercentage(_ value: Double) -> String {
        let roundedValue = (value * 10).rounded() / 10
        return roundedValue.rounded(.towardZero) == roundedValue
            ? String(Int(roundedValue))
            : String(format: "%.1f", roundedValue)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                policySection(
                    title: "Overview",
                    body: "Student Attendance Predictor stores your latest attendance inputs and default attendance target on your device so the app can restore them later."
                )
                policySection(
                    title: "Data Collection",
                    body: "The current build does not require account creation and does not send attendance data to a backend server."
                )
                policySection(
                    title: "Advertising",
                    body: "If AdMob is enabled in a release build, ad providers may use device-level advertising identifiers according to their own policies."
                )
                policySection(
                    title: "Contact",
                    body: "Add your support email or website before release, then publish this policy on a public webpage for App Store submission."
                )
            }
            .padding(20)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text(body)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsSheetView(viewModel: AttendanceViewModel())
}
