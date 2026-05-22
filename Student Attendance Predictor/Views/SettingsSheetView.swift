//
//  SettingsSheetView.swift
//  Student Attendance Predictor
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsSheetView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var defaultRequiredPercentage: String
    @State private var rateErrorMessage: String?
    @State private var adPrivacyErrorMessage: String?
    @State private var showAdPrivacyChoices = false
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
                    Text("Risk notifications are local alerts; no backend is used.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Section("Privacy & Support") {
                    if showAdPrivacyChoices {
                        Button("Ad Privacy Choices") {
                            openAdPrivacyChoices()
                        }

                        Text("Manage whether ads can be personalized based on your activity.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }

                    NavigationLink("Terms of Use") {
                        TermsOfUseView()
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
            .onAppear {
                showAdPrivacyChoices = AdMobConsentService.isPrivacyOptionsRequired
            }
            .alert("Ad Privacy", isPresented: Binding(
                get: { adPrivacyErrorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        adPrivacyErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(adPrivacyErrorMessage ?? "")
            }
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
    
    private func openAdPrivacyChoices() {
        Task { @MainActor in
            do {
                try await AdMobConsentService.presentPrivacyOptions()
            } catch {
                adPrivacyErrorMessage = error.localizedDescription
            }
        }
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

#Preview {
    SettingsSheetView(viewModel: AttendanceViewModel())
}
