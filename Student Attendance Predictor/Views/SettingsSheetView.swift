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
    @ObservedObject var subjectStore: SubjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var defaultRequiredPercentage: String
    @State private var rateErrorMessage: String?
    @State private var subscriptionErrorMessage: String?
    @State private var showPaywall = false
    @AppStorage("feature.notificationsEnabled") private var notificationsEnabled = true
    
    private let appStoreID = "6761951427"
    private let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    init(viewModel: AttendanceViewModel, subjectStore: SubjectStore) {
        self.viewModel = viewModel
        self.subjectStore = subjectStore
        _defaultRequiredPercentage = State(
            initialValue: SettingsSheetView.formattedPercentage(viewModel.defaultRequiredPercentage)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Bunk Planner Pro") {
                    Text(subjectStore.subjectLimitDescription)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if subjectStore.isProUnlocked == false {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "sparkles")
                        }

                        Text("Pro includes unlimited subjects, trend graphs, forecasts, timetable editor, and faculty dashboard.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Button("Manage Subscription") {
                        openManageSubscriptions()
                    }
                }

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
            .alert("Unable to Open Subscriptions", isPresented: Binding(
                get: { subscriptionErrorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        subscriptionErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(subscriptionErrorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
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

    private func openManageSubscriptions() {
        #if canImport(UIKit)
        guard UIApplication.shared.canOpenURL(manageSubscriptionsURL) else {
            subscriptionErrorMessage = "Subscription settings are not available on this device."
            return
        }

        UIApplication.shared.open(manageSubscriptionsURL)
        #else
        subscriptionErrorMessage = "Subscription management is available on iOS only."
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
    SettingsSheetView(
        viewModel: AttendanceViewModel(),
        subjectStore: SubjectStore()
    )
    .environmentObject(StoreKitManager.shared)
}
