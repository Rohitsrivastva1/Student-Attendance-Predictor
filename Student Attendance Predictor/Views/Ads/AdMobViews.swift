//
//  AdMobViews.swift
//  Student Attendance Predictor
//

import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UIKit)
import UIKit
#endif

extension Notification.Name {
    /// Posted when the AdMob SDK becomes ready to load ads (e.g. after consent is granted).
    static let adMobSDKDidBecomeReady = Notification.Name("ads.sdkDidBecomeReady")
}

// MARK: - SDK bootstrap

enum AdMobService {
    #if canImport(GoogleMobileAds)
    /// ATT + UMP consent flow has finished (success or blocked).
    @MainActor
    private static var isStartupSequenceComplete = false
    /// `MobileAds.shared.start()` completed — required before any ad load.
    @MainActor
    private static var isMobileAdsSDKStarted = false
    @MainActor
    private static var hasRequestedTrackingPermission = false
    private static var readyContinuations: [CheckedContinuation<Void, Never>] = []

    static var isReady: Bool { isMobileAdsSDKStarted }

    static func startIfNeeded() {
        Task { @MainActor in
            requestTrackingPermission()
        }
    }

    @MainActor
    static func requestTrackingPermission() {
        guard isStartupSequenceComplete == false, hasRequestedTrackingPermission == false else { return }
        hasRequestedTrackingPermission = true

        AppTrackingService.requestTrackingPermission { _ in
            Task { @MainActor in
                applyRequestConfigurationForTracking()
                await AdMobConsentService.gatherConsentIfNeeded()
                await startMobileAdsSDKIfAllowed()
                completeStartupSequence()
            }
        }
    }

    @MainActor
    static func start() async {
        if isStartupSequenceComplete { return }
        await withCheckedContinuation { continuation in
            readyContinuations.append(continuation)
            requestTrackingPermission()
        }
    }

    /// Waits for ATT/consent, then starts the AdMob SDK when ads may be requested.
    /// Safe to call again after the user changes ad privacy choices in Settings.
    @MainActor
    static func ensureReadyForAds() async -> Bool {
        await start()
        return await startMobileAdsSDKIfAllowed()
    }

    @MainActor
    @discardableResult
    private static func startMobileAdsSDKIfAllowed() async -> Bool {
        guard AdMobConsentService.canRequestAds else { return false }
        guard isMobileAdsSDKStarted == false else { return true }
        applyRequestConfigurationForTracking()
        await MobileAds.shared.start()
        isMobileAdsSDKStarted = true
        NotificationCenter.default.post(name: .adMobSDKDidBecomeReady, object: nil)
        #if DEBUG
        print("[AdMob] SDK started.")
        #endif
        return true
    }

    @MainActor
    private static func completeStartupSequence() {
        isStartupSequenceComplete = true
        let pending = readyContinuations
        readyContinuations.removeAll()
        pending.forEach { $0.resume() }
    }

    /// Global ad privacy before `MobileAds.shared.start()` (required when ATT is not authorized).
    @MainActor
    private static func applyRequestConfigurationForTracking() {
        let configuration = MobileAds.shared.requestConfiguration
        if AppTrackingService.allowsPersonalizedAds {
            configuration.publisherPrivacyPersonalizationState = .default
        } else {
            configuration.publisherPrivacyPersonalizationState = .disabled
        }
    }

    /// Contextual (non‑IDFA) request when tracking is denied, restricted, or not authorized.
    @MainActor
    static func makeAdRequest() -> Request {
        let request = Request()
        if !AppTrackingService.allowsPersonalizedAds {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        return request
    }

    /// Stable short reason for analytics from a Google Mobile Ads error.
    static func analyticsReason(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain.contains("GAD") || ns.domain.lowercased().contains("google") {
            return "gad_\(ns.code)"
        }
        let text = error.localizedDescription.lowercased()
        if text.contains("no fill") || text.contains("no ad") { return "no_fill" }
        if text.contains("network") { return "network" }
        if text.contains("consent") { return "consent" }
        return String(text.prefix(40))
    }
    #else
    static func startIfNeeded() {}
    static func requestTrackingPermission() {}
    static var isReady: Bool { false }
    static func start() async {}
    static func ensureReadyForAds() async -> Bool { false }
    static func analyticsReason(for error: Error) -> String { "unknown" }
    #endif
}

// MARK: - Anchored adaptive banner

/// Drop-in banner slot. Collapses until filled. Loads only after the slot stays
/// active ~1.5s (skips quick tab flips). All placements share the Home unit.
struct AdMobBannerCard: View {
    let placement: String
    /// When false, the host pauses the banner and does not issue new requests.
    var isActive: Bool = true
    @ObservedObject private var entitlements = AdEntitlementsStore.shared

    init(placement: String, isActive: Bool = true) {
        self.placement = placement
        self.isActive = isActive
    }

    var body: some View {
        #if canImport(GoogleMobileAds)
        if entitlements.areBannersHidden {
            EmptyView()
        } else {
            AdMobBannerContainer(placement: placement, isActive: isActive)
        }
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdMobBannerContainer: View {
    let placement: String
    let isActive: Bool
    @State private var isLoaded = false
    @State private var adHeight: CGFloat = 0

    var body: some View {
        AdMobBannerHost(placement: placement, isActive: isActive, isLoaded: $isLoaded, adHeight: $adHeight)
            .frame(maxWidth: .infinity)
            .frame(height: isLoaded ? adHeight : 0)
            .clipped()
    }
}

private struct AdMobBannerHost: UIViewControllerRepresentable {
    let placement: String
    let isActive: Bool
    @Binding var isLoaded: Bool
    @Binding var adHeight: CGFloat

    func makeUIViewController(context: Context) -> AdMobBannerHostViewController {
        // Pass real isActive up front — defaulting to true caused inactive tabs to request.
        let controller = AdMobBannerHostViewController(placement: placement, isActive: isActive)
        controller.onLoadStateChanged = { loaded, height in
            Task { @MainActor in
                adHeight = height
                isLoaded = loaded
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: AdMobBannerHostViewController, context: Context) {
        uiViewController.setActive(isActive)
    }
}

/// Loads an anchored adaptive banner after a short dwell on an active tab.
/// One quick retry, then a slow recover loop while the slot stays visible.
/// Tracks `banner_visible_seconds` while filled + active.
private final class AdMobBannerHostViewController: UIViewController, BannerViewDelegate {
    private let placement: String
    private var bannerView: BannerView?
    private var hasRequested = false
    private var isLoading = false
    private var isActive: Bool
    private var hasFilledAd = false
    /// True after a consent/SDK block — stop layout retries until SDK becomes ready.
    private var isWaitingForSDKReady = false
    private var didLogConsentSkip = false
    private var loadedWidth: CGFloat = 0
    private var retryCount = 0
    private var isCurrentLoadARetry = false
    private let maxQuickRetries = 1
    /// Ignore flick-through tab switches before spending a network request.
    private let dwellBeforeRequestNanoseconds: UInt64 = 1_500_000_000
    /// Backoff when inventory returns no-fill (GAD error code 3).
    private let noFillRetryNanoseconds: UInt64 = 30_000_000_000
    private let defaultRetryNanoseconds: UInt64 = 5_000_000_000
    /// After quick retries are exhausted, keep trying while visible (AdMob-safe pace).
    private let recoverRetryNanoseconds: UInt64 = 60_000_000_000
    private var dwellTask: Task<Void, Never>?
    private var recoverTask: Task<Void, Never>?
    var onLoadStateChanged: ((Bool, CGFloat) -> Void)?
    private var sdkReadyObserver: NSObjectProtocol?

    private var visibilityStartedAt: Date?
    private var accumulatedVisibleSeconds = 0

    init(placement: String, isActive: Bool) {
        self.placement = placement
        self.isActive = isActive
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        sdkReadyObserver = NotificationCenter.default.addObserver(
            forName: .adMobSDKDidBecomeReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isWaitingForSDKReady = false
            self.didLogConsentSkip = false
            self.scheduleLoadAfterDwell()
        }
        if isActive {
            scheduleLoadAfterDwell()
        }
    }

    deinit {
        dwellTask?.cancel()
        recoverTask?.cancel()
        if let start = visibilityStartedAt {
            accumulatedVisibleSeconds += max(0, Int(Date().timeIntervalSince(start)))
            visibilityStartedAt = nil
        }
        let seconds = accumulatedVisibleSeconds
        let placement = self.placement
        if seconds > 0 {
            Task { @MainActor in
                AnalyticsService.shared.log(.bannerVisibleSeconds(placement: placement, seconds: seconds))
            }
        }
        if let sdkReadyObserver {
            NotificationCenter.default.removeObserver(sdkReadyObserver)
        }
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        if active {
            scheduleLoadAfterDwell()
            if hasFilledAd {
                bannerView?.delegate = self
                beginVisibilityTracking()
            } else if hasRequested, bannerView != nil {
                // Slot became visible again with an empty banner — recover.
                scheduleRecoverReload()
            }
        } else {
            dwellTask?.cancel()
            dwellTask = nil
            recoverTask?.cancel()
            recoverTask = nil
            // Keep a filled banner for when the user returns — do not reload.
            bannerView?.delegate = nil
            endVisibilityTrackingAndFlush()
        }
    }

    private func beginVisibilityTracking() {
        guard isActive, hasFilledAd, visibilityStartedAt == nil else { return }
        visibilityStartedAt = Date()
    }

    private func endVisibilityTrackingAndFlush() {
        if let start = visibilityStartedAt {
            accumulatedVisibleSeconds += max(0, Int(Date().timeIntervalSince(start)))
            visibilityStartedAt = nil
        }
        guard accumulatedVisibleSeconds > 0 else { return }
        let seconds = accumulatedVisibleSeconds
        accumulatedVisibleSeconds = 0
        AnalyticsService.shared.log(.bannerVisibleSeconds(placement: placement, seconds: seconds))
    }

    private func scheduleLoadAfterDwell() {
        guard isActive else { return }
        guard isWaitingForSDKReady == false else { return }
        guard hasRequested == false, isLoading == false, hasFilledAd == false else { return }
        dwellTask?.cancel()
        dwellTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.dwellBeforeRequestNanoseconds ?? 1_500_000_000)
            guard let self, Task.isCancelled == false else { return }
            guard self.isActive, self.hasRequested == false, self.hasFilledAd == false else { return }
            guard self.isWaitingForSDKReady == false else { return }
            let width = self.availableWidth()
            guard width > 0 else { return }
            await self.loadBanner(width: width)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard isActive else { return }
        let width = availableWidth()
        guard width > 0 else { return }

        if isWaitingForSDKReady {
            return
        }

        if hasRequested == false, isLoading == false, hasFilledAd == false {
            scheduleLoadAfterDwell()
        } else if let bannerView, hasFilledAd, abs(width - loadedWidth) > 1 {
            loadedWidth = width
            bannerView.adSize = adaptiveSize(for: width)
            onLoadStateChanged?(true, bannerView.adSize.size.height)
        }
    }

    private func availableWidth() -> CGFloat {
        if view.bounds.width > 0 { return floor(view.bounds.width) }
        if let window = view.window {
            let insets = window.safeAreaInsets
            return floor(window.bounds.width - insets.left - insets.right)
        }
        return 0
    }

    /// Anchored adaptive — typically stronger fill than capped inline for content slots.
    private func adaptiveSize(for width: CGFloat) -> AdSize {
        let size = currentOrientationAnchoredAdaptiveBanner(width: width)
        return (size.size.width > 0 && size.size.height > 0) ? size : AdSizeBanner
    }

    @MainActor
    private func loadBanner(width: CGFloat) async {
        guard isActive, hasRequested == false, isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }

        guard await AdMobService.ensureReadyForAds() else {
            isWaitingForSDKReady = true
            if didLogConsentSkip == false {
                didLogConsentSkip = true
                AnalyticsService.shared.log(
                    .bannerAdSkipped(placement: placement, reason: "consent_or_sdk_not_ready")
                )
            }
            #if DEBUG
            print("[AdMob] Banner (\(placement)) waiting: consent/SDK not ready.")
            #endif
            return
        }
        isWaitingForSDKReady = false
        guard isActive, hasRequested == false else { return }
        hasRequested = true
        loadedWidth = width

        let banner = BannerView(adSize: adaptiveSize(for: width))
        banner.adUnitID = AdMobConfiguration.resolvedBannerAdUnitID(for: placement)
        banner.rootViewController = self
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        bannerView = banner
        isCurrentLoadARetry = false
        AnalyticsService.shared.log(.bannerAdRequested(placement: placement, isRetry: false))
        banner.load(AdMobService.makeAdRequest())
    }

    // MARK: BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        retryCount = 0
        hasFilledAd = true
        recoverTask?.cancel()
        recoverTask = nil
        bannerView.delegate = self
        onLoadStateChanged?(true, bannerView.adSize.size.height)
        AnalyticsService.shared.log(.bannerAdLoaded(placement: placement))
        if isActive {
            beginVisibilityTracking()
        }
        #if DEBUG
        print("[AdMob] Banner (\(placement)) loaded.")
        #endif
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        AnalyticsService.shared.log(.bannerAdShown(placement: placement))
        AnalyticsService.shared.recordAdImpression("banner")
        beginVisibilityTracking()
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        AnalyticsService.shared.log(.bannerAdClicked(placement: placement))
        AnalyticsService.shared.recordAdImpression("banner_click")
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        hasFilledAd = false
        endVisibilityTrackingAndFlush()
        onLoadStateChanged?(false, 0)
        let reason = AdMobService.analyticsReason(for: error)
        AnalyticsService.shared.log(
            .bannerAdFailed(placement: placement, reason: reason, isRetry: isCurrentLoadARetry)
        )
        #if DEBUG
        print("[AdMob] Banner (\(placement)) failed: \(reason) — \(error.localizedDescription)")
        #endif
        guard isActive else { return }

        if retryCount < maxQuickRetries {
            retryCount += 1
            let delay = Self.isNoFill(reason: reason, error: error)
                ? noFillRetryNanoseconds
                : defaultRetryNanoseconds
            scheduleBannerReload(on: bannerView, afterNanoseconds: delay)
            return
        }

        // Stay alive: retry every 60s while the tab is visible (no-fill is often transient).
        scheduleRecoverReload()
    }

    private func scheduleBannerReload(on bannerView: BannerView, afterNanoseconds: UInt64) {
        dwellTask?.cancel()
        dwellTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: afterNanoseconds)
            guard let self, Task.isCancelled == false else { return }
            guard self.isActive, self.hasFilledAd == false else { return }
            self.isCurrentLoadARetry = true
            AnalyticsService.shared.log(.bannerAdRequested(placement: self.placement, isRetry: true))
            bannerView.load(AdMobService.makeAdRequest())
        }
    }

    private func scheduleRecoverReload() {
        guard isActive, hasFilledAd == false, bannerView != nil else { return }
        recoverTask?.cancel()
        recoverTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.recoverRetryNanoseconds ?? 60_000_000_000)
            guard let self, Task.isCancelled == false else { return }
            guard self.isActive, self.hasFilledAd == false, let banner = self.bannerView else { return }
            self.retryCount = 0
            self.isCurrentLoadARetry = true
            AnalyticsService.shared.log(.bannerAdRequested(placement: self.placement, isRetry: true))
            banner.load(AdMobService.makeAdRequest())
        }
    }

    private static func isNoFill(reason: String, error: Error) -> Bool {
        if reason == "no_fill" || reason == "gad_3" { return true }
        let text = error.localizedDescription.lowercased()
        return text.contains("no fill") || text.contains("no ad to show")
    }
}
#endif

#if canImport(UIKit)
@MainActor
extension UIApplication {
    static var topViewController: UIViewController? {
        AdMobPresentation.presentationRootViewController
    }
}
#endif
