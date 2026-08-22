//
//  AdMobInterstitialService.swift
//  Student Attendance Predictor
//
//  Full-screen interstitials at natural breakpoints (first Insights / Overview
//  visit and first Subjects open per launch). Never after Mark Today — that
//  habit loop stays clean. Frequency caps (~90s, 3/session, 6/day in release)
//  keep volume from feeling spammy.
//

import Foundation
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AdMobInterstitialService: NSObject {
    static let shared = AdMobInterstitialService()

    /// Whether an interstitial is loaded and ready to present immediately.
    private(set) var isReady = false

    /// Minimum time between two interstitial presentations.
    #if DEBUG
    private let minIntervalBetweenAds: TimeInterval = 30
    #else
    private let minIntervalBetweenAds: TimeInterval = 90
    #endif
    /// Max interstitials per app launch (Insights + Overview + Subjects).
    private let maxPerSession = 3
    /// Max interstitials per calendar day.
    private let maxPerDay = 6

    private let lastShownKey = "ads.interstitial.lastShown"
    private let dailyCountKey = "ads.interstitial.dailyCount"
    private let dailyCountDateKey = "ads.interstitial.dailyCountDate"

    private var sessionCount = 0
    /// Each main exploration surface fires at most once per process launch.
    private var didShowInsightsInterstitialThisSession = false
    private var didShowOverviewInterstitialThisSession = false
    private var didShowSubjectsInterstitialThisSession = false
    private var sdkReadyObserver: NSObjectProtocol?

    #if canImport(GoogleMobileAds)
    private var interstitialAd: InterstitialAd?
    private var presentingAd: InterstitialAd?
    private var loadTask: Task<Void, Never>?
    private var loadTime: Date?
    private var pendingPlacement: String?
    private var didRecordThisPresentation = false

    /// Rewarded/interstitial ads should not be kept for more than about one hour.
    private let adExpirationInterval: TimeInterval = 55 * 60
    private let maxLoadAttempts = 3
    private let retryDelayNanoseconds: UInt64 = 2_000_000_000
    #endif

    private override init() {
        super.init()
        sdkReadyObserver = NotificationCenter.default.addObserver(
            forName: .adMobSDKDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.preload()
        }
    }

    deinit {
        if let sdkReadyObserver {
            NotificationCenter.default.removeObserver(sdkReadyObserver)
        }
    }

    func preload() {
        #if canImport(GoogleMobileAds)
        Task { await ensureLoaded() }
        #endif
    }

    /// Legacy placement — Mark Today no longer triggers interstitials (habit-loop protection).
    @available(*, deprecated, message: "Do not call after Mark Today; use tryShowAfterInsightsOpened / Overview instead.")
    func tryShowAfterDayMarked() {
        tryShow(placement: AdMobConfiguration.Placement.afterDayMarked)
    }

    /// Shows an interstitial on the first Insights visit this launch (natural tab transition).
    func tryShowAfterInsightsOpened() {
        guard didShowInsightsInterstitialThisSession == false else { return }
        didShowInsightsInterstitialThisSession = true
        tryShow(placement: AdMobConfiguration.Placement.afterInsightsOpened)
    }

    /// Shows an interstitial on the first Overview visit this launch (natural tab transition).
    func tryShowAfterOverviewOpened() {
        guard didShowOverviewInterstitialThisSession == false else { return }
        didShowOverviewInterstitialThisSession = true
        tryShow(placement: AdMobConfiguration.Placement.afterOverviewOpened)
    }

    /// Shows an interstitial the first time Subjects is opened this launch.
    func tryShowAfterSubjectsOpened() {
        guard didShowSubjectsInterstitialThisSession == false else { return }
        didShowSubjectsInterstitialThisSession = true
        tryShow(placement: AdMobConfiguration.Placement.afterSubjectsOpened)
    }

    /// Attempts to present a loaded interstitial when frequency caps and entitlements allow.
    func tryShow(placement: String) {
        #if canImport(GoogleMobileAds)
        Task { @MainActor in
            if presentingAd != nil || AdMobFullScreenGate.isOccupied {
                logSkip(placement: placement, reason: "already_showing")
                return
            }
            if AdEntitlementsStore.shared.areBannersHidden {
                logSkip(placement: placement, reason: "ads_removed_reward_active")
                return
            }
            if canShowUnderFrequencyCap() == false {
                logSkip(placement: placement, reason: "frequency_cap")
                return
            }
            guard await AdMobService.ensureReadyForAds() else {
                logSkip(placement: placement, reason: "consent_or_sdk_not_ready")
                return
            }

            discardExpiredAdIfNeeded(placement: placement)

            if interstitialAd == nil {
                await ensureLoaded()
                discardExpiredAdIfNeeded(placement: placement)
            }

            guard let ad = interstitialAd else {
                logSkip(placement: placement, reason: "not_loaded")
                AnalyticsService.shared.log(.interstitialAdFailed(placement: placement, reason: "not_loaded"))
                return
            }

            // Let SwiftUI finish the tap animation before taking over the screen.
            try? await Task.sleep(nanoseconds: 280_000_000)

            guard AdMobFullScreenGate.tryAcquire() else {
                logSkip(placement: placement, reason: "fullscreen_gate_busy")
                return
            }

            let root = await AdMobPresentation.waitForRoot()
            guard let root else {
                AdMobFullScreenGate.release()
                logSkip(placement: placement, reason: "root_view_controller_nil")
                AnalyticsService.shared.log(.interstitialAdFailed(placement: placement, reason: "root_view_controller_nil"))
                return
            }

            // Re-check availability after the short wait — avoid presenting a stale ref.
            guard presentingAd == nil else {
                AdMobFullScreenGate.release()
                logSkip(placement: placement, reason: "already_showing")
                return
            }

            interstitialAd = nil
            loadTime = nil
            isReady = false
            presentingAd = ad
            pendingPlacement = placement
            didRecordThisPresentation = false
            ad.fullScreenContentDelegate = self
            AnalyticsService.shared.log(.interstitialAdRequested(placement: placement))

            #if DEBUG
            print("[AdMob] Interstitial presenting from \(String(describing: type(of: root))).")
            #endif
            ad.present(from: root)
        }
        #endif
    }

    private func logSkip(placement: String, reason: String) {
        AnalyticsService.shared.log(.interstitialSkipped(placement: placement, reason: reason))
        #if DEBUG
        print("[AdMob] Interstitial skipped (\(placement)): \(reason)")
        #endif
    }

    #if canImport(GoogleMobileAds)
    private func ensureLoaded() async {
        discardExpiredAdIfNeeded(placement: "preload")
        if interstitialAd != nil { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await loadWithRetry() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func loadWithRetry() async {
        guard await AdMobService.ensureReadyForAds() else { return }

        for attempt in 1...maxLoadAttempts {
            do {
                let ad = try await InterstitialAd.load(
                    with: AdMobConfiguration.resolvedInterstitialAdUnitID,
                    request: AdMobService.makeAdRequest()
                )
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
                loadTime = Date()
                isReady = true
                #if DEBUG
                print("[AdMob] Interstitial loaded.")
                #endif
                return
            } catch {
                interstitialAd = nil
                loadTime = nil
                isReady = false
                #if DEBUG
                print("[AdMob] Interstitial load failed (attempt \(attempt)/\(maxLoadAttempts)): \(error.localizedDescription)")
                #endif
                if attempt < maxLoadAttempts {
                    try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                }
            }
        }
    }

    private func cleanupAfterPresentation() {
        pendingPlacement = nil
        presentingAd = nil
        didRecordThisPresentation = false
        AdMobFullScreenGate.release()
        Task { await ensureLoaded() }
    }

    private func discardExpiredAdIfNeeded(placement: String) {
        guard let loadTime, interstitialAd != nil else { return }
        if Date().timeIntervalSince(loadTime) >= adExpirationInterval {
            interstitialAd = nil
            self.loadTime = nil
            isReady = false
            logSkip(placement: placement, reason: "expired")
        }
    }

    private func recordSuccessfulPresentation() {
        guard didRecordThisPresentation == false else { return }
        didRecordThisPresentation = true
        recordShown()
        if let placement = pendingPlacement {
            AnalyticsService.shared.log(.interstitialAdShown(placement: placement))
            AnalyticsService.shared.recordAdImpression("interstitial", placement: placement)
        }
    }
    #endif

    private func canShowUnderFrequencyCap() -> Bool {
        if sessionCount >= maxPerSession { return false }

        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        if let storedDay = defaults.object(forKey: dailyCountDateKey) as? Date,
           Calendar.current.isDate(storedDay, inSameDayAs: today) {
            if defaults.integer(forKey: dailyCountKey) >= maxPerDay { return false }
        }

        if let lastShown = defaults.object(forKey: lastShownKey) as? Date,
           Date().timeIntervalSince(lastShown) < minIntervalBetweenAds {
            return false
        }

        return true
    }

    private func recordShown() {
        sessionCount += 1
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: lastShownKey)

        let today = Calendar.current.startOfDay(for: Date())
        if let storedDay = defaults.object(forKey: dailyCountDateKey) as? Date,
           Calendar.current.isDate(storedDay, inSameDayAs: today) {
            defaults.set(defaults.integer(forKey: dailyCountKey) + 1, forKey: dailyCountKey)
        } else {
            defaults.set(today, forKey: dailyCountDateKey)
            defaults.set(1, forKey: dailyCountKey)
        }
    }
}

#if canImport(GoogleMobileAds)
extension AdMobInterstitialService: FullScreenContentDelegate {
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        recordSuccessfulPresentation()
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        if let placement = pendingPlacement {
            AnalyticsService.shared.log(.interstitialAdClicked(placement: placement))
            AnalyticsService.shared.recordAdImpression("interstitial_click", placement: placement)
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        cleanupAfterPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[AdMob] Interstitial failed to present: \(error.localizedDescription)")
        #endif
        if let placement = pendingPlacement {
            AnalyticsService.shared.log(.interstitialAdFailed(placement: placement, reason: error.localizedDescription))
        }
        cleanupAfterPresentation()
    }
}
#endif
