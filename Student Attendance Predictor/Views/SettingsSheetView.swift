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
    @State private var selectedMarket: StudentMarket
    @State private var rateErrorMessage: String?
    @State private var adPrivacyErrorMessage: String?
    @State private var showAdPrivacyChoices = false
    @State private var isShowingProPaywall = false
    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @AppStorage("feature.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("feature.wittyNotificationsEnabled") private var wittyNotificationsEnabled = true
    
    private let appStoreID = "6761951427"
    private let proGold = Color(red: 1.0, green: 0.78, blue: 0.28)

    init(viewModel: AttendanceViewModel) {
        self.viewModel = viewModel
        _defaultRequiredPercentage = State(
            initialValue: SettingsSheetView.formattedPercentage(viewModel.defaultRequiredPercentage)
        )
        _selectedMarket = State(initialValue: StudentMarketStore.current)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if entitlements.isPro {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(proGold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bunk Planner Pro")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Text("Skip planner · Forecast · Ads off")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Active")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            AnalyticsService.shared.log(
                                .proCtaTapped(surface: "settings_pro", action: "go_pro")
                            )
                            isShowingProPaywall = true
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.86, blue: 0.42),
                                                    Color(red: 0.95, green: 0.58, blue: 0.18)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.85))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Go Pro")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text("Skip planner · Forecast · PDF + CSV · Ads off")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Pro")
                }

                #if DEBUG
                Section {
                    Button {
                        entitlements.setProUnlocked(!entitlements.isPro)
                    } label: {
                        HStack {
                            Label(
                                entitlements.isPro ? "Disable Pro (Debug)" : "Enable Pro (Debug)",
                                systemImage: entitlements.isPro ? "crown.fill" : "crown"
                            )
                            Spacer()
                            Text(entitlements.isPro ? "ON" : "OFF")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(entitlements.isPro ? .green : .secondary)
                        }
                    }
                    Text("DEBUG builds only. Toggles Pro without StoreKit.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Debug")
                }
                #endif

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

                Section {
                    HStack {
                        Text("Detected")
                        Spacer()
                        Text(StudentMarket.detect().displayName)
                            .foregroundStyle(.secondary)
                    }

                    if StudentMarketStore.usesSystemDetection {
                        Text("Using your iPhone region automatically. Wording (bunk vs skip) and Grades labels adapt — no choice needed.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Manual override is on. Tap “Use device region” to go back to auto.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Picker("Override (optional)", selection: $selectedMarket) {
                        ForEach(StudentMarket.allCases) { market in
                            Text(market.displayName).tag(market)
                        }
                    }
                    .onChange(of: selectedMarket) { _, market in
                        // Only persist when different from live detection, so picking
                        // the same country as the device does not lock an override.
                        if market == StudentMarket.detect() {
                            StudentMarketStore.resetToSystem()
                        } else {
                            StudentMarketStore.current = market
                        }
                        let suggested = market.defaultRequiredAttendance
                        if abs(viewModel.defaultRequiredPercentage - suggested) > 0.5 {
                            defaultRequiredPercentage = SettingsSheetView.formattedPercentage(suggested)
                        }
                    }

                    if StudentMarketStore.usesSystemDetection == false {
                        Button("Use device region") {
                            StudentMarketStore.resetToSystem()
                            selectedMarket = StudentMarketStore.current
                        }
                    }
                } header: {
                    Text("Region")
                }

                Section("Ads") {
                    if entitlements.isPro {
                        Label("All ads removed with Pro", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("Banners and full-screen ads stay off.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Free includes banner and occasional full-screen ads.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        Button {
                            AnalyticsService.shared.log(
                                .proCtaTapped(surface: "settings_ads", action: "go_pro")
                            )
                            isShowingProPaywall = true
                        } label: {
                            Label("Remove ads forever with Pro", systemImage: "crown.fill")
                        }
                    }
                }

                Section("Automation") {
                    Toggle("Risk Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            AnalyticsService.shared.log(.notificationsToggled(enabled: enabled))
                            AnalyticsUserProfile.sync(subjectStore: nil, notificationsEnabled: enabled)
                            if enabled == false {
                                // Clears deadline reminders; attendance reminders are separate.
                                NotificationService.rescheduleDeadlineReminders(deadlines: [])
                            }
                        }
                    Text("Risk notifications are local alerts; no backend is used.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Toggle("Witty reminder copy", isOn: $wittyNotificationsEnabled)
                    Text("Daily reminders stay on. Turn this off for straightforward language.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    if entitlements.isPro {
                        Text("Pro also sends a Sunday weekly digest of attended, missed, and at-risk subjects.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
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
                            .analyticsScreen(.privacyPolicy)
                    }

                    NavigationLink("Terms of Use") {
                        TermsOfUseView()
                            .analyticsScreen(.termsOfUse)
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
                if entitlements.isPro == false {
                    AnalyticsService.shared.logProCtaShownOnce(surface: "settings_pro")
                }
            }
            .sheet(isPresented: $isShowingProPaywall) {
                ProPaywallView(source: "settings")
                    .preferredColorScheme(.dark)
                    .analyticsScreen(.proPaywall)
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
        AnalyticsService.shared.log(.adPrivacyChoicesOpened)
        Task { @MainActor in
            do {
                try await AdMobConsentService.presentPrivacyOptions()
                if await AdMobService.ensureReadyForAds() {
                    AdMobInterstitialService.shared.preload()
                    AdMobAppOpenService.shared.preload()
                }
            } catch {
                adPrivacyErrorMessage = error.localizedDescription
            }
        }
    }

    private func openRateUsFlow() {
        AnalyticsService.shared.log(.rateUsTapped)
        #if canImport(UIKit)
        // Official StoreKit deep link. Prefer https://apps.apple.com (not itunes.apple.com).
        // Do not use canOpenURL(itms-apps:) — without LSApplicationQueriesSchemes it
        // returns false and falsely shows "App Store is not available".
        guard let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") else {
            rateErrorMessage = "Could not create App Store review URL."
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
