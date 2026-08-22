//
//  HomeView.swift
//  Student Attendance Predictor
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var viewModel: AttendanceViewModel
    @ObservedObject var subjectStore: SubjectStore
    @State private var selectedTab: HomeTab = .home
    @State private var selectedScenario: ScenarioAction = .current
    @State private var isShowingSettings = false
    @State private var isShowingSubjects = false
    @State private var isShowingSubjectPicker = false
    @State private var showAdvancedHome = false
    @State private var editingTimetableSubjectID: UUID?
    @State private var overviewEditingSubjectID: UUID?
    @State private var overviewEditingName = ""
    @State private var shareItems: [Any] = []
    @State private var isShowingShareSheet = false
    @State private var isBreakdownExpanded = false
    @State private var customAttendCount = 0
    @State private var customMissCount = 0
    @State private var forecastWeeks = SemesterSettings.weeksRemaining()
    @State private var forecastHolidayClasses = ForecastAssumptions.holidayClassCount
    @State private var forecastExpectedAbsences = ForecastAssumptions.plannedBunks
    @State private var forecastClassesPerWeek = ForecastAssumptions.fallbackClassesPerWeek
    @State private var showForecastAssumptions = false
    @State private var expandedForecastSubjectIDs: Set<UUID> = []
    @State private var semesterStartDate = SemesterSettings.startDate ?? Date()
    @State private var semesterEndDate = SemesterSettings.endDate ?? Calendar.current.date(byAdding: .weekOfYear, value: 16, to: Date())!
    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @ObservedObject private var softPaywall = SoftPaywallCoordinator.shared
    @StateObject private var gpaStore = GPAStore()
    @StateObject private var deadlineStore = DeadlineStore()
    @State private var isShowingProPaywall = false
    @State private var proPaywallSource = "forecast"
    @State private var isShowingSubjectLimitAlert = false
    @State private var studentMarket = StudentMarketStore.current
    @State private var isExportingPDF = false
    @State private var exportErrorMessage: String?
    @State private var skipPlannerDay: Date?
    @State private var showWidgetPrompt = false
    @State private var highlightMarkToday = false
    @ObservedObject private var guidedSetup = GuidedSetupStore.shared
    @ObservedObject private var notificationRoute = NotificationRouteStore.shared

    private var hasAttendanceData: Bool {
        viewModel.totalClasses > 0
    }
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    /// Light tail padding inside tab scroll views (iPhone FAB clearance uses `safeAreaInset`, not this value).
    private var tabScrollBottomPadding: CGFloat { 24 }

    @ViewBuilder
    private var bottomChrome: some View {
        VStack(spacing: 0) {
            if selectedTab == .home {
                floatingActionBanner(for: viewModel.result)
                    .padding(.horizontal, isRegularWidth ? 28 : 20)
                    .padding(.top, 6)
                    .padding(.bottom, isRegularWidth ? 6 : 8)
            }
        }
    }

    /// iPhone: floating “Attend … next” strip inside scroll `safeAreaInset` so content never sits under it.
    @ViewBuilder
    private var phoneFloatingResultStrip: some View {
        VStack(spacing: 0) {
            floatingActionBanner(for: viewModel.result)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.05, green: 0.06, blue: 0.1))
    }

    private func phoneScrollWithFABInset<Content: View>(@ViewBuilder scroll: () -> Content) -> some View {
        scroll()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isRegularWidth && selectedTab == .home {
                    phoneFloatingResultStrip
                }
            }
    }

    var body: some View {
        NavigationStack {
            homeRootContent
                .modifier(HomePresentationModifier(
                    selectedTab: selectedTab,
                    subjectStore: subjectStore,
                    viewModel: viewModel,
                    entitlements: entitlements,
                    shareItems: shareItems,
                    isShowingShareSheet: $isShowingShareSheet,
                    isShowingSettings: $isShowingSettings,
                    isShowingSubjects: $isShowingSubjects,
                    isShowingSubjectPicker: $isShowingSubjectPicker,
                    editingTimetableSubjectID: $editingTimetableSubjectID,
                    isShowingSubjectLimitAlert: $isShowingSubjectLimitAlert,
                    exportErrorMessage: $exportErrorMessage,
                    isShowingProPaywall: $isShowingProPaywall,
                    proPaywallSource: $proPaywallSource,
                    studentMarket: $studentMarket
                ))
                .applyImpactFeedback(trigger: viewModel.attendedClassesInput)
                .applyImpactFeedback(trigger: viewModel.totalClassesInput)
                .onChange(of: softPaywall.pendingSource) { _, source in
                    guard let source else { return }
                    let captured = source
                    softPaywall.clearPending()
                    Task { @MainActor in
                        // Streak / at-risk wait for Mark Today celebration; forecast can present sooner.
                        let delay: UInt64 = captured == "locked_forecast" || captured == "habit_value"
                            ? 900_000_000
                            : 1_800_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        guard entitlements.isPro == false else { return }
                        proPaywallSource = captured
                        isShowingProPaywall = true
                    }
                }
                .onAppear {
                    consumeNotificationRoute(notificationRoute.pendingDestination)
                    refreshGuidedSetup()
                    SoftPaywallCoordinator.shared.evaluateHabitValuePaywall(
                        daysSinceInstall: AnalyticsService.shared.daysSinceInstall,
                        hasMarkedDay: AnalyticsService.shared.hasMarkedAtLeastOnce
                    )
                }
                .onChange(of: subjectStore.subjects.count) { _, _ in
                    refreshGuidedSetup()
                }
                .onChange(of: notificationRoute.pendingDestination) { _, destination in
                    consumeNotificationRoute(destination)
                }
                .onChange(of: entitlements.isPro) { _, _ in
                    subjectStore.rescheduleHabitReminders(force: true)
                }
                .sheet(
                    isPresented: Binding(
                        get: { skipPlannerDay != nil },
                        set: { if $0 == false { skipPlannerDay = nil } }
                    )
                ) {
                    if let day = skipPlannerDay {
                        SkipPlannerSheet(
                            result: SkipPlanner.evaluate(date: day, subjects: subjectStore.subjects)
                        )
                    }
                }
        }
    }

    private func consumeNotificationRoute(_ destination: NotificationRoute?) {
        guard let destination else { return }
        switch destination {
        case .home:
            selectedTab = .home
        case .markToday:
            selectedTab = .home
            highlightMarkToday = true
        case .skipPlanner:
            selectedTab = .home
            skipPlannerDay = Calendar.current.startOfDay(for: Date())
            AnalyticsService.shared.log(.skipPlannerViewed(dayCount: subjectStore.subjectsForMarkToday(on: Date()).count))
        case .tools:
            selectedTab = .tools
        case .insights:
            selectedTab = .insights
        case .log:
            selectedTab = .log
        case .overview:
            selectedTab = .overview
        }
        notificationRoute.clear()
        AnalyticsService.shared.log(.notificationDeepLinkOpened(destination: destination.rawValue))
    }

    private var homeRootContent: some View {
        ZStack {
            animatedBackground
            mainNavigationContent
        }
        .preferredColorScheme(.dark)
        .navigationTitle(selectedTab.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    triggerLightHaptic()
                    isShowingSubjects = true
                } label: {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(.white)
                }

                Button {
                    triggerLightHaptic()
                    AnalyticsService.shared.log(.settingsOpened)
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white)
                }
            }
        }
        .onChange(of: viewModel.totalClassesInput) { _, _ in
            resetScenarioIfNeeded()
        }
        .onChange(of: viewModel.attendedClassesInput) { _, _ in
            resetScenarioIfNeeded()
        }
        .onChange(of: viewModel.requiredPercentageInput) { _, _ in
            resetScenarioIfNeeded()
        }
        .onChange(of: viewModel.reviewRequestToken) { _, _ in
            // Let the Safe result settle on screen before the system review dialog.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                requestAppReview()
            }
        }
        .alert("Add a Home Screen widget?", isPresented: $showWidgetPrompt) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("Long-press your Home Screen → tap + → search Bunk Planner to see attendance and safe bunks at a glance.")
        }
    }

    private func refreshGuidedSetup() {
        guidedSetup.refresh(
            subjectCount: subjectStore.subjects.count,
            hasMarked: AnalyticsService.shared.hasMarkedAtLeastOnce
        )
    }

    private func maybeShowWidgetPrompt() {
        let key = "prompt.widgetAfterFirstMark"
        guard UserDefaults.standard.bool(forKey: key) == false else { return }
        guard AnalyticsService.shared.hasMarkedAtLeastOnce else { return }
        UserDefaults.standard.set(true, forKey: key)
        AnalyticsService.shared.log(.widgetPromptShown)
        showWidgetPrompt = true
    }
    
    @ViewBuilder
    private var mainNavigationContent: some View {
        if isRegularWidth {
            ipadTabContainer
        } else {
            phoneTabContainer
        }
    }
    
    private var phoneTabContainer: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    homeTabContent
                case .insights:
                    insightsTabContent
                case .log:
                    logTabContent
                case .overview:
                    overviewTabContent
                case .tools:
                    toolsTabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            phoneTabBar
        }
    }

    private var phoneTabBar: some View {
        HStack(spacing: 0) {
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .background(Color(red: 0.05, green: 0.06, blue: 0.1))
    }
    
    private var ipadTabContainer: some View {
        HStack(alignment: .top, spacing: 16) {
            ipadSidebarRail
            VStack(spacing: 0) {
                selectedTabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.05, green: 0.06, blue: 0.1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var ipadSidebarRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sections")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(1.0)
            
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 18)
                        Text(tab.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.black : Color.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTab == tab ? Color.white : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(selectedTab == tab ? 0.0 : 0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 180, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .home:
            homeTabContent
        case .insights:
            insightsTabContent
        case .log:
            logTabContent
        case .overview:
            overviewTabContent
        case .tools:
            toolsTabContent
        }
    }

    private var toolsTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                ToolsView(
                    subjectStore: subjectStore,
                    gpaStore: gpaStore,
                    deadlineStore: deadlineStore
                )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .padding(.bottom, tabScrollBottomPadding)
                    .frame(maxWidth: isRegularWidth ? 920 : .infinity, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var logTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                VStack(spacing: 24) {
                    AttendanceLogView(subjectStore: subjectStore)
                    // No banner here — Log previously reused the Insights unit and
                    // doubled requests every tab switch without adding inventory.
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, tabScrollBottomPadding)
                .frame(maxWidth: isRegularWidth ? 920 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var homeTabContent: some View {
        phoneScrollWithFABInset {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        compactHeaderSection
                        if let progress = SemesterSettings.progress() {
                            SemesterProgressStrip(progress: progress)
                        }
                        if let step = guidedSetup.activeStep {
                            GuidedSetupBanner(step: step) {
                                guidedSetup.complete()
                            }
                        }
                        subjectPickerChip

                        MarkTodayCard(
                            subjectStore: subjectStore,
                            isHighlighted: highlightMarkToday,
                            onCelebrated: {
                                refreshGuidedSetup()
                                maybeShowWidgetPrompt()
                            },
                            onAddSubject: { isShowingSubjects = true }
                        )
                        .id("markTodayCard")

                        upcomingExamAttendanceWarning

                        AdMobBannerCard(
                            placement: AdMobConfiguration.Placement.home,
                            isActive: selectedTab == .home
                        )

                        // Calculator sits under Today's Classes + banner.
                        inputSection

                        if hasAttendanceData {
                            assistantHeroSection
                            proUpsellCard
                            scenariosDisclosure
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .padding(.bottom, tabScrollBottomPadding)
                    .frame(maxWidth: isRegularWidth ? 920 : .infinity, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .onChange(of: highlightMarkToday) { _, highlighted in
                    guard highlighted else { return }
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo("markTodayCard", anchor: .center)
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 3_500_000_000)
                        highlightMarkToday = false
                    }
                }
            }
        }
    }

    private var insightsTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                VStack(spacing: 24) {
                    if let progress = SemesterSettings.progress() {
                        SemesterProgressStrip(progress: progress)
                    }
                    weeklySummaryCard
                    skipPlannerWeekCard
                    AdMobBannerCard(
                        placement: AdMobConfiguration.Placement.insights,
                        isActive: selectedTab == .insights
                    )
                    streakAndHighlightsCard
                    gamificationBadgesCard
                    trendGraphCard
                    subjectForecastCard
                    proUpsellCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, tabScrollBottomPadding)
                .frame(maxWidth: isRegularWidth ? 920 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var overviewTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                VStack(spacing: 24) {
                    allSubjectsDashboardCard
                    AdMobBannerCard(
                        placement: AdMobConfiguration.Placement.overview,
                        isActive: selectedTab == .overview
                    )
                    overviewSubjectManagerCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, tabScrollBottomPadding)
                .frame(maxWidth: isRegularWidth ? 920 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private var upcomingExamAttendanceWarning: some View {
        Group {
            if let warning = nearestExamAttendanceWarning {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(warning.title)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(warning.body)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                )
                .onAppear {
                    AnalyticsService.shared.log(.academicExamAttendanceWarningShown)
                }
            }
        }
    }

    /// When an exam/assignment is within 7 days and names a subject that matches
    /// an attendance subject, warn the user before they bunk.
    private var nearestExamAttendanceWarning: (title: String, body: String)? {
        let nearby = deadlineStore.upcomingWithin(days: 7)
            .filter { $0.kind == .exam || $0.kind == .assignment || $0.kind == .project }
        guard let item = nearby.first else { return nil }

        let courseHint = item.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedSubject: String? = {
            guard courseHint.isEmpty == false else {
                return subjectStore.selectedSubjectName == "Subject" ? nil : subjectStore.selectedSubjectName
            }
            if let match = subjectStore.subjects.first(where: {
                $0.name.localizedCaseInsensitiveContains(courseHint)
                    || courseHint.localizedCaseInsensitiveContains($0.name)
            }) {
                return match.name
            }
            return courseHint
        }()

        let when = item.countdownLabel.lowercased()
        let subjectBit = matchedSubject.map { " for \($0)" } ?? ""
        let title = "\(item.kind.title) \(when)"
        let body = "\(item.title)\(subjectBit). Think twice before you \(studentMarket.skipVerb) — protect attendance this week."
        return (title, body)
    }

    private var proUpsellCard: some View {
        Group {
            if entitlements.isPro == false {
                let atRisk = subjectStore.dashboardSummary.riskSubjects > 0
                let skip = studentMarket.skipVerb
                VStack(alignment: .leading, spacing: 12) {
                    Text(atRisk ? "Attendance is in the danger zone" : "Pay once. Ads gone for good.")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(
                        atRisk
                            ? "Pro shows how many classes to attend to recover — and whether you can still \(skip) later."
                            : "Lifetime Pro: skip planner, forecast, unlimited subjects, PDF + CSV, ads off."
                    )
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))

                    if atRisk {
                        Button {
                            triggerLightHaptic()
                            AnalyticsService.shared.log(
                                .proCtaTapped(surface: "at_risk_home", action: "skip_planner")
                            )
                            skipPlannerDay = Calendar.current.startOfDay(for: Date())
                            AnalyticsService.shared.log(.skipPlannerViewed(dayCount: subjectStore.subjectsForMarkToday(on: Date()).count))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.checkmark")
                                Text("Plan skips free")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }

                    Button {
                        triggerLightHaptic()
                        let surface = atRisk ? "at_risk_home" : "pro_upsell"
                        AnalyticsService.shared.log(
                            .proCtaTapped(surface: surface, action: "go_pro")
                        )
                        proPaywallSource = surface
                        isShowingProPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                            Text(atRisk ? "Go Pro · See recovery path" : "Go Pro · Pay once, ads gone")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.86, blue: 0.42),
                                            Color(red: 0.95, green: 0.58, blue: 0.18)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .onAppear {
                    AnalyticsService.shared.logProCtaShownOnce(
                        surface: atRisk ? "at_risk_home" : "pro_upsell"
                    )
                }
            }
        }
    }

    private var animatedBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.10),
                Color(red: 0.07, green: 0.08, blue: 0.14),
                Color(red: 0.04, green: 0.07, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var compactHeaderSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bunk Planner")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Enter classes → see how many you can \(studentMarket.skipVerb).")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subjectPickerChip: some View {
        Button {
            triggerLightHaptic()
            isShowingSubjectPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))

                VStack(alignment: .leading, spacing: 2) {
                    Text(subjectStore.selectedSubjectName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let result = viewModel.result, hasAttendanceData {
                        Text("\(Int(result.currentPercentage.rounded()))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("Tap to switch \(studentMarket.courseNoun)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var advancedDetailsDisclosure: some View {
        scenariosDisclosure
    }

    private var scenariosDisclosure: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                triggerLightHaptic()
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAdvancedHome.toggle()
                }
            } label: {
                HStack {
                    Text(showAdvancedHome ? "Hide what-if scenarios" : "What if I skip / attend more?")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: showAdvancedHome ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }
            .buttonStyle(PressableButtonStyle())

            if showAdvancedHome, let result = displayResult {
                VStack(spacing: 20) {
                    scenarioSection(baseResult: viewModel.result, displayedResult: result)
                    riskAlertsCard(for: result)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var headerSection: some View {
        compactHeaderSection
    }

    private var activeSubjectSelectorCard: some View {
        subjectPickerChip
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your numbers")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Type totals — result updates as you go.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            inputField(title: "TOTAL CLASSES", text: $viewModel.totalClassesInput, keyboardType: .numberPad)
            inputField(title: "ATTENDED", text: $viewModel.attendedClassesInput, keyboardType: .numberPad)
            inputField(title: "REQUIRED %", text: $viewModel.requiredPercentageInput, keyboardType: .decimalPad)
            requiredPresetsRow
            clearInputsButton
            validationBanner
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        )
    }

    private var requiredPresetsRow: some View {
        HStack(spacing: 10) {
            Text("Quick presets")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.trailing, 4)

            ForEach([75, 80, 85], id: \.self) { preset in
                let isSelected = Int(viewModel.requiredPercentage.rounded()) == preset

                Button {
                    triggerLightHaptic()
                    viewModel.applyRequiredPercentagePreset(Double(preset))
                } label: {
                    Text("\(preset)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }

            Spacer()
        }
    }

    private var clearInputsButton: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                triggerLightHaptic()
                viewModel.resetInputs()
                selectedScenario = .current
            } label: {
                Label("Clear all", systemImage: "trash")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.red.opacity(0.2))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var homeHeroSection: AnyView {
        AnyView(assistantHeroSection)
    }

    @ViewBuilder
    private var assistantHeroSection: some View {
        if let result = viewModel.result, hasAttendanceData {
            assistantHeroCard(for: result)
        } else {
            welcomeEmptyState
        }
    }

    private var welcomeEmptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome 👋")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Let's calculate your attendance.\nAdd your first subject — or mark today's class to get started.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                triggerLightHaptic()
                isShowingSubjectPicker = true
            } label: {
                Text("Get Started")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.32, green: 0.84, blue: 1.0))
                    )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func assistantHeroCard(for result: AttendanceResult) -> some View {
        let isSafe = result.status == .safe
        let accent = isSafe ? Color(red: 0.2, green: 0.9, blue: 0.5) : Color(red: 1.0, green: 0.35, blue: 0.4)
        let attendImpact = viewModel.simulatedResult(attendMore: 1)
        let skipImpact = viewModel.simulatedResult(skipMore: 1)

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Today's Attendance")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button {
                    triggerLightHaptic()
                    shareResult(result)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(PressableButtonStyle())
            }

            Text(assistantHeadline(for: result))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(result.currentPercentage.rounded()))%")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSafe ? "Safe to skip" : "Need to attend")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(isSafe
                          ? "\(result.bunkAllowed) class\(result.bunkAllowed == 1 ? "" : "es")"
                          : "\(result.recoveryNeeded) more")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            if let selected = subjectStore.selectedSubject {
                let left = subjectStore.classesLeftThisSemester(
                    for: selected,
                    weeks: forecastWeeks,
                    holidayClassCount: forecastHolidayClasses,
                    plannedBunks: forecastExpectedAbsences,
                    fallbackClassesPerWeek: forecastClassesPerWeek
                )
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
                    Text(left == 1
                          ? "1 class left this semester"
                          : "\(left) classes left this semester")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if let attendImpact, let skipImpact {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tomorrow")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(0.8)

                    HStack(spacing: 10) {
                        tomorrowChip(
                            title: "Attend",
                            value: String(format: "%.1f%%", attendImpact.currentPercentage),
                            tint: Color(red: 0.2, green: 0.9, blue: 0.5)
                        )
                        tomorrowChip(
                            title: "Skip",
                            value: String(format: "%.1f%%", skipImpact.currentPercentage),
                            tint: .orange
                        )
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1.2)
                )
        )
    }

    private func tomorrowChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func assistantHeadline(for result: AttendanceResult) -> String {
        if isPerfectAttendance(result: result) {
            return "Perfect streak — keep it going ✨"
        }
        if isRecoveryMode(result: result) {
            return "Recovery mode — you can bounce back."
        }
        if result.status == .safe {
            return result.bunkAllowed > 0
                ? "Good news 🎉\nYou can safely miss \(result.bunkAllowed) more class\(result.bunkAllowed == 1 ? "" : "es")."
                : "You're right on the safe line."
        }
        return "Attend the next \(result.recoveryNeeded) class\(result.recoveryNeeded == 1 ? "" : "es") to recover."
    }

    private var homeSupportingSection: some View {
        Group {
            if let result = displayResult {
                VStack(spacing: 24) {
                    riskAlertsCard(for: result)
                    scenarioSection(baseResult: viewModel.result, displayedResult: result)
                    nextClassImpactCard
                }
            }
        }
    }

    private var overviewSubjectManagerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Manage \(studentMarket.courseNounPluralTitle)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    triggerLightHaptic()
                    attemptAddSubject()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .buttonStyle(PressableButtonStyle())
            }

            if subjectStore.subjects.isEmpty {
                Text("No \(studentMarket.courseNounPlural) yet.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                ForEach(subjectStore.subjects) { subject in
                    VStack(alignment: .leading, spacing: 10) {
                        if overviewEditingSubjectID == subject.id {
                            TextField("Subject name", text: $overviewEditingName)
                                .textInputAutocapitalization(.words)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.28))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                        } else {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject.name)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Attendance \(String(format: "%.1f%%", subject.currentPercentage))")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                if subject.id == subjectStore.selectedSubjectID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Button("Use") {
                                triggerLightHaptic()
                                subjectStore.selectSubject(subject)
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .buttonStyle(PressableButtonStyle())

                            if overviewEditingSubjectID == subject.id {
                                Button("Save") {
                                    triggerLightHaptic()
                                    subjectStore.renameSubject(id: subject.id, to: overviewEditingName)
                                    overviewEditingSubjectID = nil
                                    overviewEditingName = ""
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .buttonStyle(PressableButtonStyle())
                                .disabled(overviewEditingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Cancel") {
                                    triggerLightHaptic()
                                    overviewEditingSubjectID = nil
                                    overviewEditingName = ""
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .buttonStyle(PressableButtonStyle())
                            } else {
                                Button("Rename") {
                                    triggerLightHaptic()
                                    overviewEditingSubjectID = subject.id
                                    overviewEditingName = subject.name
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .buttonStyle(PressableButtonStyle())
                            }

                            Button("Timetable") {
                                openTimetableEditor(for: subject.id)
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .buttonStyle(PressableButtonStyle())

                            Button(role: .destructive) {
                                triggerLightHaptic()
                                subjectStore.deleteSubject(id: subject.id)
                                if overviewEditingSubjectID == subject.id {
                                    overviewEditingSubjectID = nil
                                    overviewEditingName = ""
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                Button("Open Full \(studentMarket.courseNoun.capitalized) Manager") {
                    isShowingSubjects = true
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func inputField(title: String, text: Binding<String>, keyboardType: KeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .tracking(1.2)

            HStack(spacing: 12) {
                stepperButton(symbol: "minus", text: text, keyboardType: keyboardType, delta: -1)

                TextField("0", text: text)
                    .applyKeyboardType(keyboardType)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                stepperButton(symbol: "plus", text: text, keyboardType: keyboardType, delta: 1)
            }
        }
    }

    private var validationBanner: some View {
        Group {
            if let validationMessage = viewModel.validationMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4))
                    Text(validationMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var placeholderSection: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(height: 160)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text("Awaiting data input...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
            )
    }

    private func heroCard(for result: AttendanceResult) -> some View {
        let isSafe = result.status == .safe
        let primaryStatusColor = isSafe ? Color(red: 0.1, green: 0.8, blue: 0.4) : Color(red: 1.0, green: 0.2, blue: 0.4)
        let secondaryStatusColor = isSafe ? Color(red: 0.0, green: 0.5, blue: 0.3) : Color(red: 0.8, green: 0.1, blue: 0.2)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: statusIconName(for: result))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(primaryStatusColor)
                        .shadow(color: primaryStatusColor.opacity(0.4), radius: 4, x: 0, y: 0)

                    Text(statusTitle(for: result))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(primaryStatusColor)
                        .tracking(1.5)
                }

                Spacer()

                Button {
                    triggerLightHaptic()
                    shareResult(result)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }

            Text(heroTitle(for: result))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.2), radius: 4, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(formattedPercentage(result.currentPercentage))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(primaryStatusColor)

            Text(heroSubtitle(for: result))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            progressBar(for: result, color: primaryStatusColor)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [primaryStatusColor.opacity(0.5), .clear, secondaryStatusColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: primaryStatusColor.opacity(0.08), radius: 20, x: 0, y: 10)
    }

    private func scenarioSection(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What if…")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Pick a natural scenario — calculations stay behind the scenes.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ScenarioAction.allCases) { scenario in
                    Button {
                        triggerLightHaptic()
                        selectedScenario = scenario
                        AnalyticsService.shared.log(.scenarioSelected(scenario: scenario.description))
                    } label: {
                        let isSelected = selectedScenario == scenario
                        let accentColor = Color(red: 0.3, green: 0.7, blue: 1.0)

                        Text(scenario.label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? accentColor.opacity(0.22) : Color.black.opacity(0.22))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(isSelected ? accentColor : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
                                    )
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            if selectedScenario == .custom {
                HStack {
                    Stepper("Skip \(customMissCount)", value: $customMissCount, in: 0...20)
                    Spacer()
                    Stepper("Attend \(customAttendCount)", value: $customAttendCount, in: 0...20)
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            }

            Text(scenarioInsight(baseResult: baseResult, displayedResult: displayedResult))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.9, green: 0.9, blue: 1.0).opacity(0.75))
                .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func riskAlertsCard(for result: AttendanceResult) -> some View {
        let riskLevel = CalculationService.riskLevel(
            attended: viewModel.attendedClasses,
            total: viewModel.totalClasses,
            required: viewModel.requiredPercentage
        )

        let message: String = {
            switch riskLevel {
            case .stable:
                return "Early risk check: Stable. You have healthy \(studentMarket.skipVerb) buffer."
            case .warning:
                return "Early risk warning: You are close to threshold. Avoid unnecessary absences."
            case .critical:
                return "Critical risk: falling below target. Prioritize attendance recovery now."
            }
        }()

        let color: Color = {
            switch riskLevel {
            case .stable:
                return Color(red: 0.2, green: 0.9, blue: 0.5)
            case .warning:
                return .orange
            case .critical:
                return .red
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            Text("RISK ALERTS")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))

            if result.status == .safe {
                Text("Safe \(studentMarket.skipVerb) buffer now: \(result.bunkAllowed)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            } else {
                Text("Recovery needed now: attend next \(result.recoveryNeeded) classes.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var whatIfWorkbenchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT-IF SIMULATOR")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            HStack {
                Stepper("Miss next \(customMissCount)", value: $customMissCount, in: 0...20)
                Spacer()
                Stepper("Attend next \(customAttendCount)", value: $customAttendCount, in: 0...20)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))

            if let customResult = viewModel.simulatedResult(attendMore: customAttendCount, skipMore: customMissCount) {
                Text("Projected attendance: \(String(format: "%.1f%%", customResult.currentPercentage))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(customResult.status == .safe ? Color.green : Color.orange)

                Text(customResult.status == .safe
                     ? "You can still miss \(customResult.bunkAllowed) more classes safely."
                     : "You would need \(customResult.recoveryNeeded) consecutive attended classes to recover.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("Enter attendance values to run what-if simulations.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var subjectForecastCard: some View {
        if entitlements.isForecastUnlocked {
            forecastDetailCard
        } else {
            lockedForecastCard
        }
    }

    private var lockedForecastCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
                Text("SUBJECT FORECAST")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .tracking(1.1)
            }

            Text("See where each subject lands by the end of the semester — and which ones may fall below target.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            if let preview = lockedForecastPreviewLine {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
                    Text(preview)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            }

            Button {
                triggerLightHaptic()
                AnalyticsService.shared.log(
                    .proCtaTapped(surface: "locked_forecast", action: "go_pro")
                )
                proPaywallSource = "forecast"
                isShowingProPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Go Pro · Unlock forecast forever")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.86, blue: 0.42),
                                    Color(red: 0.95, green: 0.58, blue: 0.18)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            AnalyticsService.shared.log(.lockedForecastViewed)
            AnalyticsService.shared.logProCtaShownOnce(surface: "locked_forecast")
        }
    }

    private var lockedForecastPreviewLine: String? {
        guard subjectStore.subjects.isEmpty == false else { return nil }
        let avg = Int(subjectStore.dashboardSummary.averageAttendance.rounded())
        if let worst = subjectStore.dashboardSummary.mostAtRiskSubject {
            let pct = Int(worst.currentPercentage.rounded())
            let req = Int(worst.requiredPercentage.rounded())
            if pct < req {
                return "\(worst.name): \(pct)% now · need \(req)% — Pro shows the path."
            }
            return "\(worst.name): \(pct)% · class avg \(avg)%."
        }
        return "Class average: \(avg)% today."
    }

    private var forecastDetailCard: some View {
        let forecasts = subjectStore.subjectForecasts(
            weeks: forecastWeeks,
            holidayClassCount: forecastHolidayClasses,
            expectedAbsences: forecastExpectedAbsences,
            fallbackClassesPerWeek: forecastClassesPerWeek
        )
        let needsFallback = subjectStore.subjects.contains { $0.weeklySchedule.totalPerWeek == 0 }

        return VStack(alignment: .leading, spacing: 18) {
            Text("Subject Forecast")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            plannedBunksPrimaryInput

            forecastAssumptionsDisclosure(showClassesPerWeek: needsFallback)

            VStack(alignment: .leading, spacing: 12) {
                Text("Projected Attendance")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if forecasts.isEmpty {
                    Text("Add a subject with attendance to see projections.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                } else {
                    ForEach(forecasts) { item in
                        forecastAccordionCard(for: item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            AnalyticsService.shared.log(.forecastViewed)
            SemesterSettings.ensureDefaultDatesIfNeeded()
            refreshForecastAssumptionsFromSources()
        }
        .onChange(of: forecastHolidayClasses) { _, value in
            ForecastAssumptions.holidayClassCount = value
        }
        .onChange(of: forecastExpectedAbsences) { _, value in
            ForecastAssumptions.plannedBunks = value
        }
        .onChange(of: forecastClassesPerWeek) { _, value in
            ForecastAssumptions.fallbackClassesPerWeek = value
        }
    }

    private var plannedBunksPrimaryInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How many classes do you plan to miss?")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 18) {
                Button {
                    triggerLightHaptic()
                    forecastExpectedAbsences = max(0, forecastExpectedAbsences - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle().fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(PressableButtonStyle())

                Text("\(forecastExpectedAbsences)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
                    .frame(minWidth: 64)

                Button {
                    triggerLightHaptic()
                    forecastExpectedAbsences = min(80, forecastExpectedAbsences + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle().fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(PressableButtonStyle())

                Spacer(minLength: 0)
            }

            Text("Classes you plan to miss this semester")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.32, green: 0.84, blue: 1.0).opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func forecastAssumptionsDisclosure(showClassesPerWeek: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                triggerLightHaptic()
                withAnimation(.easeInOut(duration: 0.22)) {
                    showForecastAssumptions.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Forecast Assumptions")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(forecastAssumptionsSummary(showClassesPerWeek: showClassesPerWeek))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(showForecastAssumptions ? "Hide" : "Edit")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
                    Image(systemName: showForecastAssumptions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .buttonStyle(PressableButtonStyle())

            if showForecastAssumptions {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Semester dates")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        DatePicker(
                            "Start",
                            selection: $semesterStartDate,
                            displayedComponents: .date
                        )
                        .tint(Color(red: 0.32, green: 0.84, blue: 1.0))
                        .onChange(of: semesterStartDate) { _, newValue in
                            SemesterSettings.startDate = newValue
                            forecastWeeks = SemesterSettings.weeksRemaining()
                        }
                        DatePicker(
                            "End",
                            selection: $semesterEndDate,
                            in: semesterStartDate...,
                            displayedComponents: .date
                        )
                        .tint(Color(red: 0.32, green: 0.84, blue: 1.0))
                        .onChange(of: semesterEndDate) { _, newValue in
                            SemesterSettings.endDate = newValue
                            forecastWeeks = SemesterSettings.weeksRemaining()
                        }
                        Text("Semester remaining: \(forecastWeeks) week\(forecastWeeks == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
                    }

                    if showClassesPerWeek {
                        forecastAssumptionStepper(
                            title: "Classes per Week",
                            valueLabel: "\(forecastClassesPerWeek)",
                            hint: "Fallback when a subject has no timetable",
                            value: $forecastClassesPerWeek,
                            range: 1...20
                        )
                    } else {
                        Text("Classes per week are read from each subject's timetable.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    forecastAssumptionStepper(
                        title: "College Holidays",
                        valueLabel: "\(forecastHolidayClasses) cancelled",
                        hint: "Defaults to 0 — change only if needed",
                        value: $forecastHolidayClasses,
                        range: 0...40
                    )

                    holidayPresetsSection
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func forecastAssumptionsSummary(showClassesPerWeek: Bool) -> String {
        var parts = ["\(forecastWeeks) weeks left", "\(forecastHolidayClasses) holidays"]
        if showClassesPerWeek {
            parts.append("\(forecastClassesPerWeek)/week fallback")
        } else {
            parts.append("timetable")
        }
        return parts.joined(separator: " · ")
    }

    private var holidayPresetsSection: some View {
        let presets = HolidayPresets.options(for: studentMarket)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Holiday presets")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            if presets.isEmpty {
                Text("No presets for your region — use the stepper above.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets) { preset in
                            Button {
                                triggerLightHaptic()
                                forecastHolidayClasses = preset.cancelledClasses
                                AnalyticsService.shared.log(
                                    .holidayPresetApplied(
                                        presetID: preset.id,
                                        cancelledClasses: preset.cancelledClasses
                                    )
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.title)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                    Text("\(preset.cancelledClasses) cancelled")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func refreshForecastAssumptionsFromSources() {
        if let end = SemesterSettings.endDate {
            semesterEndDate = end
        }
        if let start = SemesterSettings.startDate {
            semesterStartDate = start
        }
        forecastWeeks = SemesterSettings.weeksRemaining()
        forecastHolidayClasses = ForecastAssumptions.holidayClassCount
        forecastExpectedAbsences = ForecastAssumptions.plannedBunks
        forecastClassesPerWeek = ForecastAssumptions.fallbackClassesPerWeek
        syncForecastClassesPerWeekDefault()
    }

    private func syncForecastClassesPerWeekDefault() {
        if let selected = subjectStore.subjects.first(where: { $0.id == subjectStore.selectedSubjectID }),
           selected.weeklySchedule.totalPerWeek > 0 {
            forecastClassesPerWeek = selected.weeklySchedule.totalPerWeek
        } else if let any = subjectStore.subjects.first(where: { $0.weeklySchedule.totalPerWeek > 0 }) {
            forecastClassesPerWeek = any.weeklySchedule.totalPerWeek
        }
    }

    private func forecastAssumptionStepper(
        title: String,
        valueLabel: String,
        hint: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
            }

            Text(hint)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(Color(red: 0.32, green: 0.84, blue: 1.0))
        }
        .padding(.vertical, 4)
    }

    private func forecastAccordionCard(for item: SubjectForecast) -> some View {
        let isExpanded = expandedForecastSubjectIDs.contains(item.id)
        let statusColor = colorForRiskLevel(item.riskLevel)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                triggerLightHaptic()
                withAnimation(.easeInOut(duration: 0.22)) {
                    if isExpanded {
                        expandedForecastSubjectIDs.remove(item.id)
                    } else {
                        expandedForecastSubjectIDs.insert(item.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.subjectName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(item.primaryActionMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(String(format: "%.0f%%", item.forecastedPercentage))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(item.willFallBelowTarget ? Color.orange : .white)
                        forecastStatusBadge(item.riskLevel)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(14)
            }
            .buttonStyle(PressableButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().overlay(Color.white.opacity(0.08))

                    Text(item.primaryActionMessage)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(statusColor)
                        .fixedSize(horizontal: false, vertical: true)

                    forecastVisualComparison(for: item)

                    Text(forecastStatusMessage(for: item))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)

                    if item.usedFallbackSchedule {
                        Text("No timetable — using \(forecastClassesPerWeek) classes/week. Set a timetable for accuracy.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.28).opacity(0.9))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(statusColor.opacity(item.riskLevel == .stable ? 0.15 : 0.35), lineWidth: 1)
                )
        )
    }

    private func forecastStatusBadge(_ level: RiskAlertLevel) -> some View {
        let color = colorForRiskLevel(level)
        let icon: String = {
            switch level {
            case .stable: return "🟢"
            case .warning: return "🟡"
            case .critical: return "🔴"
            }
        }()

        return Text("\(icon) \(level.rawValue)")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.16))
            )
    }

    private func forecastVisualComparison(for item: SubjectForecast) -> some View {
        let delta = item.forecastedPercentage - item.currentPercentage
        let deltaText: String = {
            if item.isStableProjection { return "No change expected" }
            let sign = delta > 0 ? "+" : ""
            return "\(sign)\(String(format: "%.0f", delta))%"
        }()

        return VStack(alignment: .leading, spacing: 12) {
            forecastPercentBar(
                label: "Current",
                percentage: item.currentPercentage,
                tint: Color(red: 0.32, green: 0.84, blue: 1.0)
            )

            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: item.isStableProjection ? "equal" : (delta < 0 ? "arrow.down" : "arrow.up"))
                        .font(.system(size: 12, weight: .bold))
                    Text(deltaText)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(
                    item.isStableProjection
                        ? Color.white.opacity(0.45)
                        : (delta < 0 ? Color.orange : Color(red: 0.2, green: 0.9, blue: 0.5))
                )
                Spacer()
            }

            forecastPercentBar(
                label: "Projected",
                percentage: item.forecastedPercentage,
                tint: item.willFallBelowTarget ? Color.orange : Color(red: 0.2, green: 0.9, blue: 0.5)
            )
        }
    }

    private func forecastPercentBar(label: String, percentage: Double, tint: Color) -> some View {
        let ratio = CGFloat(min(max(percentage / 100, 0), 1))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(10, geo.size.width * ratio))
                }
            }
            .frame(height: 12)
        }
    }

    private func forecastStatusMessage(for item: SubjectForecast) -> String {
        let target = Int(item.requiredPercentage.rounded())
        if item.expectedClasses == 0 {
            return "Remaining classes are 0 with these assumptions, so the projection can't change yet."
        }
        if item.willFallBelowTarget {
            let recovery = max(1, item.recoveryNeeded)
            return "May fall below your \(target)% target. Attend \(recovery) consecutive class\(recovery == 1 ? "" : "es") to stay above \(target)%."
        }
        switch item.riskLevel {
        case .stable:
            let bunks = item.bunkAllowedAfterProjection
            if bunks > 0 {
                return "You're projected at \(String(format: "%.0f", item.forecastedPercentage))%. You can safely \(studentMarket.skipVerb) \(bunks) more class\(bunks == 1 ? "" : "es")."
            }
            return "No change expected — you're set to stay above \(target)%."
        case .warning:
            return "Still above \(target)% for now, but your buffer is thin — avoid extra \(studentMarket.skipNounPlural)."
        case .critical:
            return "Projected below your \(target)% target."
        }
    }

    private var allSubjectsDashboardCard: some View {
        let summary = subjectStore.dashboardSummary

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("All \(studentMarket.courseNounPluralTitle)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Menu {
                    Button {
                        triggerLightHaptic()
                        exportAttendancePDF()
                    } label: {
                        Label("PDF report", systemImage: entitlements.isPro ? "doc.richtext" : "lock.fill")
                    }
                    Button {
                        triggerLightHaptic()
                        exportAttendanceCSV()
                    } label: {
                        Label("CSV log", systemImage: entitlements.isPro ? "tablecells" : "lock.fill")
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isExportingPDF {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: entitlements.isPro ? "square.and.arrow.up" : "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text("Export")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                }
                .disabled(isExportingPDF || subjectStore.subjects.isEmpty)
                .opacity(subjectStore.subjects.isEmpty ? 0.45 : 1)
            }

            HStack(spacing: 10) {
                trendChip(title: studentMarket.courseNounPluralTitle, value: "\(summary.totalSubjects)")
                trendChip(title: "At Risk", value: "\(summary.riskSubjects)")
                trendChip(title: "Safe", value: "\(summary.safeSubjects)")
            }

            if subjectStore.subjects.isEmpty {
                Text("Add a \(studentMarket.courseNoun) to see your dashboard.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                ForEach(subjectStore.subjects) { subject in
                    Button {
                        triggerLightHaptic()
                        subjectStore.selectSubject(subject)
                        selectedTab = .home
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subject.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(subject.totalClasses > 0
                                      ? "\(String(format: "%.0f%%", subject.currentPercentage))"
                                      : "No classes yet")
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        subject.status == .safe
                                            ? Color(red: 0.2, green: 0.9, blue: 0.5)
                                            : Color(red: 1.0, green: 0.45, blue: 0.4)
                                    )
                                let left = subjectStore.classesLeftThisSemester(
                                    for: subject,
                                    weeks: forecastWeeks,
                                    holidayClassCount: forecastHolidayClasses,
                                    plannedBunks: forecastExpectedAbsences,
                                    fallbackClassesPerWeek: forecastClassesPerWeek
                                )
                                Text(left == 1 ? "1 class left" : "\(left) classes left")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Text(subject.actionChipLabel)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            subject.status == .safe
                                                ? Color(red: 0.2, green: 0.9, blue: 0.5)
                                                : Color(red: 1.0, green: 0.78, blue: 0.28)
                                        )
                                )
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            AnalyticsService.shared.log(.dashboardViewed)
        }
    }

    private var facultyDashboardCard: some View {
        allSubjectsDashboardCard
    }

    private func progressCard(for result: AttendanceResult) -> some View {
        let progress = min(max(result.currentPercentage / 100, 0), 1)
        let ringColor = result.status == .safe ? Color(red: 0.15, green: 0.85, blue: 0.5) : Color(red: 1.0, green: 0.3, blue: 0.3)

        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.3), radius: 5, x: 0, y: 0)
                
                Text("\(Int(result.currentPercentage.rounded()))%")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 90, height: 90)

            Text("CURRENT\nSTANDING")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .tracking(1.0)
        }
        .frame(maxWidth: 130)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        )
    }

    private func progressBar(for result: AttendanceResult, color: Color) -> some View {
        let progress = clampedRatio(result.currentPercentage)

        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.4))

                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: max(0.03, progress), y: 1, anchor: .leading)

            }
            .frame(height: 12)

            HStack(spacing: 8) {
                Text("CURRENT: \(Int(result.currentPercentage.rounded()))%")
                Spacer()
                Text("TARGET: \(Int(viewModel.requiredPercentage))%")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.top, 4)

            Text(gapLabel(for: result))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var displayResult: AttendanceResult? {
        let weekClasses = max(1, subjectStore.subjects.first(where: { $0.id == subjectStore.selectedSubjectID })?.weeklySchedule.totalPerWeek ?? 5)
        switch selectedScenario {
        case .current:
            return viewModel.result
        case .skipTomorrow:
            return viewModel.simulatedResult(skipMore: 1)
        case .skipThisWeek:
            return viewModel.simulatedResult(skipMore: weekClasses)
        case .attendAllWeek:
            return viewModel.simulatedResult(attendMore: weekClasses)
        case .custom:
            return viewModel.simulatedResult(attendMore: customAttendCount, skipMore: customMissCount)
        }
    }

    private func heroTitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "No classes logged yet."
        }
        if isPerfectAttendance(result: result) {
            return "You're perfect, but don't get overconfident 😄"
        }
        if isRecoveryMode(result: result) {
            return "Recovery mode activated."
        }
        if isCriticalRisk(result: result) {
            return "Attend next \(result.recoveryNeeded) classes or you're in danger ⚠️"
        }
        if result.status == .safe {
            return result.bunkAllowed > 0
                ? "You can skip \(result.bunkAllowed) classes safely."
                : "Perfectly balanced on the safe line."
        }
        return "Attend next \(result.recoveryNeeded) classes to recover."
    }

    private func heroSubtitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "Add your first class record to unlock predictions."
        }
        if isPerfectAttendance(result: result) {
            return "100% attendance streak. Great discipline."
        }
        if isRecoveryMode(result: result) {
            return "You're below 50%. Focus on attending consistently for the next few weeks."
        }
        if isCriticalRisk(result: result) {
            return "One more \(studentMarket.skipVerb) can increase the recovery burden quickly."
        }
        if result.status == .safe {
            return result.bunkAllowed <= 1
                ? "1 more \(studentMarket.skipVerb) = danger ⚠️"
                : "You're chilling 😎 Current attendance is \(String(format: "%.1f%%", result.currentPercentage))."
        }
        return "Your rate is \(String(format: "%.1f%%", result.currentPercentage)). Perfect attendance is mandatory now."
    }

    private func scenarioInsight(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> String {
        let percentageText = String(format: "%.0f%%", displayedResult.currentPercentage)

        guard selectedScenario != .current, baseResult != nil else {
            if displayedResult.status == .safe {
                return "You're at \(percentageText) — safely above target."
            }
            return "Attend next \(displayedResult.recoveryNeeded) classes to get back on track."
        }

        if displayedResult.status == .safe {
            return "After this → \(percentageText). Still safe."
        }
        return "After this → \(percentageText). Attend next \(displayedResult.recoveryNeeded) to recover."
    }

    private func actionSummary(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "Log first class"
        }
        if isRecoveryMode(result: result) {
            return "Recovery mode"
        }
        if result.status == .safe {
            return "Skip \(result.bunkAllowed) classes"
        }
        return "Attend \(result.recoveryNeeded) next"
    }

    private func planSubtitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "Start tracking"
        }
        if isRecoveryMode(result: result) {
            return "Below 50% attendance"
        }
        if result.status == .safe {
            return "Retains threshold"
        }
        return "Critical recovery"
    }

    private func formattedPercentage(_ value: Double) -> String {
        guard value.isFinite else { return "0.0%" }
        return String(format: "%.1f%%", value)
    }

    private func clampedRatio(_ percentage: Double) -> CGFloat {
        guard percentage.isFinite else { return 0 }
        return CGFloat(min(max(percentage / 100, 0), 1))
    }

    private func gapLabel(for result: AttendanceResult) -> String {
        let gap = max(0, viewModel.requiredPercentage - result.currentPercentage)
        if gap == 0 {
            return "GAP TO TARGET: 0%"
        }
        return "GAP TO TARGET: \(formattedPercentage(gap))"
    }

    private func stepperButton(
        symbol: String,
        text: Binding<String>,
        keyboardType: KeyboardType,
        delta: Double
    ) -> some View {
        Button {
            triggerLightHaptic()
            adjustInput(text: text, keyboardType: keyboardType, delta: delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func adjustInput(text: Binding<String>, keyboardType: KeyboardType, delta: Double) {
        switch keyboardType {
        case .numberPad:
            let currentValue = Int(text.wrappedValue) ?? 0
            text.wrappedValue = String(max(0, currentValue + Int(delta)))
        case .decimalPad:
            let currentValue = Double(text.wrappedValue) ?? 0
            let newValue = max(0, currentValue + delta)
            text.wrappedValue = newValue.rounded(.towardZero) == newValue
                ? String(Int(newValue))
                : String(format: "%.1f", newValue)
        }
    }

    private func attemptAddSubject(named name: String? = nil) {
        if subjectStore.addSubject(named: name) == false {
            if SoftPaywallCoordinator.shared.consumeSubjectLimitTrigger() {
                proPaywallSource = "subject_limit"
                isShowingProPaywall = true
            } else {
                isShowingSubjectLimitAlert = true
            }
        }
    }

    private func exportAttendancePDF() {
        AnalyticsService.shared.log(.pdfExportTapped)
        guard entitlements.isPro else {
            proPaywallSource = "pdf_export"
            isShowingProPaywall = true
            return
        }

        #if canImport(UIKit)
        isExportingPDF = true
        Task { @MainActor in
            defer { isExportingPDF = false }
            do {
                let url = try AttendanceReportPDF.makeFile(
                    subjects: subjectStore.subjects,
                    summary: subjectStore.dashboardSummary,
                    grades: gpaStore.makeGradesReportSnapshot(market: studentMarket)
                )
                let caption = gpaStore.courses.isEmpty
                    ? "My attendance summary from Bunk Planner."
                    : "My attendance & grades summary from Bunk Planner."
                shareItems = [url, caption]
                isShowingShareSheet = true
                AnalyticsService.shared.log(.pdfExportShared(subjectCount: subjectStore.subjects.count))
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
        #endif
    }

    private func exportAttendanceCSV() {
        AnalyticsService.shared.log(.csvExportTapped)
        guard entitlements.isPro else {
            proPaywallSource = "csv_export"
            isShowingProPaywall = true
            return
        }

        do {
            let result = try AttendanceLogCSV.makeFile(
                entries: subjectStore.allLogEntries(),
                subjects: subjectStore.subjects
            )
            shareItems = [result.url, "My attendance log from Bunk Planner."]
            isShowingShareSheet = true
            AnalyticsService.shared.log(.csvExportShared(rowCount: result.rowCount))
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func resetScenarioIfNeeded() {
        if selectedScenario != .current {
            selectedScenario = .current
        }
    }

    private func triggerLightHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func shareResult(_ result: AttendanceResult) {
        let message = shareMessage(for: result)
        #if canImport(UIKit)
        if let image = generateShareImage(result: result, message: message) {
            shareItems = [image, message]
        } else {
            shareItems = [message]
        }
        #else
        shareItems = [message]
        #endif
        isShowingShareSheet = true
        AnalyticsService.shared.log(.resultShared(status: result.status == .safe ? "safe" : "risk"))
    }

    private func shareStreak(days: Int) {
        let message = shareStreakMessage(days: days)
        #if canImport(UIKit)
        if let image = generateShareStreakImage(days: days, message: message) {
            shareItems = [image, message]
        } else {
            shareItems = [message]
        }
        #else
        shareItems = [message]
        #endif
        isShowingShareSheet = true
        AnalyticsService.shared.log(.streakShared(days: days))
    }

    private func shareStreakMessage(days: Int) -> String {
        let cta = "Try Bunk Planner: Attendance Track."
        if days == 1 {
            return "I'm on a 1-day attendance streak 🔥\n\(cta)"
        }
        return "I'm on a \(days)-day attendance streak 🔥\n\(cta)"
    }

    #if canImport(UIKit)
    private func generateShareStreakImage(days: Int, message: String) -> UIImage? {
        let renderer = ImageRenderer(content: shareStreakSnapshotCard(days: days, message: message))
        let screenScale = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.scale ?? 2
        renderer.scale = screenScale
        return renderer.uiImage
    }
    #endif

    private func requestAppReview() {
        AnalyticsService.shared.log(.reviewPromptShown)
        #if canImport(StoreKit) && canImport(UIKit)
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
        #endif
    }

    private func shareMessage(for result: AttendanceResult) -> String {
        let cta = "Try Bunk Planner: Attendance Track."
        let verb = studentMarket.skipVerb
        if result.status == .safe {
            if result.bunkAllowed > 0 {
                return "I can \(verb) \(result.bunkAllowed) classes safely 😎\n\(cta)"
            }
            return "I'm exactly on the safe attendance line ⚖️\n\(cta)"
        }
        return "I'm in recovery mode: need to attend \(result.recoveryNeeded) classes 💪\n\(cta)"
    }

    #if canImport(UIKit)
    private func generateShareImage(result: AttendanceResult, message: String) -> UIImage? {
        let renderer = ImageRenderer(content: shareSnapshotCard(result: result, message: message))
        let screenScale = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.scale ?? 2
        renderer.scale = screenScale
        return renderer.uiImage
    }
    #endif

    private func shareSnapshotCard(result: AttendanceResult, message: String) -> some View {
        return ZStack {
            shareBackground(for: result)

            VStack(alignment: .leading, spacing: 30) {
                shareHeader(for: result)
                shareHero(for: result)
                shareStatsGrid(for: result)
                shareFooter(message: message)
            }
            .padding(.horizontal, 68)
            .padding(.vertical, 76)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
    }

    private func shareBackground(for result: AttendanceResult) -> some View {
        shareBackground(palette: sharePalette(for: result))
    }

    private func shareBackground(palette: SharePalette) -> some View {
        ZStack {
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.glow.opacity(0.28))
                .frame(width: 520, height: 520)
                .blur(radius: 50)
                .offset(x: 260, y: -540)

            Circle()
                .fill(palette.secondaryGlow.opacity(0.2))
                .frame(width: 620, height: 620)
                .blur(radius: 70)
                .offset(x: -250, y: 480)

            RoundedRectangle(cornerRadius: 140, style: .continuous)
                .fill(.white.opacity(0.03))
                .frame(width: 820, height: 820)
                .rotationEffect(.degrees(-18))
                .offset(x: 270, y: 520)
        }
    }

    private func shareHeader(for result: AttendanceResult) -> some View {
        let palette = sharePalette(for: result)

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.72))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bunk Planner")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Attendance Track")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                Text(subjectStore.selectedSubjectName.uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent.opacity(0.95))
                    .tracking(1.8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(result.status == .safe ? "SAFE ZONE" : "ATTENDANCE ALERT")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .tracking(1.6)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.08))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(palette.accent.opacity(0.45), lineWidth: 1)
                            )
                    )

                Text(shareTimestamp)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func shareHero(for result: AttendanceResult) -> some View {
        let palette = sharePalette(for: result)

        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(shareHeadline(for: result))
                    .font(.system(size: 82, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(shareSubheadline(for: result))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .bottom, spacing: 16) {
                Text("\(result.currentPercentage, specifier: "%.1f")%")
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text("current")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.bottom, 24)
            }

            VStack(alignment: .leading, spacing: 14) {
                shareProgressLabel(title: "Target", value: String(format: "%.0f%%", viewModel.requiredPercentage))
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.08))
                            .frame(height: 18)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.secondaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * min(max(result.currentPercentage / 100, 0), 1),
                                height: 18
                            )
                    }
                }
                .frame(height: 18)
            }
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func shareStatsGrid(for result: AttendanceResult) -> some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                shareStatCard(
                    title: "Next Move",
                    value: sharePrimaryAction(for: result),
                    detail: sharePrimaryActionDetail(for: result),
                    tint: sharePalette(for: result).accent
                )
                shareStatCard(
                    title: "Attended",
                    value: "\(viewModel.attendedClasses)/\(viewModel.totalClasses)",
                    detail: "classes locked in",
                    tint: Color(red: 0.34, green: 0.77, blue: 1.0)
                )
            }

            HStack(spacing: 18) {
                shareStatCard(
                    title: "Margin",
                    value: shareMarginText(for: result),
                    detail: "vs required threshold",
                    tint: result.status == .safe ? Color(red: 0.35, green: 0.9, blue: 0.58) : Color(red: 1.0, green: 0.56, blue: 0.32)
                )
                shareStatCard(
                    title: "Status",
                    value: result.status == .safe ? "On Track" : "Needs Focus",
                    detail: result.status == .safe ? "story-ready flex" : "bounce-back phase",
                    tint: sharePalette(for: result).secondaryAccent
                )
            }
        }
    }

    private func shareFooter(message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(message)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Track. Predict. Share.")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)

                Spacer()

                Text("@ Bunk Planner")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func shareStatCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)

            Text(value)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func shareProgressLabel(title: String, value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.3)

            Spacer()

            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func shareHeadline(for result: AttendanceResult) -> String {
        if result.status == .safe {
            if result.bunkAllowed > 0 {
                return "I can \(studentMarket.skipVerb) \(result.bunkAllowed) class\(result.bunkAllowed == 1 ? "" : "es") and still stay safe."
            }
            return "I'm exactly on the attendance safe line."
        }

        return "I need \(result.recoveryNeeded) solid class\(result.recoveryNeeded == 1 ? "" : "es") to bounce back."
    }

    private func shareSubheadline(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return "Threshold cleared. This one is social-post worthy."
        }

        return "No more random \(studentMarket.skipNounPlural). Recovery starts with the very next lecture."
    }

    private func sharePrimaryAction(for result: AttendanceResult) -> String {
        if result.status == .safe {
            let noun = result.bunkAllowed == 1 ? studentMarket.skipVerb : studentMarket.skipNounPlural
            return result.bunkAllowed > 0 ? "\(result.bunkAllowed) safe \(noun)" : "Hold steady"
        }

        return "\(result.recoveryNeeded) classes"
    }

    private func sharePrimaryActionDetail(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return result.bunkAllowed > 0 ? "before crossing the line" : "one \(studentMarket.skipVerb) changes the story"
        }

        return "needed in a row to recover"
    }

    private func shareMarginText(for result: AttendanceResult) -> String {
        let margin = result.currentPercentage - viewModel.requiredPercentage
        if abs(margin) < 0.05 {
            return "0.0%"
        }
        return String(format: "%@%.1f%%", margin > 0 ? "+" : "", margin)
    }

    private var shareTimestamp: String {
        Self.shareDateFormatter.string(from: Date())
    }

    private func sharePalette(for result: AttendanceResult) -> SharePalette {
        if result.status == .safe {
            return SharePalette(
                background: [
                    Color(red: 0.04, green: 0.08, blue: 0.14),
                    Color(red: 0.04, green: 0.15, blue: 0.20),
                    Color(red: 0.07, green: 0.08, blue: 0.14)
                ],
                accent: Color(red: 0.42, green: 0.98, blue: 0.78),
                secondaryAccent: Color(red: 0.29, green: 0.76, blue: 1.0),
                glow: Color(red: 0.26, green: 0.96, blue: 0.78),
                secondaryGlow: Color(red: 0.22, green: 0.71, blue: 1.0)
            )
        }

        return SharePalette(
            background: [
                Color(red: 0.12, green: 0.04, blue: 0.08),
                Color(red: 0.19, green: 0.06, blue: 0.11),
                Color(red: 0.09, green: 0.05, blue: 0.16)
            ],
            accent: Color(red: 1.0, green: 0.54, blue: 0.36),
            secondaryAccent: Color(red: 1.0, green: 0.32, blue: 0.52),
            glow: Color(red: 1.0, green: 0.38, blue: 0.44),
            secondaryGlow: Color(red: 0.95, green: 0.35, blue: 0.76)
        )
    }

    private static let shareDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM • h:mm a"
        return formatter
    }()

    private func shareStreakSnapshotCard(days: Int, message: String) -> some View {
        let palette = shareStreakPalette
        return ZStack {
            shareBackground(palette: palette)

            VStack(alignment: .leading, spacing: 30) {
                shareStreakHeader(days: days, palette: palette)
                shareStreakHero(days: days, palette: palette)
                shareStreakStatsGrid(days: days, palette: palette)
                shareFooter(message: message)
            }
            .padding(.horizontal, 68)
            .padding(.vertical, 76)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
    }

    private func shareStreakHeader(days: Int, palette: SharePalette) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.72))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bunk Planner")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Attendance Track")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                Text(subjectStore.selectedSubjectName.uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent.opacity(0.95))
                    .tracking(1.8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(days >= 7 ? "CONSISTENCY HERO" : "STREAK")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .tracking(1.6)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.08))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(palette.accent.opacity(0.45), lineWidth: 1)
                            )
                    )

                Text(shareTimestamp)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func shareStreakHero(days: Int, palette: SharePalette) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(days == 1 ? "I'm on a 1-day streak." : "I'm on a \(days)-day streak.")
                    .font(.system(size: 82, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Logged attendance every day. No missed marks.")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .bottom, spacing: 16) {
                Text("\(days)")
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text("days")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.bottom, 24)
            }
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func shareStreakStatsGrid(days: Int, palette: SharePalette) -> some View {
        let percentText: String
        let statusTitle: String
        let statusDetail: String
        if viewModel.totalClasses > 0, let result = viewModel.result {
            percentText = String(format: "%.1f%%", result.currentPercentage)
            statusTitle = result.status == .safe ? "On Track" : "Needs Focus"
            statusDetail = result.status == .safe ? "safe to keep going" : "protect the streak"
        } else {
            percentText = "—"
            statusTitle = "—"
            statusDetail = "log today to see status"
        }
        return VStack(spacing: 18) {
            HStack(spacing: 18) {
                shareStatCard(
                    title: "Current",
                    value: percentText,
                    detail: "attendance right now",
                    tint: palette.accent
                )
                shareStatCard(
                    title: "Logged",
                    value: "\(viewModel.attendedClasses)/\(viewModel.totalClasses)",
                    detail: "classes locked in",
                    tint: Color(red: 0.34, green: 0.77, blue: 1.0)
                )
            }

            HStack(spacing: 18) {
                shareStatCard(
                    title: "Badge",
                    value: days >= 7 ? "Hero" : "Building",
                    detail: days >= 7 ? "7+ day consistency" : "keep logging daily",
                    tint: Color(red: 1.0, green: 0.78, blue: 0.28)
                )
                shareStatCard(
                    title: "Status",
                    value: statusTitle,
                    detail: statusDetail,
                    tint: palette.secondaryAccent
                )
            }
        }
    }

    private var shareStreakPalette: SharePalette {
        SharePalette(
            background: [
                Color(red: 0.12, green: 0.06, blue: 0.02),
                Color(red: 0.22, green: 0.09, blue: 0.03),
                Color(red: 0.08, green: 0.04, blue: 0.10)
            ],
            accent: Color(red: 1.0, green: 0.72, blue: 0.28),
            secondaryAccent: Color(red: 1.0, green: 0.45, blue: 0.22),
            glow: Color(red: 1.0, green: 0.62, blue: 0.18),
            secondaryGlow: Color(red: 1.0, green: 0.38, blue: 0.28)
        )
    }

    private var weeklySummaryCard: some View {
        let summary = subjectStore.weeklyAttendanceSummary()
        let deltaText = summary.percentageDelta >= 0
            ? "+\(String(format: "%.0f", summary.percentageDelta))%"
            : "\(String(format: "%.0f", summary.percentageDelta))%"

        return VStack(alignment: .leading, spacing: 14) {
            Text("This Week")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                insightStat(title: "Attended", value: "\(summary.attendedClasses)")
                insightStat(title: studentMarket.skipNounPluralTitle, value: "\(summary.missedClasses)")
                insightStat(title: "Attendance", value: deltaText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var skipPlannerWeekCard: some View {
        SkipPlannerWeekCard(
            subjects: subjectStore.subjects,
            isPro: entitlements.isPro,
            onUnlock: {
                AnalyticsService.shared.log(.skipPlannerLocked)
                AnalyticsService.shared.log(.proCtaTapped(surface: "skip_planner", action: "go_pro"))
                proPaywallSource = "skip_planner"
                isShowingProPaywall = true
            },
            onSelectDay: { day in
                skipPlannerDay = day
            }
        )
    }

    private var streakAndHighlightsCard: some View {
        let streak = subjectStore.attendanceStreakDays()
        let best = subjectStore.bestSubject
        let worst = subjectStore.worstSubject

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Streak")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if streak > 0 {
                    Button {
                        triggerLightHaptic()
                        shareStreak(days: streak)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Share \(streak)-day streak")
                }
            }

            HStack(spacing: 10) {
                insightStat(title: "Logged", value: "\(streak) days")
                if let best {
                    insightStat(title: "Top Performer", value: "\(best.name)\n\(String(format: "%.0f%%", best.currentPercentage))")
                }
            }

            if let worst, worst.id != best?.id {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Needs Attention")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("\(worst.name) · \(String(format: "%.0f%%", worst.currentPercentage))")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.4))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .onAppear {
            if streak > 0 {
                AnalyticsService.shared.log(.streakUpdated(days: streak))
            }
        }
    }

    private var gamificationBadgesCard: some View {
        let summary = subjectStore.weeklyAttendanceSummary()
        let streak = subjectStore.attendanceStreakDays()
        let xp = min(999, streak * 25 + summary.attendedClasses * 10 + subjectStore.subjects.filter { $0.status == .safe }.count * 40)

        let badges: [(title: String, subtitle: String, earned: Bool)] = [
            ("Perfect Week", "No \(studentMarket.skipVerb) this week", summary.missedClasses == 0 && summary.attendedClasses > 0),
            ("Recovery Master", "Recovered from below target", subjectStore.subjects.contains { $0.currentPercentage >= $0.requiredPercentage && $0.totalClasses > 0 }),
            ("Consistency Hero", "Logged attendance 7+ days", streak >= 7)
        ]

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Attendance Score")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(xp) XP")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.28))
            }

            ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                HStack(spacing: 12) {
                    Image(systemName: badge.earned ? "seal.fill" : "seal")
                        .foregroundStyle(badge.earned ? Color(red: 1.0, green: 0.78, blue: 0.28) : .white.opacity(0.35))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(badge.earned ? 1 : 0.55))
                        Text(badge.subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func insightStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private var trendGraphCard: some View {
        let points = trendPointsForSelectedSubject()
        let latest = points.last?.percentage ?? 0
        let minValue = points.map(\.percentage).min() ?? 0
        let maxValue = points.map(\.percentage).max() ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ATTENDANCE TREND")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .tracking(1.1)
                Spacer()
                Text("\(points.count) pts")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if points.count < 2 {
                Text("Trend graph unlocks after at least 2 updates for this subject.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                AttendanceTrendSparkline(points: points)
                    .frame(height: 90)

                HStack(spacing: 10) {
                    trendChip(title: "Latest", value: "\(String(format: "%.1f", latest))%")
                    trendChip(title: "Min", value: "\(String(format: "%.1f", minValue))%")
                    trendChip(title: "Max", value: "\(String(format: "%.1f", maxValue))%")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            if points.count >= 2 {
                AnalyticsService.shared.log(.trendViewed)
            }
        }
    }

    private func openTimetableEditor(for subjectID: UUID) {
        triggerLightHaptic()
        AnalyticsService.shared.log(.timetableEditorOpened)
        editingTimetableSubjectID = subjectID
    }

    private func trendPointsForSelectedSubject() -> [AttendanceTrendPoint] {
        guard let subjectID = subjectStore.selectedSubjectID else { return [] }
        return AttendanceTrendStore.load(subjectID: subjectID)
    }

    private func trendChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var nextClassImpactCard: some View {
        let attendImpact = viewModel.simulatedResult(attendMore: 1)
        let skipImpact = viewModel.simulatedResult(skipMore: 1)

        return VStack(alignment: .leading, spacing: 10) {
            Text("NEXT CLASS IMPACT")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            if viewModel.totalClasses == 0 {
                Text("No class history yet. Add classes to see tomorrow impact.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                if let skipImpact {
                    Text("If you skip tomorrow → \(String(format: "%.1f%%", skipImpact.currentPercentage))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                if let attendImpact {
                    Text("If you attend tomorrow → \(String(format: "%.1f%%", attendImpact.currentPercentage))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func calculationBreakdownCard(for result: AttendanceResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $isBreakdownExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current: \(viewModel.attendedClasses) / \(viewModel.totalClasses) = \(String(format: "%.2f%%", result.currentPercentage))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    if let simulated = simulatedScenarioCounts(), let simulatedResult = displayResult {
                        Text("After \(simulated.label):")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        Text("\(simulated.attended) / \(simulated.total) = \(String(format: "%.2f%%", simulatedResult.currentPercentage))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Calculation breakdown")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func simulatedScenarioCounts() -> (attended: Int, total: Int, label: String)? {
        let weekClasses = max(1, subjectStore.subjects.first(where: { $0.id == subjectStore.selectedSubjectID })?.weeklySchedule.totalPerWeek ?? 5)
        switch selectedScenario {
        case .current:
            return nil
        case .skipTomorrow:
            return (viewModel.attendedClasses, viewModel.totalClasses + 1, "skipping tomorrow")
        case .skipThisWeek:
            return (viewModel.attendedClasses, viewModel.totalClasses + weekClasses, "skipping this week")
        case .attendAllWeek:
            return (viewModel.attendedClasses + weekClasses, viewModel.totalClasses + weekClasses, "attending all week")
        case .custom:
            return (
                viewModel.attendedClasses + customAttendCount,
                viewModel.totalClasses + customAttendCount + customMissCount,
                "custom what-if"
            )
        }
    }

    private func isPerfectAttendance(result: AttendanceResult) -> Bool {
        viewModel.totalClasses > 0 && viewModel.attendedClasses == viewModel.totalClasses && result.currentPercentage >= 99.9
    }

    private func isRecoveryMode(result: AttendanceResult) -> Bool {
        viewModel.totalClasses > 0 && result.currentPercentage < 50
    }

    private func isCriticalRisk(result: AttendanceResult) -> Bool {
        result.status == .risk && result.recoveryNeeded >= 5
    }

    private func statusTitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "STATUS: READY"
        }
        if isPerfectAttendance(result: result) {
            return "STATUS: PERFECT"
        }
        if isRecoveryMode(result: result) {
            return "STATUS: RECOVERY MODE"
        }
        if result.status == .safe {
            return "STATUS: SAFE"
        }
        return isCriticalRisk(result: result) ? "STATUS: CRITICAL" : "STATUS: RISK"
    }

    private func statusIconName(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "sparkles"
        }
        if isPerfectAttendance(result: result) {
            return "star.circle.fill"
        }
        if isRecoveryMode(result: result) {
            return "bolt.heart.fill"
        }
        if result.status == .safe {
            return "shield.checkerboard"
        }
        return isCriticalRisk(result: result) ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private func floatingActionBanner(for result: AttendanceResult?) -> some View {
        let copy = contextualFABCopy(for: result)
        return Button {
            triggerLightHaptic()
            handleFloatingBannerAction(copy: copy, result: result)
        } label: {
            ResultCardView(
                title: copy.title,
                value: copy.value,
                subtitle: copy.subtitle,
                tint: copy.tint,
                alignment: .center,
                isEmphasized: true
            )
            .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .onAppear {
            AnalyticsService.shared.log(.fabBannerShown(action: copy.analytics))
        }
    }

    private func handleFloatingBannerAction(copy: (title: String, value: String, subtitle: String, tint: Color, analytics: String), result: AttendanceResult?) {
        AnalyticsService.shared.log(.fabBannerShown(action: "\(copy.analytics)_tap"))
        switch copy.analytics {
        case "log_morning", "log_evening", "log_today":
            selectedTab = .home
            highlightMarkToday = true
        case "start_recovery", "skip_plan":
            skipPlannerDay = Calendar.current.startOfDay(for: Date())
            AnalyticsService.shared.log(.skipPlannerViewed(dayCount: subjectStore.subjectsForMarkToday(on: Date()).count))
        case "create_subject":
            isShowingSubjects = true
        case "maintain_streak":
            selectedTab = .insights
        default:
            if result?.status == .risk {
                skipPlannerDay = Calendar.current.startOfDay(for: Date())
                AnalyticsService.shared.log(.skipPlannerViewed(dayCount: subjectStore.subjectsForMarkToday(on: Date()).count))
            } else {
                selectedTab = .home
                highlightMarkToday = true
            }
        }
    }

    private func contextualFABCopy(for result: AttendanceResult?) -> (title: String, value: String, subtitle: String, tint: Color, analytics: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        let loggedToday = subjectStore.hasLoggedToday()
        let green = Color(red: 0.2, green: 0.9, blue: 0.5)
        let red = Color(red: 1.0, green: 0.3, blue: 0.3)
        let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)

        if !hasAttendanceData {
            return ("Before semester", "Create your first subject", "Get Started", cyan, "create_subject")
        }
        if !loggedToday {
            let pending = subjectStore.subjectsForMarkToday().count
            if hour < 12 {
                return (
                    "Morning",
                    pending > 1 ? "Log all \(pending) subjects" : "Log Today's Attendance",
                    "Mark every subject in one place",
                    cyan,
                    "log_morning"
                )
            }
            if hour >= 17 {
                return (
                    "Evening",
                    pending > 1 ? "Don't forget \(pending) subjects" : "Don't forget today's class",
                    "Log before you sleep",
                    .orange,
                    "log_evening"
                )
            }
            return (
                "Today",
                pending > 1 ? "Log all \(pending) subjects" : "Log Today's Attendance",
                "Keep your streak alive",
                cyan,
                "log_today"
            )
        }
        guard let result else {
            return ("Today", "Log Today's Attendance", "Keep tracking", cyan, "log_today")
        }
        if isPerfectAttendance(result: result) {
            return ("Perfect attendance", "Maintain your streak", "You're crushing it", green, "maintain_streak")
        }
        if isRecoveryMode(result: result) || result.status == .risk {
            return ("Recovery mode", "Start Recovery", "Attend next \(max(1, result.recoveryNeeded))", red, "start_recovery")
        }
        return ("Best next move", "Skip \(result.bunkAllowed) safely", "You're above target", green, "skip_plan")
    }

    private func colorForRiskLevel(_ level: RiskAlertLevel) -> Color {
        switch level {
        case .stable:
            return Color(red: 0.2, green: 0.9, blue: 0.5)
        case .warning:
            return Color(red: 1.0, green: 0.84, blue: 0.2)
        case .critical:
            return Color(red: 1.0, green: 0.35, blue: 0.4)
        }
    }
}

private struct AttendanceTrendSparkline: View {
    let points: [AttendanceTrendPoint]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minimum = points.map(\.percentage).min() ?? 0
            let maximum = points.map(\.percentage).max() ?? 100
            let range = max(maximum - minimum, 0.1)
            let stepX = points.count > 1 ? width / CGFloat(points.count - 1) : width

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.2))

                Path { path in
                    guard points.isEmpty == false else { return }
                    for index in points.indices {
                        let point = points[index]
                        let x = CGFloat(index) * stepX
                        let yRatio = (point.percentage - minimum) / range
                        let y = height - (CGFloat(yRatio) * height)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.84, blue: 0.95), Color(red: 0.22, green: 0.95, blue: 0.58)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                if let last = points.last {
                    let x = CGFloat(points.count - 1) * stepX
                    let yRatio = (last.percentage - minimum) / range
                    let y = height - (CGFloat(yRatio) * height)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle().stroke(Color(red: 0.22, green: 0.95, blue: 0.58), lineWidth: 2)
                        )
                        .position(x: x, y: y)
                }
            }
        }
    }
}

private struct SharePalette {
    let background: [Color]
    let accent: Color
    let secondaryAccent: Color
    let glow: Color
    let secondaryGlow: Color
}

#Preview {
    ContentView()
}

enum KeyboardType {
    case numberPad
    case decimalPad
}

private enum HomeTab: CaseIterable {
    case home
    case insights
    case log
    case overview
    case tools

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .insights:
            return "chart.line.uptrend.xyaxis"
        case .log:
            return "calendar"
        case .overview:
            return "books.vertical.fill"
        case .tools:
            return "square.grid.2x2.fill"
        }
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .insights:
            return "Insights"
        case .log:
            return "Log"
        case .overview:
            return "Overview"
        case .tools:
            return "Tools"
        }
    }

    var analyticsScreen: AppScreen {
        switch self {
        case .home: return .home
        case .insights: return .insights
        case .log: return .log
        case .overview: return .overview
        case .tools: return .tools
        }
    }
}

private enum ScenarioAction: CaseIterable, Identifiable {
    case current
    case skipTomorrow
    case skipThisWeek
    case attendAllWeek
    case custom

    var id: Self { self }

    var label: String {
        switch self {
        case .current:
            return "Current"
        case .skipTomorrow:
            return "Skip Tomorrow"
        case .skipThisWeek:
            return "Skip This Week"
        case .attendAllWeek:
            return "Attend All Week"
        case .custom:
            return "Custom"
        }
    }

    var description: String {
        switch self {
        case .current:
            return "current"
        case .skipTomorrow:
            return "skip_tomorrow"
        case .skipThisWeek:
            return "skip_this_week"
        case .attendAllWeek:
            return "attend_all_week"
        case .custom:
            return "custom"
        }
    }
}

private extension View {
    @ViewBuilder
    func applyKeyboardType(_ keyboardType: KeyboardType) -> some View {
        #if canImport(UIKit)
        switch keyboardType {
        case .numberPad:
            self.keyboardType(.numberPad)
        case .decimalPad:
            self.keyboardType(.decimalPad)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyImpactFeedback<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.impact, trigger: trigger)
        } else {
            self
        }
    }
}

/// Sheets / alerts extracted so `HomeView.body` type-checks in reasonable time.
private struct HomePresentationModifier: ViewModifier {
    let selectedTab: HomeTab
    let subjectStore: SubjectStore
    let viewModel: AttendanceViewModel
    let entitlements: AdEntitlementsStore
    let shareItems: [Any]

    @Binding var isShowingShareSheet: Bool
    @Binding var isShowingSettings: Bool
    @Binding var isShowingSubjects: Bool
    @Binding var isShowingSubjectPicker: Bool
    @Binding var editingTimetableSubjectID: UUID?
    @Binding var isShowingSubjectLimitAlert: Bool
    @Binding var exportErrorMessage: String?
    @Binding var isShowingProPaywall: Bool
    @Binding var proPaywallSource: String
    @Binding var studentMarket: StudentMarket

    func body(content: Content) -> some View {
        content
            .onAppear {
                AnalyticsService.shared.setScreen(selectedTab.analyticsScreen)
                AnalyticsUserProfile.sync(subjectStore: subjectStore)
            }
            .onChange(of: selectedTab) { _, newTab in
                AnalyticsService.shared.setScreen(newTab.analyticsScreen)
                switch newTab {
                case .insights:
                    AdMobInterstitialService.shared.tryShowAfterInsightsOpened()
                case .overview:
                    AdMobInterstitialService.shared.tryShowAfterOverviewOpened()
                case .home, .log, .tools:
                    break
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ActivityView(activityItems: shareItems)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsSheetView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
                    .analyticsScreen(.settings)
            }
            .onChange(of: isShowingSettings) { _, isShowing in
                if isShowing == false {
                    studentMarket = StudentMarketStore.current
                    subjectStore.rescheduleHabitReminders()
                }
            }
            .sheet(isPresented: $isShowingSubjects) {
                SubjectListView(subjectStore: subjectStore)
                    .preferredColorScheme(.dark)
                    .analyticsScreen(.subjects)
            }
            .onChange(of: isShowingSubjects) { _, isShowing in
                if isShowing {
                    AdMobInterstitialService.shared.tryShowAfterSubjectsOpened()
                }
            }
            .sheet(isPresented: $isShowingSubjectPicker) {
                SubjectPickerSheet(subjectStore: subjectStore) {
                    isShowingSubjects = true
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: timetableEditorPresented) {
                if let subjectID = editingTimetableSubjectID {
                    TimetableEditorSheet(subjectStore: subjectStore, subjectID: subjectID)
                        .preferredColorScheme(.dark)
                        .analyticsScreen(.timetableEditor)
                }
            }
            .alert("Subject limit reached", isPresented: $isShowingSubjectLimitAlert) {
                Button("Not now", role: .cancel) {
                    AnalyticsService.shared.log(
                        .proCtaTapped(surface: "subject_limit_alert", action: "not_now")
                    )
                }
                Button("Go Pro") {
                    AnalyticsService.shared.log(
                        .proCtaTapped(surface: "subject_limit_alert", action: "go_pro")
                    )
                    proPaywallSource = "subject_limit"
                    isShowingProPaywall = true
                }
            } message: {
                Text("Free includes \(ProPurchaseConfiguration.freeSubjectLimit) subjects. Go Pro for unlimited.")
            }
            .onChange(of: isShowingSubjectLimitAlert) { _, isShowing in
                if isShowing {
                    AnalyticsService.shared.logProCtaShownOnce(surface: "subject_limit_alert")
                }
            }
            .alert("Export", isPresented: exportAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
            }
            .sheet(isPresented: $isShowingProPaywall) {
                ProPaywallView(source: proPaywallSource)
                    .preferredColorScheme(.dark)
                    .analyticsScreen(.proPaywall)
            }
    }

    private var timetableEditorPresented: Binding<Bool> {
        Binding(
            get: { editingTimetableSubjectID != nil },
            set: { isPresented in
                if isPresented == false {
                    editingTimetableSubjectID = nil
                }
            }
        )
    }

    private var exportAlertPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    exportErrorMessage = nil
                }
            }
        )
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed == false {
                AnalyticsService.shared.log(.shareCancelled)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct SubjectPickerSheet: View {
    @ObservedObject var subjectStore: SubjectStore
    var onManageSubjects: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var isShowingSubjectLimitAlert = false
    @State private var isShowingProPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(subjectStore.subjects) { subject in
                        Button {
                            subjectStore.selectSubject(subject)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(subject.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text(subject.totalClasses > 0
                                          ? "\(String(format: "%.0f%%", subject.currentPercentage))"
                                          : "No classes yet")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if subject.id == subjectStore.selectedSubjectID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.5))
                                }
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("New subject name", text: $newName)
                        Button("Add") {
                            let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if subjectStore.addSubject(named: name.isEmpty ? nil : name) {
                                newName = ""
                            } else if SoftPaywallCoordinator.shared.consumeSubjectLimitTrigger() {
                                isShowingProPaywall = true
                            } else {
                                isShowingSubjectLimitAlert = true
                            }
                        }
                        .disabled(false)
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onManageSubjects()
                        }
                    } label: {
                        Label("Manage subjects & timetables", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .navigationTitle("Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Subject limit reached", isPresented: $isShowingSubjectLimitAlert) {
                Button("Not now", role: .cancel) {
                    AnalyticsService.shared.log(
                        .proCtaTapped(surface: "subject_limit_alert", action: "not_now")
                    )
                }
                Button("Go Pro") {
                    AnalyticsService.shared.log(
                        .proCtaTapped(surface: "subject_limit_alert", action: "go_pro")
                    )
                    isShowingProPaywall = true
                }
            } message: {
                Text("Free includes \(ProPurchaseConfiguration.freeSubjectLimit) subjects. Go Pro for unlimited.")
            }
            .onChange(of: isShowingSubjectLimitAlert) { _, isShowing in
                if isShowing {
                    AnalyticsService.shared.logProCtaShownOnce(surface: "subject_limit_alert")
                }
            }
            .sheet(isPresented: $isShowingProPaywall) {
                ProPaywallView(source: "subject_limit")
                    .preferredColorScheme(.dark)
            }
        }
    }
}

private struct SubjectListView: View {
    @ObservedObject var subjectStore: SubjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAddPrompt = false
    @State private var newSubjectName = ""
    @State private var isShowingRenamePrompt = false
    @State private var renameSubjectName = ""
    @State private var renamingSubjectID: UUID?
    @State private var editingTimetableSubjectID: UUID?
    @State private var isShowingSubjectLimitAlert = false
    @State private var isShowingProPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Subjects") {
                    ForEach(subjectStore.subjects) { subject in
                        Button {
                            subjectStore.selectSubject(subject)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(subject.name)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Target \(Int(subject.requiredPercentage))%")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                Spacer()

                                Text("\(Int(subject.currentPercentage.rounded()))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(subject.status == .safe ? Color.green : Color.red)

                                if subject.id == subjectStore.selectedSubjectID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Timetable") {
                                editingTimetableSubjectID = subject.id
                            }
                            .tint(.purple)

                            Button("Rename") {
                                renamingSubjectID = subject.id
                                renameSubjectName = subject.name
                                isShowingRenamePrompt = true
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                subjectStore.deleteSubject(id: subject.id)
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                    .onDelete(perform: subjectStore.deleteSubjects)
                }

            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.05, green: 0.06, blue: 0.1))
            .navigationTitle("Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newSubjectName = ""
                        isShowingAddPrompt = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .alert("New Subject", isPresented: $isShowingAddPrompt) {
                TextField("e.g. Math", text: $newSubjectName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    if subjectStore.addSubject(named: newSubjectName) == false {
                        if SoftPaywallCoordinator.shared.consumeSubjectLimitTrigger() {
                            isShowingProPaywall = true
                        } else {
                            isShowingSubjectLimitAlert = true
                        }
                    }
                }
            } message: {
                Text("Type a subject name or leave blank to auto-name.")
            }
            .alert("Rename Subject", isPresented: $isShowingRenamePrompt) {
                TextField("Subject name", text: $renameSubjectName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let subjectID = renamingSubjectID {
                        subjectStore.renameSubject(id: subjectID, to: renameSubjectName)
                    }
                }
            } message: {
                Text("Update the subject name.")
            }
            .alert("Subject limit reached", isPresented: $isShowingSubjectLimitAlert) {
                Button("Not now", role: .cancel) {
                    AnalyticsService.shared.log(
                        .proCtaTapped(surface: "subject_limit_alert", action: "not_now")
                    )
                }
                Button("Go Pro") {
                    AnalyticsService.shared.log(
                        .proCtaTapped(surface: "subject_limit_alert", action: "go_pro")
                    )
                    isShowingProPaywall = true
                }
            } message: {
                Text("Free includes \(ProPurchaseConfiguration.freeSubjectLimit) subjects. Go Pro for unlimited.")
            }
            .onChange(of: isShowingSubjectLimitAlert) { _, isShowing in
                if isShowing {
                    AnalyticsService.shared.logProCtaShownOnce(surface: "subject_limit_alert")
                }
            }
            .sheet(isPresented: $isShowingProPaywall) {
                ProPaywallView(source: "subject_limit")
                    .preferredColorScheme(.dark)
            }
            .sheet(
                isPresented: Binding(
                    get: { editingTimetableSubjectID != nil },
                    set: { isPresented in
                        if isPresented == false {
                            editingTimetableSubjectID = nil
                        }
                    }
                )
            ) {
                if let subjectID = editingTimetableSubjectID {
                    TimetableEditorSheet(
                        subjectStore: subjectStore,
                        subjectID: subjectID
                    )
                    .preferredColorScheme(.dark)
                    .analyticsScreen(.timetableEditor)
                }
            }
        }
    }
}

private struct TimetableEditorSheet: View {
    @ObservedObject var subjectStore: SubjectStore
    let subjectID: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var schedule: WeeklySchedule = .empty
    @State private var projectionWeeks = 1
    @State private var holidayClassCount = 0
    @State private var expectedAbsences = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Weekly Classes") {
                    dayStepper("Monday", value: $schedule.monday)
                    dayStepper("Tuesday", value: $schedule.tuesday)
                    dayStepper("Wednesday", value: $schedule.wednesday)
                    dayStepper("Thursday", value: $schedule.thursday)
                    dayStepper("Friday", value: $schedule.friday)
                    dayStepper("Saturday", value: $schedule.saturday)
                    dayStepper("Sunday", value: $schedule.sunday)
                }

                Section("Summary") {
                    HStack {
                        Text("Total classes / week")
                        Spacer()
                        Text("\(schedule.totalPerWeek)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }

                    Button("Set subject total classes = weekly total") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyWeeklySchedule(for: subjectID, addToExisting: false)
                    }

                    Button("Add one full week to total classes") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyWeeklySchedule(for: subjectID, addToExisting: true)
                    }
                }

                Section("Forecast Assumptions") {
                    Stepper("Semester Remaining: \(projectionWeeks) week\(projectionWeeks == 1 ? "" : "s")", value: $projectionWeeks, in: 1...16)
                    Stepper("College Holidays: \(holidayClassCount) cancelled", value: $holidayClassCount, in: 0...80)
                    Stepper("Planned \(StudentMarketStore.current.skipNounPluralTitle): \(expectedAbsences)", value: $expectedAbsences, in: 0...80)

                    let expected = CalculationService.projectedTotalClasses(
                        schedule: schedule,
                        weeks: projectionWeeks,
                        holidayClassCount: holidayClassCount
                    )
                    let expectedAttended = max(0, expected - min(expectedAbsences, expected))

                    Text("Projected classes: \(expected), projected attended: \(expectedAttended)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Button("Apply projection to existing totals") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyProjectedSchedule(
                            for: subjectID,
                            weeks: projectionWeeks,
                            holidayClassCount: holidayClassCount,
                            expectedAbsences: expectedAbsences,
                            addToExisting: true
                        )
                    }

                    Button("Replace totals with projection") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyProjectedSchedule(
                            for: subjectID,
                            weeks: projectionWeeks,
                            holidayClassCount: holidayClassCount,
                            expectedAbsences: expectedAbsences,
                            addToExisting: false
                        )
                    }
                }
            }
            .navigationTitle("Timetable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        dismiss()
                    }
                }
            }
            .onAppear {
                schedule = subjectStore.weeklySchedule(for: subjectID)
            }
        }
    }

    private func dayStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...12) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
        }
    }
}
