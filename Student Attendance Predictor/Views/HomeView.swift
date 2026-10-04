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
    @ObservedObject private var purchaseService = ProPurchaseService.shared
    @ObservedObject private var softPaywall = SoftPaywallCoordinator.shared
    @StateObject private var gpaStore = GPAStore()
    @StateObject private var deadlineStore = DeadlineStore()
    @ObservedObject private var studyTasks = StudyTaskStore.shared
    @State private var showTaskCapture = false
    @State private var showTaskList = false
    @State private var editingHomeTask: StudyTask?
    @State private var isShowingProPaywall = false
    @State private var proPaywallSource = "forecast"
    @State private var isShowingSubjectLimitAlert = false
    @State private var studentMarket = StudentMarketStore.current
    @State private var isExportingPDF = false
    @State private var exportErrorMessage: String?
    @State private var skipPlannerDay: Date?
    @State private var isShowingFineTuneEditor = false
    @State private var showPostMarkFocusPrompt = false
    @State private var didAcceptPostMarkFocus = false
    @State private var focusPromptSubject: SubjectSummary?
    @State private var showFocusTimerSheet = false
    @State private var showFirstRunSetup = false
    @State private var classDaysSubjectID: UUID?
    @State private var dismissAtRiskSharePrompt = false
    @State private var dismissStreakInvite = false
    @State private var pendingToolsDeadlines = false
    @ObservedObject private var widgetPrompt = WidgetPromptCoordinator.shared
    @ObservedObject private var guidedSetup = GuidedSetupStore.shared
    @ObservedObject private var notificationRoute = NotificationRouteStore.shared
    @ObservedObject private var reviewPromptCoordinator = AppStoreReviewPromptCoordinator.shared
    @ObservedObject private var referral = ReferralService.shared
    @State private var highlightMarkToday = false
    @State private var homeScrollToken = 0

    @State private var returnTomorrowBanner: String?

    private var hasAttendanceData: Bool {
        viewModel.totalClasses > 0
    }

    /// Paper whose Safe / At risk % should show on Today. Prefer the selected
    /// subject; if that one has no marks yet (just added), fall back so the
    /// status doesn’t vanish after marking the others.
    private var todayHeroSubject: SubjectSummary? {
        if let selected = subjectStore.selectedSubject, selected.totalClasses > 0 {
            return selected
        }
        return subjectStore.worstSubject ?? subjectStore.bestSubject
    }
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    /// Light tail padding inside tab scroll views.
    private var tabScrollBottomPadding: CGFloat { 24 }

    @ViewBuilder
    private var bottomChrome: some View {
        stickyAdBanner
    }

    private func phoneScrollWithFABInset<Content: View>(@ViewBuilder scroll: () -> Content) -> some View {
        scroll()
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
                    presentFirstRunIfNeeded()
                    presentMissingDaysIfNeeded()
                    SoftPaywallCoordinator.shared.noteHomeAppeared()
                    SoftPaywallCoordinator.shared.evaluateHabitValuePaywall(
                        daysSinceInstall: AnalyticsService.shared.daysSinceInstall,
                        hasMarkedDay: AnalyticsService.shared.hasMarkedAtLeastOnce
                    )
                }
                .onChange(of: guidedSetup.activeStep) { _, step in
                    if step == .addSubject {
                        presentFirstRunIfNeeded()
                    }
                }
                .onChange(of: subjectStore.subjects.count) { oldCount, newCount in
                    refreshGuidedSetup()
                    if newCount > oldCount, showFirstRunSetup == false, isShowingSubjects == false {
                        classDaysSubjectID = subjectStore.selectedSubjectID
                    }
                    if newCount == 0 {
                        presentFirstRunIfNeeded()
                    }
                }
                .fullScreenCover(isPresented: $showFirstRunSetup) {
                    FirstRunSetupView(subjectStore: subjectStore) {
                        showFirstRunSetup = false
                        refreshGuidedSetup()
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: { classDaysSubjectID != nil },
                        set: { if $0 == false { classDaysSubjectID = nil } }
                    )
                ) {
                    if let subjectID = classDaysSubjectID {
                        ClassDaysSheet(subjectStore: subjectStore, subjectID: subjectID) {
                            refreshGuidedSetup()
                        }
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                    }
                }
                .onChange(of: notificationRoute.pendingDestination) { _, destination in
                    consumeNotificationRoute(destination)
                }
                .onChange(of: entitlements.hasProFeatures) { _, _ in
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
                .sheet(isPresented: $referral.isShowingRedeem) {
                    RedeemInviteView()
                }
        }
    }

    /// Skip Planner is Pro. Home previously opened the full sheet for free users
    /// ("Plan skips free"), which removed the reason to pay.
    private func presentSkipPlannerOrPaywall(day: Date = Calendar.current.startOfDay(for: Date())) {
        if entitlements.hasProFeatures {
            skipPlannerDay = day
            AnalyticsService.shared.log(
                .skipPlannerViewed(dayCount: subjectStore.subjectsForMarkToday(on: day).count)
            )
        } else {
            AnalyticsService.shared.log(.skipPlannerLocked)
            AnalyticsService.shared.log(.proCtaTapped(surface: "skip_planner", action: "go_pro"))
            proPaywallSource = "skip_planner"
            isShowingProPaywall = true
        }
    }

    /// Always show the weekly Tools promo — at-risk free users need Skip Planner most.
    private var shouldShowHomePromoCard: Bool {
        subjectStore.subjects.isEmpty == false
    }

    private func consumeNotificationRoute(_ destination: NotificationRoute?) {
        guard let destination else { return }
        switch destination {
        case .home:
            selectedTab = .home
        case .markToday:
            selectedTab = .home
            focusMarkTodayFromNotification()
        case .skipPlanner:
            selectedTab = .home
            presentSkipPlannerOrPaywall()
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

    /// Scroll + pulse Mark Today so evening / day-2 / day-3 opens land on the habit, not just Home.
    private func focusMarkTodayFromNotification() {
        highlightMarkToday = true
        homeScrollToken += 1
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeOut(duration: 0.35)) {
                highlightMarkToday = false
            }
        }
    }

    private var homeRootContent: some View {
        ZStack {
            animatedBackground
            mainNavigationContent
        }
        .preferredColorScheme(.dark)
        .navigationTitle(selectedTab == .home ? "" : selectedTab.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(selectedTab == .home ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        .sheet(isPresented: $isShowingFineTuneEditor) {
            NavigationStack {
                ScrollView {
                    inputSection
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                .background(BrandColor.colorBackground.ignoresSafeArea())
                .navigationTitle("Fine-tune numbers")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isShowingFineTuneEditor = false }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        .alert("Add a Home Screen widget?", isPresented: Binding(
            get: { widgetPrompt.shouldPresent },
            set: { if $0 == false { widgetPrompt.clear() } }
        )) {
            Button("Got it", role: .cancel) { widgetPrompt.clear() }
        } message: {
            Text("Long-press your Home Screen → tap + → search Bunk Planner to see attendance and safe bunks at a glance.")
        }
        .sheet(isPresented: $reviewPromptCoordinator.shouldPresentDayTwoPrompt, onDismiss: {
            reviewPromptCoordinator.handleDismissed()
        }) {
            DeveloperReviewNoteSheet(
                onReview: {
                    reviewPromptCoordinator.handleRated()
                },
                onLater: {
                    reviewPromptCoordinator.handleDismissed()
                }
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showPostMarkFocusPrompt, onDismiss: {
            if didAcceptPostMarkFocus == false {
                AnalyticsService.shared.log(.postMarkFocusPromptDismissed)
            }
            didAcceptPostMarkFocus = false
            let dayOrdinal = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
            let dayKey = "\(SoftPaywallCoordinator.currentISOWeekKey()).\(dayOrdinal)"
            showReturnTomorrowIfNeeded(dayKey: dayKey)
        }) {
            PostMarkFocusSheet(
                subjectName: focusPromptSubject?.name,
                onCaptureHomework: {
                    didAcceptPostMarkFocus = true
                    showPostMarkFocusPrompt = false
                    showTaskCapture = true
                },
                onStart: { minutes in
                    didAcceptPostMarkFocus = true
                    showPostMarkFocusPrompt = false
                    startFocusAfterMark(minutes: minutes)
                },
                onDismiss: {
                    showPostMarkFocusPrompt = false
                }
            )
            .presentationDetents([.height(348)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showTaskCapture) {
            StudyTaskCaptureFlow(
                subjects: subjectStore.subjects,
                onNeedSubjects: { isShowingSubjects = true },
                onAdded: { _ in },
                onStartFocus: {
                    if let first = StudyTaskStore.shared.pending.first {
                        FocusTimerService.shared.selectTask(first)
                    }
                    showFocusTimerSheet = true
                }
            )
        }
        .sheet(isPresented: $showTaskList) {
            NavigationStack {
                StudyTaskListScreen(
                    subjects: subjectStore.subjects,
                    onStartFocus: {
                        showTaskList = false
                        if let first = StudyTaskStore.shared.pending.first {
                            FocusTimerService.shared.selectTask(first)
                        }
                        showFocusTimerSheet = true
                    }
                )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showTaskList = false }
                                .foregroundStyle(.white)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(item: $editingHomeTask) { task in
            StudyTaskEditSheet(task: task, subjects: subjectStore.subjects)
        }
        .sheet(isPresented: $showFocusTimerSheet) {
            NavigationStack {
                FocusTimerToolScreen(subjects: subjectStore.subjects)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showFocusTimerSheet = false }
                                .foregroundStyle(.white)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func refreshGuidedSetup() {
        let legacyAttendance = subjectStore.subjects.contains(where: { $0.totalClasses > 0 })
        guidedSetup.refresh(
            subjectCount: subjectStore.subjects.count,
            hasMarked: GuidedSetupStore.hasUserMarked(
                subjectCount: subjectStore.subjects.count,
                hasAnalyticsMark: AnalyticsService.shared.hasMarkedAtLeastOnce,
                hasLegacyAttendance: legacyAttendance
            ),
            hasClassDays: subjectStore.subjects.contains { $0.weeklySchedule.totalPerWeek > 0 },
            hasSomethingToMark: subjectStore.subjectsForMarkToday().isEmpty == false
        )
    }

    private func startFocusAfterMark(minutes: Int) {
        let timer = FocusTimerService.shared
        if let subject = focusPromptSubject {
            timer.tagSubject(id: subject.id, name: subject.name)
            if let task = studyTasks.tasks(for: subject.id).first {
                timer.selectTask(task)
            }
        }
        timer.selectedFocusMinutes = minutes
        AnalyticsService.shared.log(.postMarkFocusPromptAccepted(minutes: minutes))
        MultiFeatureEngagementStore.record(.focus)
        showFocusTimerSheet = true
        timer.startOrResume()
    }

    /// After all of today's subjects are marked: Focus prompt (once/day) + “come back tomorrow” streak nudge.
    private func presentPostMarkHabitLoop(subject: SubjectSummary?) {
        let dayOrdinal = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let dayKey = "\(SoftPaywallCoordinator.currentISOWeekKey()).\(dayOrdinal)"
        let focusKey = "prompt.postMarkFocus.\(dayKey)"

        if UserDefaults.standard.bool(forKey: focusKey) == false,
           softPaywall.pendingSource == nil {
            UserDefaults.standard.set(true, forKey: focusKey)
            focusPromptSubject = subject ?? subjectStore.selectedSubject
            didAcceptPostMarkFocus = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard softPaywall.pendingSource == nil else {
                    showReturnTomorrowIfNeeded(dayKey: dayKey)
                    return
                }
                showPostMarkFocusPrompt = true
                AnalyticsService.shared.log(
                    .postMarkFocusPromptShown(subjectName: focusPromptSubject?.name ?? "")
                )
            }
            return
        }

        showReturnTomorrowIfNeeded(dayKey: dayKey)
    }

    private func showReturnTomorrowIfNeeded(dayKey: String) {
        let streak = AnalyticsService.shared.currentStreakDays
        let storageKey = "prompt.returnTomorrow.\(dayKey)"
        guard streak >= 1,
              UserDefaults.standard.bool(forKey: storageKey) == false else { return }
        UserDefaults.standard.set(true, forKey: storageKey)
        returnTomorrowBanner = streak == 1
            ? "Come back tomorrow — start a streak."
            : "Come back tomorrow — keep your \(streak)-day streak."
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_500_000_000)
            if returnTomorrowBanner != nil {
                withAnimation { returnTomorrowBanner = nil }
            }
        }
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

            // Pinned above the tab bar so mark-and-leave users still see the ad.
            stickyAdBanner
            phoneTabBar
        }
    }

    /// Anchored banner — collapses until filled; sits on the dark canvas.
    @ViewBuilder
    private var stickyAdBanner: some View {
        if entitlements.areBannersHidden == false {
            AdMobBannerCard(
                placement: AdMobConfiguration.Placement.home,
                isActive: true
            )
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background(BrandColor.colorBackground)
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
                            .font(.system(size: 17, weight: .bold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? BrandColor.colorAccentPrimary
                            : Color.white.opacity(0.42)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .background(BrandColor.colorBackground)
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
                    .background(BrandColor.colorBackground)
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
                    deadlineStore: deadlineStore,
                    navigateToDeadlines: $pendingToolsDeadlines
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
                    if subjectStore.subjects.isEmpty {
                        BrandEmptyState(
                            illustration: .emptyLog,
                            title: "No days to show yet",
                            message: "Add a subject on Today, then tap Attend or Missed. Your month fills in automatically.",
                            buttonTitle: "Add a subject",
                            action: {
                                triggerLightHaptic()
                                selectedTab = .home
                                isShowingSubjects = true
                            }
                        )
                    } else {
                        AttendanceLogView(subjectStore: subjectStore)
                    }
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
                    VStack(alignment: .leading, spacing: 16) {
                        compactHeaderSection

                        if let reward = referral.rewardBannerText {
                            referralRewardBanner(reward)
                        }

                        if let returnLine = returnTomorrowBanner {
                            returnTomorrowBannerView(returnLine)
                        }

                        if showFirstRunSetup == false, let step = guidedSetup.activeStep {
                            GuidedSetupBanner(step: step) {
                                handleGuidedSetupAction(step)
                            }
                        }

                        if subjectStore.subjects.isEmpty {
                            welcomeEmptyState
                        } else {
                            if let subject = todayHeroSubject {
                                assistantHeroCard(for: subject)
                            }

                            missingClassDaysCard

                            if subjectStore.lockedSubjectCount > 0 {
                                lockedExtrasBanner
                            }

                            MarkTodayCard(
                                subjectStore: subjectStore,
                                isHighlighted: highlightMarkToday,
                                onCelebrated: {
                                    refreshGuidedSetup()
                                },
                                onAllSubjectsMarkedToday: { subject in
                                    presentPostMarkHabitLoop(subject: subject)
                                },
                                onAddSubject: { isShowingSubjects = true },
                                onSetClassDays: { subjectID in
                                    classDaysSubjectID = subjectID
                                }
                            )
                            .id("markToday")

                            HomeDueSoonCard(
                                store: studyTasks,
                                onOpenAll: { showTaskList = true },
                                onEdit: { editingHomeTask = $0 }
                            )

                            HomeExamCoverageCard(store: studyTasks) { exam, topic in
                                studyTasks.setTopicCovered(
                                    taskID: exam.id,
                                    topicID: topic.id,
                                    covered: true
                                )
                            }

                            if let selected = subjectStore.selectedSubject {
                                HomeSubjectTasksRow(
                                    subject: selected,
                                    store: studyTasks,
                                    onEdit: { editingHomeTask = $0 }
                                )
                            }

                            if nearestExamAttendanceWarning != nil {
                                upcomingExamAttendanceWarning
                            }

                            streakInviteCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, tabScrollBottomPadding)
                    .frame(maxWidth: isRegularWidth ? 920 : .infinity, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .onChange(of: homeScrollToken) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("markToday", anchor: .center)
                        }
                    }
                }
                .onChange(of: guidedSetup.activeStep) { _, step in
                    if step == .markToday {
                        focusMarkTodayFromNotification()
                    }
                }
            }
        }
    }

    private var insightsTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                VStack(spacing: 20) {
                    insightsCoachCard
                    if hasAttendanceData {
                        insightsWeekPulse
                        trendGraphCard
                        skipPlannerWeekCard
                        subjectForecastCard
                    }
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
                    if subjectStore.subjects.isEmpty {
                        BrandEmptyState(
                            illustration: .emptySubjects,
                            title: "Your papers live here",
                            message: "Add Maths, DSA, whatever you have this semester. Then go back to Today and tap Attend or Missed.",
                            buttonTitle: "Add a subject",
                            action: {
                                triggerLightHaptic()
                                isShowingSubjects = true
                            }
                        )
                    } else {
                        allSubjectsDashboardCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, tabScrollBottomPadding)
                .frame(maxWidth: isRegularWidth ? 920 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private func handleGuidedSetupAction(_ step: GuidedSetupStep) {
        switch step {
        case .addSubject:
            if subjectStore.subjects.isEmpty {
                presentFirstRunIfNeeded()
            } else {
                isShowingSubjects = true
            }
        case .setClassDays:
            classDaysSubjectID = subjectStore.subjects.first(where: {
                $0.weeklySchedule.totalPerWeek == 0
            })?.id ?? subjectStore.selectedSubjectID
        case .markToday:
            focusMarkTodayFromNotification()
        }
    }

    private func presentFirstRunIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "onboarding.didComplete") else { return }
        guard subjectStore.subjects.isEmpty else { return }
        showFirstRunSetup = true
    }

    private func presentMissingDaysIfNeeded() {
        guard showFirstRunSetup == false else { return }
        guard classDaysSubjectID == nil else { return }
        classDaysSubjectID = subjectsMissingClassDays.first?.id
    }

    private var subjectsMissingClassDays: [SubjectSummary] {
        subjectStore.subjects.filter { $0.weeklySchedule.totalPerWeek == 0 }
    }

    @ViewBuilder
    private var missingClassDaysCard: some View {
        if let subject = subjectsMissingClassDays.first {
            Button {
                triggerLightHaptic()
                classDaysSubjectID = subject.id
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(BrandColor.colorPremium)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(subject.name) has no days set")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(
                            subjectsMissingClassDays.count > 1
                                ? "Today shows it every day until you pick class days."
                                : "Today shows this subject every day until you pick class days."
                        )
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    Spacer(minLength: 0)
                    Text("Set days")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(BrandColor.colorOnAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(BrandColor.colorPremium))
                }
                .padding(14)
                .background(BrandColor.cardFill(cornerRadius: 16))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func openExamDeadlinesFromWarning() {
        triggerLightHaptic()
        AnalyticsService.shared.log(.academicExamAttendanceWarningTapped)
        selectedTab = .tools
        pendingToolsDeadlines = true
    }

    private var upcomingExamAttendanceWarning: some View {
        Group {
            if let warning = nearestExamAttendanceWarning {
                Button(action: openExamDeadlinesFromWarning) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(BrandColor.colorStreakBadge)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(warning.title)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text(warning.body)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("View in Exam Deadlines →")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(BrandColor.colorStreakBadge.opacity(0.95))
                                .padding(.top, 2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(BrandColor.colorStreakBadge.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(BrandColor.colorStreakBadge.opacity(0.28), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PressableButtonStyle())
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

    private var animatedBackground: some View {
        LinearGradient(
            colors: [
                BrandColor.colorBackground,
                Color(hex: 0x10141C),
                BrandColor.colorBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var greetingName: String? {
        let raw = StudentProfileStore.shared.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.isEmpty == false else { return nil }
        return raw.split(separator: " ").first.map(String.init)
    }

    private var compactHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(subjectStore.subjects.isEmpty
                     ? (greetingName.map { "Hey \($0)" } ?? "Hey")
                     : (greetingName.map { "Hey \($0)" } ?? "Today"))
                    .font(BrandType.display(28))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button {
                    triggerLightHaptic()
                    if subjectStore.subjects.isEmpty {
                        isShowingSubjects = true
                    } else {
                        showTaskCapture = true
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Add homework from photo")

                Button {
                    triggerLightHaptic()
                    AnalyticsService.shared.log(.settingsOpened)
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Settings")
            }

            if subjectStore.subjects.isEmpty {
                Text("Add one subject. Then Attend or Missed.")
                    .font(BrandType.body(13))
                    .foregroundStyle(.white.opacity(0.58))
            } else if let progress = SemesterSettings.progress() {
                Text("Week \(progress.currentWeek) of \(progress.totalWeeks) · \(progress.weeksRemaining) week\(progress.weeksRemaining == 1 ? "" : "s") left")
                    .font(BrandType.body(13))
                    .foregroundStyle(.white.opacity(0.58))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(BrandColor.colorAccentPrimary)
                            .frame(width: max(6, geo.size.width * progress.fractionComplete))
                    }
                }
                .frame(height: 3)
            } else {
                Text("We’ll tell you how many you can \(studentMarket.skipVerb).")
                    .font(BrandType.body(13))
                    .foregroundStyle(.white.opacity(0.58))
            }
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
                    .foregroundStyle(BrandColor.colorAccentPrimary)

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
            Text("Fine-tune numbers")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Only if a total is wrong. Daily logging is Attend / Missed above.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            inputField(title: "CLASSES HELD", text: $viewModel.totalClassesInput, keyboardType: .numberPad)
            inputField(title: "YOU WENT", text: $viewModel.attendedClassesInput, keyboardType: .numberPad)
            inputField(title: "NEED %", text: $viewModel.requiredPercentageInput, keyboardType: .decimalPad)
            requiredPresetsRow
            clearInputsButton
            validationBanner
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandColor.colorSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(BrandColor.colorBorder, lineWidth: 1)
                )
                .shadow(color: BrandColor.colorElevation, radius: 16, y: 8)
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
                            .fill(BrandColor.colorMissed.opacity(0.2))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(BrandColor.colorMissed.opacity(0.35), lineWidth: 1)
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
        if let subject = todayHeroSubject {
            assistantHeroCard(for: subject)
        } else {
            welcomeEmptyState
        }
    }

    private var welcomeEmptyState: some View {
        BrandEmptyState(
            illustration: .emptyHome,
            title: "Start with one subject",
            message: "Add Maths or DSA, then tap Attend or Missed.\nThat’s the whole app.",
            buttonTitle: "Add a subject",
            action: {
                triggerLightHaptic()
                presentFirstRunIfNeeded()
                if showFirstRunSetup == false {
                    isShowingSubjects = true
                }
            }
        )
    }

    private func assistantHeroCard(for subject: SubjectSummary) -> some View {
        let result = AttendanceResult(
            currentPercentage: subject.currentPercentage,
            bunkAllowed: subject.bunkAllowed,
            recoveryNeeded: subject.recoveryNeeded,
            status: subject.status
        )
        let isSafe = result.status == .safe
        let accent = isSafe ? BrandColor.colorAccentPrimary : BrandColor.colorMissed
        let attendPct = CalculationService.currentPercentage(
            attended: subject.attendedClasses + 1,
            total: subject.totalClasses + 1
        )
        let skipPct = CalculationService.currentPercentage(
            attended: subject.attendedClasses,
            total: subject.totalClasses + 1
        )
        let streak = subject.id == subjectStore.selectedSubjectID
            ? subjectStore.attendanceStreakDays()
            : 0
        let skipLabel = studentMarket.skipVerb

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AttendanceStatusBadge(isSafe: isSafe)
                Text(subject.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                Button {
                    triggerLightHaptic()
                    subjectStore.selectSubject(id: subject.id)
                    isShowingFineTuneEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Edit numbers")

                Button {
                    triggerLightHaptic()
                    subjectStore.selectSubject(id: subject.id)
                    shareResult(result)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Share")
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(Int(result.currentPercentage.rounded()))%")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                if streak >= 2 {
                    Text("\(streak)-day streak")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.top, -4)

            Text(heroStatusLine(subject: subject, result: result, skipLabel: skipLabel))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                if subject.hasStableSample {
                    tomorrowChip(
                        title: "If you go",
                        value: String(format: "%.0f%%", attendPct),
                        tint: BrandColor.colorAttend
                    )
                    tomorrowChip(
                        title: "If you miss",
                        value: String(format: "%.0f%%", skipPct),
                        tint: BrandColor.colorMissed
                    )
                } else {
                    tomorrowChip(
                        title: "If you go",
                        value: "\(subject.attendedClasses + 1)/\(subject.totalClasses + 1)",
                        tint: BrandColor.colorAttend
                    )
                    tomorrowChip(
                        title: "If you miss",
                        value: "\(subject.attendedClasses)/\(subject.totalClasses + 1)",
                        tint: BrandColor.colorMissed
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BrandColor.colorSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func heroStatusLine(subject: SubjectSummary, result: AttendanceResult, skipLabel: String) -> String {
        if result.status != .safe {
            return "Need to attend: \(result.recoveryNeeded) more"
        }
        if result.bunkAllowed > 0 {
            let noun = result.bunkAllowed == 1 ? skipLabel : "\(skipLabel)s"
            return "\(result.bunkAllowed) \(noun) left"
        }
        if subject.hasStableSample == false {
            return "On track · buffer grows after more classes"
        }
        return "On the line — one miss drops you"
    }

    private func tomorrowChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        .foregroundStyle(BrandColor.colorMissed)
                    Text(validationMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BrandColor.colorMissed.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(BrandColor.colorMissed.opacity(0.3), lineWidth: 1)
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
        let primaryStatusColor = isSafe ? BrandColor.colorAccentPrimary : BrandColor.colorMissed
        let secondaryStatusColor = isSafe ? BrandColor.colorAttend : BrandColor.colorMissed.opacity(0.7)

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
                return BrandColor.colorAttend
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
                    .foregroundStyle(customResult.status == .safe ? BrandColor.colorAttend : BrandColor.colorStreakBadge)

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
        forecastDetailCard(isLocked: entitlements.isForecastUnlocked == false)
    }

    private var lockedForecastPreviewLine: String? {
        guard subjectStore.subjects.isEmpty == false else { return nil }
        let avg = Int(subjectStore.dashboardSummary.averageAttendance.rounded())
        if let worst = subjectStore.dashboardSummary.mostAtRiskSubject {
            let pct = Int(worst.currentPercentage.rounded())
            let req = Int(worst.requiredPercentage.rounded())
            if pct < req {
                return "\(worst.name): \(pct)% now · need \(req)%"
            }
            return "\(worst.name): \(pct)% · class avg \(avg)%."
        }
        return "Class average: \(avg)% today."
    }

    private func forecastDetailCard(isLocked: Bool) -> some View {
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

                if isLocked, let preview = lockedForecastPreviewLine {
                    Text(preview)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }

                if forecasts.isEmpty {
                    Text("Add a subject with attendance to see projections.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                } else {
                    forecastSubjectList(forecasts: forecasts, isLocked: isLocked)
                }
            }

            if isLocked {
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
                        Text("Unlock the rest of your semester")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(BrandColor.premiumGradient)
                    )
                }
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
        .onAppear {
            if isLocked {
                AnalyticsService.shared.log(.lockedForecastViewed)
                AnalyticsService.shared.logProCtaShownOnce(surface: "locked_forecast")
            } else {
                AnalyticsService.shared.log(.forecastViewed)
            }
            MultiFeatureEngagementStore.record(.forecast)
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
                    .foregroundStyle(BrandColor.colorAccentPrimary)
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
                        .stroke(BrandColor.colorAccentPrimary.opacity(0.28), lineWidth: 1)
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
                        .foregroundStyle(BrandColor.colorAccentPrimary)
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
                        .tint(BrandColor.colorAccentPrimary)
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
                        .tint(BrandColor.colorAccentPrimary)
                        .onChange(of: semesterEndDate) { _, newValue in
                            SemesterSettings.endDate = newValue
                            forecastWeeks = SemesterSettings.weeksRemaining()
                        }
                        Text("Semester remaining: \(forecastWeeks) week\(forecastWeeks == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(BrandColor.colorAccentPrimary)
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
            Text(HolidayPresets.sectionTitle(for: studentMarket))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            Text(HolidayPresets.sectionSubtitle(for: studentMarket))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
            if presets.isEmpty {
                Text("No regional presets — use the stepper above for your own break.")
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
                    .foregroundStyle(BrandColor.colorAccentPrimary)
            }

            Text(hint)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            Stepper("", value: value, in: range)
                .labelsHidden()
                .tint(BrandColor.colorAccentPrimary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func forecastSubjectList(forecasts: [SubjectForecast], isLocked: Bool) -> some View {
        let previewID = subjectStore.dashboardSummary.mostAtRiskSubject?.id ?? forecasts.first?.id
        ForEach(forecasts) { item in
            if isLocked, item.id != previewID {
                lockedForecastRow(for: item)
            } else {
                forecastAccordionCard(for: item)
            }
        }
    }

    private func lockedForecastRow(for item: SubjectForecast) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.subjectName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Semester landing is Pro")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 8)
            Text("••%")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.28))
                .blur(radius: 3)
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(BrandColor.colorPremium)
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
        .accessibilityLabel("\(item.subjectName), forecast locked")
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
                            .foregroundStyle(item.willFallBelowTarget ? BrandColor.colorStreakBadge : .white)
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
                            .foregroundStyle(BrandColor.colorPremium.opacity(0.9))
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
                tint: BrandColor.colorAccentPrimary
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
                        : (delta < 0 ? BrandColor.colorStreakBadge : BrandColor.colorAttend)
                )
                Spacer()
            }

            forecastPercentBar(
                label: "Projected",
                percentage: item.forecastedPercentage,
                tint: item.willFallBelowTarget ? BrandColor.colorStreakBadge : BrandColor.colorAttend
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
            HStack(alignment: .center, spacing: 8) {
                Text("All \(studentMarket.courseNounPluralTitle)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    triggerLightHaptic()
                    isShowingSubjects = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandColor.colorOnAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(BrandColor.colorAccentPrimary))
                }
                .buttonStyle(PressableButtonStyle())
                Menu {
                    Button {
                        triggerLightHaptic()
                        exportAttendancePDF()
                    } label: {
                        Label("PDF report", systemImage: entitlements.hasProFeatures ? "doc.richtext" : "lock.fill")
                    }
                    Button {
                        triggerLightHaptic()
                        exportAttendanceCSV()
                    } label: {
                        Label("CSV log", systemImage: entitlements.hasProFeatures ? "tablecells" : "lock.fill")
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isExportingPDF {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: entitlements.hasProFeatures ? "square.and.arrow.up" : "lock.fill")
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
                    overviewSubjectRow(subject)
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

    private func overviewSubjectRow(_ subject: SubjectSummary) -> some View {
        let chipTint: Color = {
            if subject.hasAttendance == false { return BrandColor.colorPremium }
            return subject.isAtRisk ? BrandColor.colorMissed : BrandColor.colorAttend
        }()
        let percentTint: Color = {
            if subject.hasAttendance == false { return .white.opacity(0.55) }
            return subject.isAtRisk ? BrandColor.colorMissed : BrandColor.colorAttend
        }()
        let hasDays = subject.weeklySchedule.totalPerWeek > 0
        let left = subjectStore.classesLeftThisSemester(
            for: subject,
            weeks: forecastWeeks,
            holidayClassCount: forecastHolidayClasses,
            plannedBunks: forecastExpectedAbsences,
            fallbackClassesPerWeek: forecastClassesPerWeek
        )

        return HStack(alignment: .center, spacing: 10) {
            Button {
                triggerLightHaptic()
                AnalyticsService.shared.log(.timetableEditorOpened)
                classDaysSubjectID = subject.id
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subject.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(subject.hasAttendance
                             ? "\(String(format: "%.0f%%", subject.currentPercentage))"
                             : "No classes yet")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(percentTint)
                        Text(hasDays
                             ? (left == 1 ? "1 class left" : "\(left) classes left")
                             : "Tap to set class days")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(hasDays ? .white.opacity(0.5) : BrandColor.colorPremium)
                    }
                    Spacer(minLength: 8)
                    Text(subject.actionChipLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule(style: .continuous).fill(chipTint))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("\(subject.name), \(hasDays ? "edit class days" : "set class days")")

            Button(role: .destructive) {
                triggerLightHaptic()
                subjectStore.deleteSubject(id: subject.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BrandColor.colorMissed)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(BrandColor.colorMissed.opacity(0.16)))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Delete \(subject.name)")
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

    private var facultyDashboardCard: some View {
        allSubjectsDashboardCard
    }

    private func progressCard(for result: AttendanceResult) -> some View {
        let progress = min(max(result.currentPercentage / 100, 0), 1)
        let ringColor = result.status == .safe ? BrandColor.colorAccentPrimary : BrandColor.colorMissed

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

    private func exportAttendancePDF() {
        AnalyticsService.shared.log(.pdfExportTapped)
        guard entitlements.hasProFeatures else {
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
        guard entitlements.hasProFeatures else {
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
        Task { @MainActor in
            await referral.ensureInviteCode()
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
            if ReferralConfiguration.inviteSystemShareEnabled, referral.inviteCode != nil {
                AnalyticsService.shared.log(.inviteLinkShared)
            }
        }
    }

    private func shareStreak(days: Int) {
        Task { @MainActor in
            await referral.ensureInviteCode()
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
            if ReferralConfiguration.inviteSystemShareEnabled, referral.inviteCode != nil {
                AnalyticsService.shared.log(.inviteLinkShared)
            }
        }
    }

    private func shareStreakMessage(days: Int) -> String {
        let headline = days == 1
            ? "I'm on a 1-day attendance streak 🔥"
            : "I'm on a \(days)-day attendance streak 🔥"
        if ReferralConfiguration.inviteSystemShareEnabled,
           let invite = referral.shareInviteLine() {
            return "\(headline)\n\(invite)"
        }
        return "\(headline)\nTry Bunk Planner: Attendance Track."
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
        let verb = studentMarket.skipVerb
        let headline: String
        if result.status == .safe {
            if result.bunkAllowed > 0 {
                headline = "I can \(verb) \(result.bunkAllowed) classes safely 😎"
            } else {
                headline = "I'm exactly on the safe attendance line ⚖️"
            }
        } else {
            headline = "I'm in recovery mode: need to attend \(result.recoveryNeeded) classes 💪"
        }
        if ReferralConfiguration.inviteSystemShareEnabled,
           let invite = referral.shareInviteLine() {
            return "\(headline)\n\(invite)"
        }
        return "\(headline)\nTry Bunk Planner: Attendance Track."
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
        let palette = sharePalette(for: result)
        let heroNumber: String
        let heroLabel: String
        if result.status == .safe {
            heroNumber = "\(max(result.bunkAllowed, 0))"
            heroLabel = result.bunkAllowed == 1
                ? "SAFE \(studentMarket.skipVerb.uppercased())"
                : "SAFE \(studentMarket.skipNounPluralTitle.uppercased())"
        } else {
            heroNumber = "\(max(result.recoveryNeeded, 1))"
            heroLabel = "CLASSES TO RECOVER"
        }

        return ZStack {
            shareBackground(palette: palette)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BUNK PLANNER")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(2.4)
                        Text(subjectStore.selectedSubjectName.uppercased())
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.accent)
                            .tracking(1.6)
                    }
                    Spacer()
                    Text(result.status == .safe ? "SAFE" : "RECOVER")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(palette.accent))
                }

                Spacer()

                Text(heroNumber)
                    .font(.system(size: 280, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .offset(x: -12)

                Text(heroLabel)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(2)
                    .padding(.bottom, 28)

                Text(shareHeadline(for: result))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 36)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(String(format: "%.1f%% now", result.currentPercentage))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(String(format: "target %.0f%%", viewModel.requiredPercentage))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.1)).frame(height: 16)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [palette.accent, palette.secondaryAccent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * min(max(result.currentPercentage / 100, 0), 1),
                                    height: 16
                                )
                        }
                    }
                    .frame(height: 16)
                }

                Spacer()

                shareFooter(message: message, palette: palette)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 80)
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

    private func shareFooter(message: String, palette: SharePalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(message)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Know before you bunk")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .tracking(0.4)
                Spacer()
                Text("schoolabe.com")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(palette.accent.opacity(0.35), lineWidth: 1)
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
                shareFooter(message: message, palette: palette)
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
                    tint: BrandColor.colorPremium
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

    private var insightsCoachCard: some View {
        InsightsCoachCard(
            advice: InsightsCoach.advice(
                subjects: subjectStore.subjects,
                skipVerb: studentMarket.skipVerb,
                skipNounPlural: studentMarket.skipNounPlural,
                isPro: entitlements.hasProFeatures
            ),
            subjects: subjectStore.subjects,
            isPro: entitlements.hasProFeatures,
            onSelectSubject: { id in
                triggerLightHaptic()
                subjectStore.selectedSubjectID = id
            },
            onEmptyAction: {
                triggerLightHaptic()
                selectedTab = .home
                isShowingSubjects = true
            },
            onLockedRecover: {
                triggerLightHaptic()
                AnalyticsService.shared.log(.proCtaTapped(surface: "plan_recover", action: "go_pro"))
                proPaywallSource = "forecast"
                isShowingProPaywall = true
            }
        )
    }

    private var insightsWeekPulse: some View {
        let summary = subjectStore.weeklyAttendanceSummary()
        let streak = subjectStore.attendanceStreakDays()
        return InsightsWeekPulseCard(
            attended: summary.attendedClasses,
            missed: summary.missedClasses,
            streak: streak,
            skipNounPlural: studentMarket.skipNounPluralTitle,
            onShareStreak: {
                triggerLightHaptic()
                shareStreak(days: streak)
            }
        )
        .onAppear {
            if streak > 0 {
                AnalyticsService.shared.log(.streakUpdated(days: streak))
            }
        }
    }

    private var skipPlannerWeekCard: some View {
        SkipPlannerWeekCard(
            subjects: subjectStore.subjects,
            isPro: entitlements.hasProFeatures,
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

    private var trendGraphCard: some View {
        let points = trendPointsForSelectedSubject()
        let latest = points.last?.percentage ?? 0
        let minValue = points.map(\.percentage).min() ?? 0
        let maxValue = points.map(\.percentage).max() ?? 0
        let name = subjectStore.selectedSubjectName
        let skipVerb = studentMarket.skipVerb
        let reading: String? = {
            guard points.count >= 2 else { return nil }
            let delta = points[points.count - 1].percentage - points[points.count - 2].percentage
            if delta >= 1 {
                return "Up \(String(format: "%.0f", delta)) pts. Buffer is growing."
            }
            if delta <= -1 {
                return "Dropped \(String(format: "%.0f", abs(delta))) pts. Don’t \(skipVerb) this one."
            }
            return "\(name) is holding steady."
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TREND")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .tracking(1.1)
                    Text(name)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            if points.count < 2 {
                Text("Log this subject twice and you’ll see whether you’re climbing or slipping.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                if let reading {
                    Text(reading)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                AttendanceTrendSparkline(points: points)
                    .frame(height: 90)

                HStack(spacing: 10) {
                    trendChip(title: "Now", value: "\(String(format: "%.0f", latest))%")
                    trendChip(title: "Low", value: "\(String(format: "%.0f", minValue))%")
                    trendChip(title: "High", value: "\(String(format: "%.0f", maxValue))%")
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
                        .foregroundStyle(BrandColor.colorAttend)
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

    private var lockedExtrasBanner: some View {
        Button {
            AnalyticsService.shared.log(.proCtaTapped(surface: "locked_subject", action: "go_pro"))
            proPaywallSource = "locked_subject"
            isShowingProPaywall = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(BrandColor.colorPremium)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(subjectStore.lockedSubjectCount) extra \(subjectStore.lockedSubjectCount == 1 ? "subject is" : "subjects are") locked")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your first \(ProPurchaseConfiguration.freeSubjectLimit) stay free. Go Pro to keep marking the rest — nothing was deleted.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BrandColor.colorPremium.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(BrandColor.colorPremium.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onAppear {
            AnalyticsService.shared.logProCtaShownOnce(surface: "locked_subject")
        }
    }

    private func referralRewardBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(BrandColor.colorAccentPrimary)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            Button {
                referral.dismissRewardBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BrandColor.colorAccentPrimary.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BrandColor.colorAccentPrimary.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func returnTomorrowBannerView(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(BrandColor.colorPremium)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            Button {
                withAnimation { returnTomorrowBanner = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BrandColor.colorPremium.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(BrandColor.colorPremium.opacity(0.28), lineWidth: 1)
                )
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private var streakInviteCard: some View {
        let streak = AnalyticsService.shared.currentStreakDays
        let dismissKey = "prompt.streakInvite"
        // Hold Home invite share until redeem reason breakdown is clean in prod.
        if ReferralConfiguration.inviteSystemShareEnabled,
           entitlements.isPro == false,
           streak >= 7,
           dismissStreakInvite == false,
           UserDefaults.standard.bool(forKey: dismissKey) == false {
            VStack(alignment: .leading, spacing: 10) {
                Text("You’re on a \(streak)-day streak")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Invite a friend. You both get \(ReferralConfiguration.grantDays) days of all Pro features when they redeem. Ads stay on.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                HStack(spacing: 10) {
                    Button {
                        Task {
                            await referral.ensureInviteCode()
                            if let result = viewModel.result {
                                shareResult(result)
                            } else if let line = referral.shareInviteLine() {
                                shareItems = [line]
                                isShowingShareSheet = true
                                AnalyticsService.shared.log(.inviteLinkShared)
                            }
                        }
                    } label: {
                        Text("Invite a friend")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(BrandColor.colorAccentPrimary))
                    }
                    .buttonStyle(PressableButtonStyle())
                    Button {
                        UserDefaults.standard.set(true, forKey: dismissKey)
                        dismissStreakInvite = true
                    } label: {
                        Text("Not now")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
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
    }

    private var homeRotatingPromoCard: some View {
        let promo: HomePromoKind = {
            // At-risk free users need Skip Planner more than a rotating export tip.
            if entitlements.hasProFeatures == false,
               subjectStore.dashboardSummary.riskSubjects > 0 {
                return .skipPlanner
            }
            return HomePromoStore.promoForCurrentWeek()
        }()
        return HomePromoCard(
            promo: promo,
            market: studentMarket,
            onAction: { handleHomePromoTap(promo) }
        )
        .onAppear {
            AnalyticsService.shared.log(.homePromoCardShown(kind: promo.rawValue))
        }
    }

    private func handleHomePromoTap(_ promo: HomePromoKind) {
        triggerLightHaptic()
        switch promo {
        case .skipPlanner:
            AnalyticsService.shared.log(.homePromoCardTapped(kind: promo.rawValue, action: "skip_planner"))
            MultiFeatureEngagementStore.record(.skipPlanner)
            presentSkipPlannerOrPaywall()
        case .focus:
            AnalyticsService.shared.log(.homePromoCardTapped(kind: promo.rawValue, action: "focus"))
            if let subject = subjectStore.selectedSubject {
                FocusTimerService.shared.tagSubject(id: subject.id, name: subject.name)
            }
            MultiFeatureEngagementStore.record(.focus)
            showFocusTimerSheet = true
        case .export:
            AnalyticsService.shared.log(.homePromoCardTapped(kind: promo.rawValue, action: "export"))
            selectedTab = .tools
        case .widget:
            AnalyticsService.shared.log(.homePromoCardTapped(kind: promo.rawValue, action: "widget"))
            widgetPrompt.presentInstructions()
            MultiFeatureEngagementStore.record(.widget)
        }
    }

    @ViewBuilder
    private var atRiskSharePromptCard: some View {
        // Free at-risk users should see Pro, not a share card (812 share vs 114 paywall this week).
        if entitlements.isPro,
           dismissAtRiskSharePrompt == false,
           let result = viewModel.result,
           result.status == .risk,
           hasAttendanceData {
            let weekKey = SoftPaywallCoordinator.currentISOWeekKey()
            let dismissKey = "prompt.atRiskShare.\(weekKey)"
            if UserDefaults.standard.bool(forKey: dismissKey) == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tell a friend your safe bunk count")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Share how many classes you can still \(studentMarket.skipVerb) — or flex that you're in recovery mode.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    HStack(spacing: 10) {
                        Button {
                            AnalyticsService.shared.log(.atRiskSharePromptTapped)
                            shareResult(result)
                        } label: {
                            Text("Share")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.black.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(BrandColor.colorAccentPrimary))
                        }
                        .buttonStyle(PressableButtonStyle())
                        Button {
                            UserDefaults.standard.set(true, forKey: dismissKey)
                            dismissAtRiskSharePrompt = true
                        } label: {
                            Text("Not now")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(BrandColor.colorMissed.opacity(0.35), lineWidth: 1)
                        )
                )
                .onAppear {
                    AnalyticsService.shared.log(.atRiskSharePromptShown)
                }
            }
        }
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
            focusMarkTodayFromNotification()
        case "start_recovery", "skip_plan":
            presentSkipPlannerOrPaywall()
        case "create_subject":
            isShowingSubjects = true
        case "maintain_streak":
            selectedTab = .insights
        default:
            if result?.status == .risk {
                presentSkipPlannerOrPaywall()
            } else {
                selectedTab = .home
                focusMarkTodayFromNotification()
            }
        }
    }

    private func contextualFABCopy(for result: AttendanceResult?) -> (title: String, value: String, subtitle: String, tint: Color, analytics: String) {
        let hour = Calendar.current.component(.hour, from: Date())
        let loggedToday = subjectStore.hasLoggedToday()
        let green = BrandColor.colorAttend
        let red = BrandColor.colorMissed
        let cyan = BrandColor.colorAccentPrimary

        if subjectStore.subjects.isEmpty {
            return ("Start here", "Add your first subject", "Then Attend or Missed", cyan, "create_subject")
        }
        if !loggedToday {
            let pending = subjectStore.subjectsForMarkToday().count
            if hour < 12 {
                return (
                    "Morning",
                    pending > 1 ? "Mark \(pending) subjects" : "Attend or Missed?",
                    "Attend · Missed · No class",
                    cyan,
                    "log_morning"
                )
            }
            if hour >= 17 {
                return (
                    "Evening",
                    pending > 1 ? "Finish \(pending) subjects" : "Attend or Missed before you sleep",
                    "Takes 5 seconds",
                    .orange,
                    "log_evening"
                )
            }
            return (
                "Today",
                pending > 1 ? "Mark \(pending) subjects" : "Attend or Missed?",
                "Attend · Missed · No class",
                cyan,
                "log_today"
            )
        }
        guard let result else {
            return ("Today", "Attend or Missed?", "Keep tracking", cyan, "log_today")
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
            return BrandColor.colorAttend
        case .warning:
            return BrandColor.colorStreakBadge
        case .critical:
            return BrandColor.colorMissed
        }
    }
}

private struct AttendanceTrendSparkline: View {
    let points: [AttendanceTrendPoint]

    var body: some View {
        GeometryReader { geometry in
            let coords = plotCoordinates(in: geometry.size)
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.2))

                Path { path in
                    guard let first = coords.first else { return }
                    path.move(to: first)
                    for point in coords.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    BrandColor.colorAccentPrimary,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                if let first = coords.first {
                    endpointDot(at: first)
                }
                if coords.count > 1, let last = coords.last {
                    endpointDot(at: last)
                }
            }
        }
    }

    private func plotCoordinates(in size: CGSize) -> [CGPoint] {
        let insetX: CGFloat = 16
        let insetY: CGFloat = 12
        let width = max(size.width - insetX * 2, 1)
        let height = max(size.height - insetY * 2, 1)
        let minimum = points.map(\.percentage).min() ?? 0
        let maximum = points.map(\.percentage).max() ?? 100
        let range = max(maximum - minimum, 0.1)
        let stepX = points.count > 1 ? width / CGFloat(points.count - 1) : width

        return points.enumerated().map { index, point in
            let yRatio = (point.percentage - minimum) / range
            return CGPoint(
                x: insetX + CGFloat(index) * stepX,
                y: insetY + height - (CGFloat(yRatio) * height)
            )
        }
    }

    private func endpointDot(at point: CGPoint) -> some View {
        Circle()
            .fill(BrandColor.colorAccentPrimary)
            .frame(width: 8, height: 8)
            .overlay(
                Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            )
            .position(point)
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
            return "Today"
        case .insights:
            return "Plan"
        case .log:
            return "Log"
        case .overview:
            return "Subjects"
        case .tools:
            return "More"
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
                SettingsSheetView(viewModel: viewModel, subjectStore: subjectStore)
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
                                if subjectStore.isSubjectLocked(subject.id) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(BrandColor.colorPremium)
                                }
                                if subject.id == subjectStore.selectedSubjectID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BrandColor.colorAttend)
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
                            guard name.isEmpty == false else { return }
                            if subjectStore.addSubject(named: name) {
                                newName = ""
                            } else if SoftPaywallCoordinator.shared.consumeSubjectLimitTrigger() {
                                isShowingProPaywall = true
                            } else {
                                isShowingSubjectLimitAlert = true
                            }
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onManageSubjects()
                        }
                    } label: {
                        Label("Manage subjects & class days", systemImage: "slider.horizontal.3")
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
    @State private var classDaysSubjectID: UUID?
    @State private var isShowingSubjectLimitAlert = false
    @State private var isShowingProPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(subjectStore.subjects) { subject in
                        VStack(alignment: .leading, spacing: 10) {
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

                                    if subjectStore.isSubjectLocked(subject.id) {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(BrandColor.colorPremium)
                                    }

                                    Text("\(Int(subject.currentPercentage.rounded()))%")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(subject.hasAttendance
                                                         ? (subject.isAtRisk ? BrandColor.colorMissed : BrandColor.colorAttend)
                                                         : .white.opacity(0.55))

                                    if subject.id == subjectStore.selectedSubjectID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(BrandColor.colorAttend)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 8) {
                                Button {
                                    AnalyticsService.shared.log(.timetableEditorOpened)
                                    classDaysSubjectID = subject.id
                                } label: {
                                    Label(
                                        subject.weeklySchedule.totalPerWeek > 0 ? "Days" : "Set days",
                                        systemImage: "calendar"
                                    )
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(BrandColor.colorOnAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(BrandColor.colorAccentPrimary)
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    renamingSubjectID = subject.id
                                    renameSubjectName = subject.name
                                    isShowingRenamePrompt = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.white.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.04))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                subjectStore.deleteSubject(id: subject.id)
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                    .onDelete(perform: subjectStore.deleteSubjects)
                } header: {
                    Text("Subjects")
                } footer: {
                    Text("Set class days so Today only asks you to mark lectures you actually have.")
                }

            }
            .scrollContentBackground(.hidden)
            .background(BrandColor.colorBackground)
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
                    let name = newSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard name.isEmpty == false else { return }
                    if subjectStore.addSubject(named: name) == false {
                        if SoftPaywallCoordinator.shared.consumeSubjectLimitTrigger() {
                            isShowingProPaywall = true
                        } else {
                            isShowingSubjectLimitAlert = true
                        }
                    } else {
                        classDaysSubjectID = subjectStore.selectedSubjectID
                    }
                }
            } message: {
                Text("Name the paper — Maths, DSA, History.")
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
                    get: { classDaysSubjectID != nil },
                    set: { isPresented in
                        if isPresented == false {
                            classDaysSubjectID = nil
                        }
                    }
                )
            ) {
                if let subjectID = classDaysSubjectID {
                    ClassDaysSheet(
                        subjectStore: subjectStore,
                        subjectID: subjectID
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

struct TimetableEditorSheet: View {
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
                Section {
                    Text("Tap each lecture hour. Untapped hours are free.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    dayHours("Monday", weekday: 2)
                    dayHours("Tuesday", weekday: 3)
                    dayHours("Wednesday", weekday: 4)
                    dayHours("Thursday", weekday: 5)
                    dayHours("Friday", weekday: 6)
                    dayHours("Saturday", weekday: 7)
                    dayHours("Sunday", weekday: 1)
                } header: {
                    Text("Weekly hours")
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

    private func dayHours(_ title: String, weekday: Int) -> some View {
        let hours = schedule.hours(weekday: weekday)
        let savedCount = schedule.count(weekday: weekday)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(hours.isEmpty ? savedCount : hours.count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            PeriodChipGrid(selectedHours: Set(hours)) { hour in
                schedule.toggleHour(hour, weekday: weekday)
            }
            if hours.isEmpty && savedCount > 0 {
                Text("\(savedCount) classes saved — tap the hours they happen")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
