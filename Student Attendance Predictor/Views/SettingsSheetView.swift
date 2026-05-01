//
//  SettingsSheetView.swift
//  Student Attendance Predictor
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct SettingsSheetView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var defaultRequiredPercentage: String
    @State private var rateErrorMessage: String?
    @AppStorage("feature.notificationsEnabled") private var notificationsEnabled = true
    
    private let appStoreID = "6761951427"

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

                Section("Automation") {
                    Toggle("Risk Notifications", isOn: $notificationsEnabled)
                    // v0.2 (hidden for this release): Upgrade to Pro control
                    // Toggle("Pro Gating Enabled", isOn: $proGatingEnabled)
                    Text("Risk notifications are local alerts; no backend is used.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Section("Privacy & Support") {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Support")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("info@schoolabe.com")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
                Section("Feedback") {
                    Button("Rate Us on App Store") {
                        openRateUsFlow()
                    }
                    
                    Text("This opens the App Store review page where ratings submit reliably.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Unable to Open App Store", isPresented: Binding(
                get: { rateErrorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        rateErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(rateErrorMessage ?? "")
            }
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
    
    private func openRateUsFlow() {
        #if canImport(UIKit)
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review") else {
            rateErrorMessage = "Could not create App Store review URL."
            return
        }
        
        guard UIApplication.shared.canOpenURL(url) else {
            rateErrorMessage = "App Store is not available on this device."
            return
        }
        
        UIApplication.shared.open(url)
        #else
        rateErrorMessage = "App Store review is available on iOS only."
        #endif
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
                    body: "Bunk Planner: Attendance Track stores your latest attendance inputs and your default attendance target locally on your device using Apple UserDefaults so the app can restore them the next time you open it."
                )
                policySection(
                    title: "Data Handling",
                    body: "The app does not require an account. Your attendance numbers, subject names, and related preferences you enter are stored on your device (for example in Apple UserDefaults) so the app can work offline and restore your session. The developer does not operate a login backend for this app and does not receive those inputs on our own servers."
                )
                policySection(
                    title: "Notifications",
                    body: "If you turn on local “risk” reminders, those alerts are scheduled on your device. They are not sent to our servers."
                )
                policySection(
                    title: "Support and Privacy Contact",
                    body: "For support questions or privacy requests, contact info@schoolabe.com."
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
