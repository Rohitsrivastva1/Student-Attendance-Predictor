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
    @ObservedObject var subjectStore: SubjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var defaultRequiredPercentage: String
    @State private var selectedMarket: StudentMarket
    @State private var rateErrorMessage: String?
    @State private var adPrivacyErrorMessage: String?
    @State private var showAdPrivacyChoices = false
    @State private var isShowingProPaywall = false
    @State private var isShowingProfileEditor = false
    #if DEBUG
    @State private var isShowingDebugTools = false
    #endif
    @State private var showRemoveUserDataConfirmation = false
    @State private var isRemovingUserData = false
    @State private var removeUserDataErrorMessage: String?
    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @ObservedObject private var referral = ReferralService.shared
    @ObservedObject private var profileStore = StudentProfileStore.shared
    @AppStorage("feature.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("feature.wittyNotificationsEnabled") private var wittyNotificationsEnabled = true
    @AppStorage("feature.notificationSavageEnabled") private var savageNotificationsEnabled = false
    @AppStorage("prompt.siriShortcutsTipDismissed") private var siriShortcutsTipDismissed = false
    @State private var didLogSiriTipShown = false

    private let proGold = BrandColor.colorPremium

    init(viewModel: AttendanceViewModel, subjectStore: SubjectStore) {
        self.viewModel = viewModel
        self.subjectStore = subjectStore
        _defaultRequiredPercentage = State(
            initialValue: SettingsSheetView.formattedPercentage(viewModel.defaultRequiredPercentage)
        )
        _selectedMarket = State(initialValue: StudentMarketStore.current)
    }

    var body: some View {
        NavigationStack {
            List {
                proSection
                inviteSection
                profileSection
                attendanceSection
                regionSection
                remindersSection
                supportSection

                #if DEBUG
                debugSection
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .listSectionSpacing(16)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BrandColor.colorBackground, for: .navigationBar)
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
            .sheet(isPresented: $isShowingProfileEditor) {
                StudentProfileEditorView(subjectStore: subjectStore)
            }
            // Redeem sheet is hosted on HomeView only — dual .sheet on the same
            // binding (Settings already a sheet) caused flaky presentation.
            #if DEBUG
            .sheet(isPresented: $isShowingDebugTools) {
                DebugToolsView(subjectStore: subjectStore)
            }
            #endif
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
            .alert("Remove my data?", isPresented: $showRemoveUserDataConfirmation) {
                Button("Remove", role: .destructive) {
                    Task { await removeUserDataFromSchoolabe() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Clears your profile on this device and marks your Schoolabe sync as removed for tracking. Attendance history on this phone stays.")
            }
            .alert("Could not remove data", isPresented: Binding(
                get: { removeUserDataErrorMessage != nil },
                set: { isPresented in
                    if isPresented == false {
                        removeUserDataErrorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(removeUserDataErrorMessage ?? "")
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
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
        }
    }

    // MARK: - Sections

    private var proSection: some View {
        Section {
            if entitlements.isPro {
                HStack(spacing: 12) {
                    settingsIcon("crown.fill", colors: [proGold, BrandColor.colorPremiumDeep])
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bunk Planner Pro")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Skip planner · Forecast · Ads off")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Active")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(BrandColor.colorAccentPrimary))
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    AnalyticsService.shared.log(.proCtaTapped(surface: "settings_pro", action: "go_pro"))
                    isShowingProPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("crown.fill", colors: [proGold, BrandColor.colorPremiumDeep], foreground: .black.opacity(0.85))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Go Pro")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Skip planner, forecast, PDF + CSV, ads off")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Pro")
        } footer: {
            if entitlements.isPro {
                Text("Banners and full-screen ads stay off.")
            } else {
                Text("Free includes ads. Invite a friend for 7 days of Pro features (ads stay on), or Go Pro to remove ads forever.")
            }
        }
        .settingsRowChrome()
    }

    private var inviteSection: some View {
        Section {
            InviteFriendsSettingsSection()
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } footer: {
            Text("7-day Pro-feature trial. Ads stay on. One redeem per install.")
        }
        .settingsRowChrome()
    }

    private var profileSection: some View {
        Section {
            Button {
                isShowingProfileEditor = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(BrandColor.colorAccentPrimary.opacity(0.18))
                            .frame(width: 40, height: 40)
                        Text(profileInitial)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(BrandColor.colorAccentPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profileTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(profileSubtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }

            Button(role: .destructive) {
                showRemoveUserDataConfirmation = true
            } label: {
                HStack {
                    Label("Remove my data from Schoolabe", systemImage: "trash")
                    Spacer()
                    if isRemovingUserData {
                        ProgressView()
                    }
                }
            }
            .disabled(isRemovingUserData)
        } header: {
            Text("You")
        } footer: {
            Text("Name, class, and college help improve Bunk Planner. Attendance history stays on this phone.")
        }
        .settingsRowChrome()
    }

    private var attendanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Default required %")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    TextField("75", text: $defaultRequiredPercentage)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(BrandColor.colorAccentPrimary)
                        .frame(width: 72)
                        .onChange(of: defaultRequiredPercentage) { _, newValue in
                            defaultRequiredPercentage = sanitizePercentage(newValue)
                        }
                }

                HStack(spacing: 8) {
                    ForEach([75, 80, 85], id: \.self) { preset in
                        let selected = abs((Double(defaultRequiredPercentage) ?? -1) - Double(preset)) < 0.05
                        Button {
                            defaultRequiredPercentage = "\(preset)"
                        } label: {
                            Text("\(preset)%")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(selected ? .black : .white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(selected ? BrandColor.colorAccentPrimary : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Button("Save") {
                        saveDefault()
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .disabled(Double(defaultRequiredPercentage).map { (0...100).contains($0) } != true)
                }
            }
            .padding(.vertical, 4)

            Button("Reset calculator inputs", role: .destructive) {
                viewModel.resetInputs()
                dismiss()
            }
        } header: {
            Text("Attendance")
        } footer: {
            Text("Default % is used for new subjects and after reset.")
        }
        .settingsRowChrome()
    }

    private var regionSection: some View {
        Section {
            HStack {
                Label("Detected", systemImage: "location.fill")
                Spacer()
                Text(StudentMarket.detect().displayName)
                    .foregroundStyle(.secondary)
            }

            Picker("Wording", selection: $selectedMarket) {
                ForEach(StudentMarket.allCases) { market in
                    Text(market.displayName).tag(market)
                }
            }
            .onChange(of: selectedMarket) { _, market in
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
        } footer: {
            Text(
                StudentMarketStore.usesSystemDetection
                    ? "Wording (bunk vs skip) and Grades labels follow your iPhone region."
                    : "Manual override is on. Use device region to go back to auto."
            )
        }
        .settingsRowChrome()
    }

    private var remindersSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label("Risk notifications", systemImage: "bell.badge.fill")
            }
            .onChange(of: notificationsEnabled) { _, enabled in
                AnalyticsService.shared.log(.notificationsToggled(enabled: enabled))
                AnalyticsUserProfile.sync(subjectStore: nil, notificationsEnabled: enabled)
                if enabled == false {
                    NotificationService.rescheduleDeadlineReminders(deadlines: [])
                }
            }

            Toggle(isOn: $wittyNotificationsEnabled) {
                Label("Witty reminder copy", systemImage: "face.smiling.fill")
            }
            .onChange(of: wittyNotificationsEnabled) { _, _ in
                subjectStore.rescheduleHabitReminders(force: true)
            }

            if wittyNotificationsEnabled {
                Toggle(isOn: $savageNotificationsEnabled) {
                    Label("Roast tone (optional)", systemImage: "flame.fill")
                }
                .onChange(of: savageNotificationsEnabled) { _, _ in
                    subjectStore.rescheduleHabitReminders(force: true)
                }
            }

            if siriShortcutsTipDismissed == false,
               AnalyticsService.shared.currentStreakDays >= 3 {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mark with Siri", systemImage: "waveform")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("“Hey Siri, mark all attended in Bunk Planner” — or ask for your safest skip this week.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Button("Got it") {
                        siriShortcutsTipDismissed = true
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .padding(.vertical, 4)
                .onAppear {
                    guard didLogSiriTipShown == false else { return }
                    didLogSiriTipShown = true
                    AnalyticsService.shared.log(.siriShortcutsTipShown)
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text(
                entitlements.hasProFeatures
                    ? "Alerts stay on this device. Pro (and the invite trial) also send a Sunday digest. Roast tone stays off unless you turn it on — never used when you’re below the line."
                    : "Alerts stay on this device. Daily reminders stay on even if witty copy is off. Roast tone is optional and stays away from shortage alerts."
            )
        }
        .settingsRowChrome()
    }

    private var supportSection: some View {
        Section {
            if showAdPrivacyChoices {
                Button("Ad Privacy Choices") {
                    openAdPrivacyChoices()
                }
            }

            NavigationLink {
                PrivacyPolicyView()
                    .analyticsScreen(.privacyPolicy)
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
            }

            NavigationLink {
                TermsOfUseView()
                    .analyticsScreen(.termsOfUse)
            } label: {
                Label("Terms of Use", systemImage: "doc.text.fill")
            }

            Button {
                openRateUsFlow()
            } label: {
                Label("Rate Bunk Planner", systemImage: "star.fill")
            }

            Link(destination: URL(string: "mailto:info@schoolabe.com")!) {
                HStack {
                    Label("Support", systemImage: "envelope.fill")
                    Spacer()
                    Text("info@schoolabe.com")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Help")
        }
        .settingsRowChrome()
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Toggle(isOn: debugProBinding) {
                Label("Debug Pro", systemImage: "hammer.fill")
            }
            Button {
                isShowingDebugTools = true
            } label: {
                Label("More debug tools", systemImage: "ladybug.fill")
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Simulator API: \(SchoolabeAPIConfiguration.syncURL?.absoluteString ?? "unset")")
        }
        .settingsRowChrome()
    }
    #endif

    private func settingsIcon(
        _ systemName: String,
        colors: [Color],
        foreground: Color = .black.opacity(0.85)
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(foreground)
        }
    }

    private var profileInitial: String {
        let name = profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var profileTitle: String {
        let name = profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Student profile" : name
    }

    private var profileSubtitle: String {
        let profile = profileStore.profile
        let classLabel = profile.classOrDegree.trimmingCharacters(in: .whitespacesAndNewlines)
        let school = InstitutionNameQuality.normalizedForStorage(profile.institutionName)
        if classLabel.isEmpty == false, school.isEmpty == false {
            return "\(classLabel) · \(school)"
        }
        if classLabel.isEmpty == false { return classLabel }
        if school.isEmpty == false { return school }
        if profileStore.didCompleteProfileStep { return "Add class and college" }
        return "Add your details"
    }

    #if DEBUG
    private var debugProBinding: Binding<Bool> {
        Binding(
            get: { entitlements.isPro },
            set: { entitlements.setProUnlocked($0) }
        )
    }
    #endif

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

    private func removeUserDataFromSchoolabe() async {
        guard isRemovingUserData == false else { return }
        isRemovingUserData = true
        defer { isRemovingUserData = false }

        do {
            try await SchoolabeSyncService.shared.deleteUserData()
            StudentProfileStore.shared.clearLocalProfile()
            subjectStore.rescheduleHabitReminders(force: true)
        } catch {
            removeUserDataErrorMessage = error.localizedDescription
            AnalyticsService.shared.log(.userDataRemoveFailed(reason: String(describing: error).prefix(80).description))
        }
    }

    private func openRateUsFlow() {
        AnalyticsService.shared.log(.rateUsTapped)
        AppStoreReviewPromptCoordinator.shared.markRatedFromSettings()
        Task { @MainActor in
            let opened = await AppStoreReviewOpener.openWriteReview()
            if opened == false {
                rateErrorMessage = "Could not open the App Store. Search for “Bunk Planner” in the App Store to leave a review."
            }
        }
    }

    private static func formattedPercentage(_ value: Double) -> String {
        let roundedValue = (value * 10).rounded() / 10
        return roundedValue.rounded(.towardZero) == roundedValue
            ? String(Int(roundedValue))
            : String(format: "%.1f", roundedValue)
    }
}

private extension View {
    func settingsRowChrome() -> some View {
        listRowBackground(Color.white.opacity(0.055))
            .listRowSeparatorTint(Color.white.opacity(0.08))
    }
}

#Preview {
    SettingsSheetView(viewModel: AttendanceViewModel(), subjectStore: SubjectStore())
}
