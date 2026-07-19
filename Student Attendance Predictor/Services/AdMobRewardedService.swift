//
//  AdMobRewardedService.swift
//  Student Attendance Predictor
//
//  Loads and presents rewarded ads. The completion fires with `true` only if the
//  user actually earned the reward (watched enough of the ad).
//

import Foundation
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AdMobRewardedService: NSObject {
    static let shared = AdMobRewardedService()

    /// Whether a rewarded ad is loaded and ready to present immediately.
    private(set) var isReady = false

    #if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    /// Strong reference to the ad while it's on screen (the SDK delegate is weak).
    private var presentingAd: RewardedAd?
    /// In-flight load, so concurrent callers await the same request instead of racing.
    private var loadTask: Task<Void, Never>?
    private var loadTime: Date?
    private var rewardEarned = false
    private var pendingCompletion: ((Bool) -> Void)?

    /// Rewarded/interstitial ads should not be kept for more than about one hour.
    private let adExpirationInterval: TimeInterval = 55 * 60
    private let maxLoadAttempts = 3
    private let retryDelayNanoseconds: UInt64 = 2_000_000_000
    #endif

    private override init() {
        super.init()
    }

    /// Begin loading a rewarded ad so it's ready when the user taps a reward button.
    func preload() {
        #if canImport(GoogleMobileAds)
        Task { await ensureLoaded() }
        #endif
    }

    /// Presents a rewarded ad. `completion(true)` means the reward was earned.
    func showAd(placement: String = "unknown", completion: @escaping (Bool) -> Void) {
        #if canImport(GoogleMobileAds)
        Task { @MainActor in
            guard presentingAd == nil else {
                logShowBlocked("already_showing", placement: placement)
                completion(false)
                return
            }
            guard await AdMobService.ensureReadyForAds() else {
                logShowBlocked("consent_or_sdk_not_ready", placement: placement)
                completion(false)
                return
            }

            discardExpiredAdIfNeeded(placement: placement)

            if rewardedAd == nil {
                await ensureLoaded()
                discardExpiredAdIfNeeded(placement: placement)
            }

            guard let ad = rewardedAd else {
                logShowBlocked("not_loaded", placement: placement)
                completion(false)
                return
            }

            guard AdMobFullScreenGate.tryAcquire() else {
                logShowBlocked("fullscreen_gate_busy", placement: placement)
                completion(false)
                return
            }

            let root = await AdMobPresentation.waitForRoot()
            guard let root else {
                AdMobFullScreenGate.release()
                logShowBlocked("root_view_controller_nil", placement: placement)
                completion(false)
                return
            }

            // Hand off to the presenting slot so the loaded slot can reload.
            rewardedAd = nil
            loadTime = nil
            isReady = false
            presentingAd = ad
            rewardEarned = false
            pendingCompletion = completion
            ad.fullScreenContentDelegate = self
            #if DEBUG
            print("[AdMob] Rewarded presenting from \(String(describing: type(of: root))).")
            #endif
            ad.present(from: root) { [weak self] in
                self?.rewardEarned = true
            }
        }
        #else
        completion(false)
        #endif
    }

    #if canImport(GoogleMobileAds)
    /// Ensures a rewarded ad is loaded; dedupes concurrent callers onto one request.
    private func ensureLoaded() async {
        discardExpiredAdIfNeeded(placement: "preload")
        if rewardedAd != nil { return }
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
                let ad = try await RewardedAd.load(
                    with: AdMobConfiguration.resolvedRewardedAdUnitID,
                    request: AdMobService.makeAdRequest()
                )
                rewardedAd = ad
                loadTime = Date()
                isReady = true
                #if DEBUG
                print("[AdMob] Rewarded loaded.")
                #endif
                return
            } catch {
                rewardedAd = nil
                loadTime = nil
                isReady = false
                #if DEBUG
                print("[AdMob] Rewarded load failed (attempt \(attempt)/\(maxLoadAttempts)): \(error.localizedDescription)")
                #endif
                if attempt < maxLoadAttempts {
                    try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                }
            }
        }
    }

    private func finish(earned: Bool) {
        let completion = pendingCompletion
        pendingCompletion = nil
        presentingAd = nil
        AdMobFullScreenGate.release()
        completion?(earned)
        Task { await ensureLoaded() }
    }

    private func discardExpiredAdIfNeeded(placement: String) {
        guard let loadTime, rewardedAd != nil else { return }
        if Date().timeIntervalSince(loadTime) >= adExpirationInterval {
            rewardedAd = nil
            self.loadTime = nil
            isReady = false
            logShowBlocked("expired", placement: placement)
        }
    }

    private func logShowBlocked(_ reason: String, placement: String) {
        AnalyticsService.shared.log(.rewardedAdFailed(placement: placement, reason: reason))
        #if DEBUG
        print("[AdMob] Rewarded show blocked (\(placement)): \(reason)")
        #endif
    }
    #endif
}

#if canImport(GoogleMobileAds)
extension AdMobRewardedService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish(earned: rewardEarned)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[AdMob] Rewarded failed to present: \(error.localizedDescription)")
        #endif
        finish(earned: false)
    }
}
#endif
