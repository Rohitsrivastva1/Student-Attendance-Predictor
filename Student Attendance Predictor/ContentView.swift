//
//  ContentView.swift
//  Student Attendance Predictor
//
//  Created by Rohit Srivastava on 02/04/26.
//

import SwiftUI

struct ContentView: View {
    @State private var subjectStore: SubjectStore?
    @State private var showOnboarding = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.1)
                .ignoresSafeArea()

            if let subjectStore {
                HomeView(viewModel: subjectStore.calculator, subjectStore: subjectStore)
                    .transition(.opacity)
            } else {
                ProgressView("Loading…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            // After intro (or paywall), allow a cold-start app-open if one is ready.
            AdMobAppOpenService.shared.showAdIfAvailable()
        }) {
            OnboardingView {
                showOnboarding = false
            }
        }
        .onAppear {
            AppLaunchState.isMainContentReady = false
            AttendanceViewModel.recordAppSession()
            AdMobAppOpenService.shared.recordLaunch()
            AdMobService.requestTrackingPermission()
            AdMobInterstitialService.shared.preload()
            AdMobAppOpenService.shared.preload()
        }
        .task(id: subjectStore == nil) {
            guard subjectStore == nil else { return }
            await Task.yield()
            await PersistenceController.shared.waitForStoreIfNeeded()
            let store = SubjectStore()
            store.performDeferredLaunchTasks()
            subjectStore = store
            AnalyticsService.shared.appBecameReady()
            AppLaunchState.isMainContentReady = true
            FocusTimerService.shared.reconcileLiveActivityOnLaunchIfNeeded()
            AnalyticsUserProfile.sync(subjectStore: store)
            decideOnboarding(for: store)
            // Cold-start app-open: wait until onboarding is dismissed so it doesn't cover the intro.
            if UserDefaults.standard.bool(forKey: "onboarding.didComplete") {
                AdMobAppOpenService.shared.showAdIfAvailable()
                AppStoreReviewPromptCoordinator.shared.scheduleDayTwoPromptIfNeeded()
            }
        }
        .onChange(of: showOnboarding) { _, isShowing in
            guard isShowing == false, let store = subjectStore else { return }
            GuidedSetupStore.shared.refreshAfterOnboarding(
                subjectCount: store.subjects.count,
                hasMarked: GuidedSetupStore.hasUserMarked(
                    subjectCount: store.subjects.count,
                    hasAnalyticsMark: AnalyticsService.shared.hasMarkedAtLeastOnce,
                    hasLegacyAttendance: store.subjects.contains(where: { $0.totalClasses > 0 })
                )
            )
            AppStoreReviewPromptCoordinator.shared.scheduleDayTwoPromptIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .attendanceDataChanged)) { _ in
            subjectStore?.reloadFromExternalChange()
        }
    }

    /// Show intro for true first runs. Skip only if already completed, or the user
    /// already has attendance data (update path / reinstall with iCloud backup rare).
    /// Do NOT use `didMigrateToCoreDataV1` or launch-count — migration runs on every
    /// fresh install and would hide onboarding forever.
    private func decideOnboarding(for store: SubjectStore) {
        let defaults = UserDefaults.standard
        let key = "onboarding.didComplete"
        if defaults.bool(forKey: key) {
            showOnboarding = false
            return
        }

        if store.subjects.contains(where: { $0.totalClasses > 0 }) {
            defaults.set(true, forKey: key)
            GuidedSetupStore.shared.markCompleteSilently()
            showOnboarding = false
            AnalyticsService.shared.log(.onboardingSkipped(reason: "returning_data"))
            return
        }

        // Defer one run-loop so fullScreenCover attaches after Home is in the hierarchy.
        DispatchQueue.main.async {
            showOnboarding = true
            AnalyticsService.shared.log(.onboardingShown)
        }
    }
}

#Preview {
    ContentView()
}
