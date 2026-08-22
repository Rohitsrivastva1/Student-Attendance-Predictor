//
//  AdMobAppOpenService.swift
//  Student Attendance Predictor
//
//  App open ads when the user opens or returns to the app.
//  Cadence: show on opens 1, 2, 4, 5, 7, 8, … (skip every 3rd open).
//

import Foundation
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Shared launch state so app-open ads know whether main content is already on screen.
@MainActor
enum AppLaunchState {
    static var isMainContentReady = false
}

@MainActor
final class AdMobAppOpenService: NSObject {
    static let shared = AdMobAppOpenService()

    /// Ads expire four hours after load (Google requirement).
    private let adExpirationInterval: TimeInterval = 4 * 3_600

    /// Cycle length: show, show, skip → opens 1+2 yes, 3 no, 4+5 yes, 6 no, …
    private let openCadenceCycle = 3

    private let openCountKey = "ads.appOpen.openCount"
    private let launchCountKey = "ads.appOpen.launchCount"

    private var isFirstActivationThisLaunch = true
    private var isLoadingAd = false
    private var isShowingAd = false
    private var didRecordImpression = false
    private var loadTime: Date?
    private var sdkReadyObserver: NSObjectProtocol?
    private var pendingShowTask: Task<Void, Never>?

    /// One cadence decision per foreground activation (cold start or resume).
    private var skippedCadenceThisActivation = false
    private var allowedShowThisActivation = false

    #if canImport(GoogleMobileAds)
    private var appOpenAd: AppOpenAd?
    #endif

    private override init() {
        super.init()
        sdkReadyObserver = NotificationCenter.default.addObserver(
            forName: .adMobSDKDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadAd()
            }
        }
    }

    deinit {
        pendingShowTask?.cancel()
        if let sdkReadyObserver {
            NotificationCenter.default.removeObserver(sdkReadyObserver)
        }
    }

    func preload() {
        Task { await loadAd() }
    }

    /// Reset cadence so the next foreground counts as a new open.
    func noteSceneDidEnterBackground() {
        skippedCadenceThisActivation = false
        allowedShowThisActivation = false
        isFirstActivationThisLaunch = false
    }

    /// Call when the scene becomes active (mirrors `applicationDidBecomeActive`).
    func showAdIfAvailable() {
        pendingShowTask?.cancel()
        pendingShowTask = Task { @MainActor in
            // Debounce competing triggers (scenePhase + SDK ready) and let UI settle.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard Task.isCancelled == false else { return }
            await performShowIfAvailable()
        }
    }

    #if canImport(GoogleMobileAds)
    private func performShowIfAvailable() async {
            guard AdEntitlementsStore.shared.areBannersHidden == false else {
                logSkip("ads_removed_reward_active")
                return
            }
            if isShowingAd || AdMobFullScreenGate.isOccupied {
                logSkip("already_showing")
                return
            }

            // Decide once per activation: show on 1st+2nd of each cycle; skip every 3rd.
            // Duplicate scenePhase / SDK-ready triggers must not log another skip.
            if skippedCadenceThisActivation {
                return
            }
            if allowedShowThisActivation == false {
                let openNumber = recordOpenAndReturnCount()
                if shouldShow(forOpenNumber: openNumber) == false {
                    skippedCadenceThisActivation = true
                    logSkip("open_cadence")
                    await loadAd()
                    return
                }
                allowedShowThisActivation = true
            }

            let isColdStartActivation = isFirstActivationThisLaunch
            isFirstActivationThisLaunch = false

            guard await AdMobService.ensureReadyForAds() else {
                logSkip("consent_or_sdk_not_ready")
                return
            }

            if isAdAvailable() == false {
                // Give a short window for an in-flight load (common on cold start).
                if isColdStartActivation {
                    await loadAd()
                }
                if isAdAvailable() == false {
                    logSkip(appOpenAd == nil ? "not_loaded" : "expired")
                    await loadAd()
                    return
                }
            }

            guard let ad = appOpenAd else {
                logSkip("ad_reference_nil_after_available_check")
                await loadAd()
                return
            }

            // Let first paint settle so presentation doesn't race the loading screen.
            try? await Task.sleep(nanoseconds: isColdStartActivation ? 600_000_000 : 350_000_000)

            guard AdMobFullScreenGate.tryAcquire() else {
                logSkip("fullscreen_gate_busy")
                return
            }

            let root = await AdMobPresentation.waitForRoot()
            guard let root else {
                AdMobFullScreenGate.release()
                logSkip("root_view_controller_nil")
                await loadAd()
                return
            }

            appOpenAd = nil
            isShowingAd = true
            didRecordImpression = false
            ad.fullScreenContentDelegate = self
            AnalyticsService.shared.log(.appOpenAdRequested)
            #if DEBUG
            print("[AdMob] App open presenting from \(String(describing: type(of: root))).")
            #endif
            ad.present(from: root)
    }

    private func loadAd() async {
        if isLoadingAd || isAdAvailable() { return }
        guard await AdMobService.ensureReadyForAds() else { return }

        isLoadingAd = true
        defer { isLoadingAd = false }

        do {
            let ad = try await AppOpenAd.load(
                with: AdMobConfiguration.resolvedAppOpenAdUnitID,
                request: AdMobService.makeAdRequest()
            )
            ad.fullScreenContentDelegate = self
            appOpenAd = ad
            loadTime = Date()
            #if DEBUG
            print("[AdMob] App open loaded.")
            #endif
        } catch {
            appOpenAd = nil
            loadTime = nil
            #if DEBUG
            print("[AdMob] App open load failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func isAdAvailable() -> Bool {
        guard appOpenAd != nil, let loadTime else { return false }
        let isFresh = Date().timeIntervalSince(loadTime) < adExpirationInterval
        if isFresh == false {
            appOpenAd = nil
            self.loadTime = nil
        }
        return isFresh
    }

    private func cleanupAfterPresentation() {
        appOpenAd = nil
        loadTime = nil
        isShowingAd = false
        didRecordImpression = false
        AdMobFullScreenGate.release()
        Task { await loadAd() }
    }

    private func recordSuccessfulImpression() {
        guard didRecordImpression == false else { return }
        didRecordImpression = true
        AnalyticsService.shared.log(.appOpenAdShown)
        AnalyticsService.shared.recordAdImpression("app_open")
    }
    #endif

    private func shouldShow(forOpenNumber openNumber: Int) -> Bool {
        guard openNumber > 0 else { return false }
        // 1,2 yes · 3 no · 4,5 yes · 6 no …
        return openNumber % openCadenceCycle != 0
    }

    @discardableResult
    private func recordOpenAndReturnCount() -> Int {
        let defaults = UserDefaults.standard
        let next = defaults.integer(forKey: openCountKey) + 1
        defaults.set(next, forKey: openCountKey)
        return next
    }

    /// Increment once per process launch (called from ContentView). Kept for analytics continuity.
    func recordLaunch() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: launchCountKey) + 1, forKey: launchCountKey)
    }

    private func logSkip(_ reason: String) {
        AnalyticsService.shared.log(.appOpenSkipped(reason: reason))
        #if DEBUG
        print("[AdMob] App open skipped: \(reason)")
        #endif
    }
}

#if canImport(GoogleMobileAds)
extension AdMobAppOpenService: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        recordSuccessfulImpression()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if isShowingAd {
            cleanupAfterPresentation()
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[AdMob] App open failed to present: \(error.localizedDescription)")
        #endif
        AnalyticsService.shared.log(.appOpenAdFailed(reason: error.localizedDescription))
        cleanupAfterPresentation()
    }
}
#endif
