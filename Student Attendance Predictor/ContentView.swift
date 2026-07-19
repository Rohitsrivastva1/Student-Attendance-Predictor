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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
        .onAppear {
            AppLaunchState.isMainContentReady = false
            AdMobAppOpenService.shared.recordLaunch()
            AdMobService.requestTrackingPermission()
            AdMobInterstitialService.shared.preload()
            AdMobAppOpenService.shared.preload()
            // Rewarded preload once ads may be shown — improves 24h-remove / unlock CTR.
            AdMobRewardedService.shared.preload()
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
            AnalyticsUserProfile.sync(subjectStore: store)
            decideOnboarding(for: store)
            // Cold-start app-open: content is up; try once if a preloaded ad is ready.
            AdMobAppOpenService.shared.showAdIfAvailable()
        }
    }

    /// Returning users with real data skip the intro so updates don't interrupt habit.
    private func decideOnboarding(for store: SubjectStore) {
        let defaults = UserDefaults.standard
        let key = "onboarding.didComplete"
        if defaults.bool(forKey: key) {
            showOnboarding = false
            return
        }

        let isReturning = store.subjects.contains { $0.totalClasses > 0 }
            || defaults.bool(forKey: "attendance.didMigrateToCoreDataV1")
            || (defaults.object(forKey: "ads.appOpen.launchCount") as? Int ?? 0) > 1

        if isReturning {
            defaults.set(true, forKey: key)
            showOnboarding = false
        } else {
            showOnboarding = true
        }
    }
}

#Preview {
    ContentView()
}
