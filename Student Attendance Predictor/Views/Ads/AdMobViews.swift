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

// MARK: - SDK bootstrap

enum AdMobService {
    #if canImport(GoogleMobileAds)
    @MainActor
    private static var isStarted = false
    private static var readyContinuations: [CheckedContinuation<Void, Never>] = []

    static var isReady: Bool { isStarted }

    static func startIfNeeded() {
        Task { @MainActor in
            await start()
        }
    }

    @MainActor
    static func start() async {
        if isStarted { return }
        await withCheckedContinuation { continuation in
            readyContinuations.append(continuation)
            guard readyContinuations.count == 1 else { return }
            Task { @MainActor in
                // ATT must finish before UMP or Mobile Ads — otherwise IDFA is read too early.
                await AppTrackingService.requestAuthorizationIfNeeded()
                applyRequestConfigurationForTracking()
                await AdMobConsentService.gatherConsentIfNeeded()
                guard AdMobConsentService.canRequestAds else {
                    completeStartup()
                    return
                }
                MobileAds.shared.start { _ in
                    Task { @MainActor in
                        completeStartup()
                    }
                }
            }
        }
    }

    @MainActor
    private static func completeStartup() {
        isStarted = true
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
    #else
    static func startIfNeeded() {}
    static var isReady: Bool { false }
    static func start() async {}
    #endif
}

// MARK: - Native advanced (UIViewController host — reliable rootViewController + layout)

struct AdMobNativeCard: View {
    let placement: String

    init(placement: String) {
        self.placement = placement
    }

    var body: some View {
        #if canImport(GoogleMobileAds)
        AdMobNativeCardContainer(placement: placement)
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdMobNativeCardContainer: View {
    let placement: String
    @State private var isLoaded = false

    var body: some View {
        AdMobNativeCardHost(placement: placement, isLoaded: $isLoaded)
            .frame(maxWidth: .infinity)
            .frame(height: isLoaded ? NativeAdLayout.cardHeight : 0)
            .clipped()
    }
}

private struct AdMobNativeCardHost: UIViewControllerRepresentable {
    let placement: String
    @Binding var isLoaded: Bool

    func makeUIViewController(context: Context) -> AdMobNativeHostViewController {
        let controller = AdMobNativeHostViewController(placement: placement)
        controller.onLoadStateChanged = { loaded in
            Task { @MainActor in
                isLoaded = loaded
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: AdMobNativeHostViewController, context: Context) {}
}

/// Loads and displays a native ad using `self` as `rootViewController` (required by AdMob).
private final class AdMobNativeHostViewController: UIViewController, NativeAdLoaderDelegate, NativeAdDelegate {
    private let placement: String
    private var adLoader: AdLoader?
    private let nativeAdView = BunkPlannerNativeAdView()
    private var isRequesting = false
    private var retryCount = 0
    private let maxRetries = 4
    var onLoadStateChanged: ((Bool) -> Void)?

    init(placement: String) {
        self.placement = placement
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        installNativeAdView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await requestAdIfNeeded() }
    }

    private func installNativeAdView() {
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.isHidden = true
        view.addSubview(nativeAdView)
        NSLayoutConstraint.activate([
            nativeAdView.topAnchor.constraint(equalTo: view.topAnchor),
            nativeAdView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeAdView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            nativeAdView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @MainActor
    private func requestAdIfNeeded() async {
        await AdMobService.start()
        guard AdMobConsentService.canRequestAds else { return }
        guard !isRequesting, nativeAdView.nativeAd == nil else { return }
        isRequesting = true

        adLoader = AdLoader(
            adUnitID: AdMobConfiguration.resolvedNativeAdUnitID,
            rootViewController: self,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        adLoader?.load(AdMobService.makeAdRequest())
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            isRequesting = false
            retryCount = 0
            nativeAd.delegate = self
            nativeAdView.populate(with: nativeAd)
            nativeAdView.isHidden = false
            onLoadStateChanged?(true)
            #if DEBUG
            print("[AdMob] Native (\(placement)) loaded.")
            #endif
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            isRequesting = false
            #if DEBUG
            print("[AdMob] Native (\(placement)) failed: \(error.localizedDescription)")
            #endif
            guard retryCount < maxRetries else {
                onLoadStateChanged?(false)
                return
            }
            retryCount += 1
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await requestAdIfNeeded()
        }
    }

    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        #if DEBUG
        print("[AdMob] Native (\(placement)) loader finished.")
        #endif
    }
}

private enum NativeAdLayout {
    /// AdMob requires MediaView ≥ 120×120 pt when video can be shown.
    static let mediaMinSide: CGFloat = 120
    static let cardHeight: CGFloat = 300
    static let cardPadding: CGFloat = 14
}

/// Programmatic native layout styled like app cards; includes required “Ad” attribution.
private final class BunkPlannerNativeAdView: NativeAdView {
    private let attributionLabel = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let media = MediaView()
    private let iconImageView = UIImageView()
    private let ctaLabel = UILabel()
    private let cardBackground = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureHierarchy()
    }

    private func configureHierarchy() {
        backgroundColor = .clear

        cardBackground.translatesAutoresizingMaskIntoConstraints = false
        cardBackground.backgroundColor = UIColor(white: 1, alpha: 0.06)
        cardBackground.layer.cornerRadius = 20
        cardBackground.layer.cornerCurve = .continuous
        cardBackground.layer.borderWidth = 1
        cardBackground.layer.borderColor = UIColor(white: 1, alpha: 0.12).cgColor
        addSubview(cardBackground)

        attributionLabel.translatesAutoresizingMaskIntoConstraints = false
        attributionLabel.text = "Ad"
        attributionLabel.font = .systemFont(ofSize: 10, weight: .black)
        attributionLabel.textColor = UIColor(white: 1, alpha: 0.55)
        attributionLabel.textAlignment = .center
        attributionLabel.backgroundColor = UIColor(white: 1, alpha: 0.12)
        attributionLabel.layer.cornerRadius = 6
        attributionLabel.layer.cornerCurve = .continuous
        attributionLabel.clipsToBounds = true

        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headlineLabel.textColor = .white
        headlineLabel.numberOfLines = 2

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        bodyLabel.textColor = UIColor(white: 1, alpha: 0.75)
        bodyLabel.numberOfLines = 2

        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        advertiserLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        advertiserLabel.textColor = UIColor(white: 1, alpha: 0.5)

        media.translatesAutoresizingMaskIntoConstraints = false
        media.contentMode = .scaleAspectFit
        media.clipsToBounds = true
        media.setContentHuggingPriority(.defaultLow, for: .horizontal)
        media.setContentCompressionResistancePriority(.required, for: .horizontal)
        media.setContentCompressionResistancePriority(.required, for: .vertical)
        media.layer.cornerRadius = 12
        media.layer.cornerCurve = .continuous

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 8
        iconImageView.clipsToBounds = true

        ctaLabel.translatesAutoresizingMaskIntoConstraints = false
        ctaLabel.font = .systemFont(ofSize: 12, weight: .bold)
        ctaLabel.textColor = UIColor(red: 0.32, green: 0.84, blue: 1.0, alpha: 1)
        ctaLabel.textAlignment = .right

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel, advertiserLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [attributionLabel, textStack])
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.alignment = .top
        topRow.translatesAutoresizingMaskIntoConstraints = false

        attributionLabel.setContentHuggingPriority(.required, for: .horizontal)
        attributionLabel.widthAnchor.constraint(equalToConstant: 28).isActive = true
        attributionLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let bottomRow = UIStackView(arrangedSubviews: [iconImageView, ctaLabel])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 10
        bottomRow.alignment = .center
        bottomRow.translatesAutoresizingMaskIntoConstraints = false

        iconImageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true

        cardBackground.addSubview(topRow)
        cardBackground.addSubview(media)
        cardBackground.addSubview(bottomRow)

        let padding = NativeAdLayout.cardPadding
        let mediaSide = NativeAdLayout.mediaMinSide

        NSLayoutConstraint.activate([
            cardBackground.topAnchor.constraint(equalTo: topAnchor),
            cardBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardBackground.bottomAnchor.constraint(equalTo: bottomAnchor),

            topRow.topAnchor.constraint(equalTo: cardBackground.topAnchor, constant: padding),
            topRow.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: padding),
            topRow.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -padding),

            media.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: 12),
            media.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: padding),
            media.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -padding),
            media.heightAnchor.constraint(equalToConstant: mediaSide),
            media.widthAnchor.constraint(greaterThanOrEqualToConstant: mediaSide),

            bottomRow.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 12),
            bottomRow.leadingAnchor.constraint(equalTo: cardBackground.leadingAnchor, constant: padding),
            bottomRow.trailingAnchor.constraint(equalTo: cardBackground.trailingAnchor, constant: -padding),
            bottomRow.bottomAnchor.constraint(equalTo: cardBackground.bottomAnchor, constant: -padding),
        ])

        headlineView = headlineLabel
        bodyView = bodyLabel
        advertiserView = advertiserLabel
        mediaView = media
        iconView = iconImageView
        callToActionView = ctaLabel
        callToActionView?.isUserInteractionEnabled = false
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: NativeAdLayout.cardHeight)
    }

    func populate(with nativeAd: NativeAd) {
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        bodyLabel.isHidden = nativeAd.body == nil
        advertiserLabel.text = nativeAd.advertiser
        advertiserLabel.isHidden = nativeAd.advertiser == nil
        ctaLabel.text = nativeAd.callToAction
        ctaLabel.isHidden = nativeAd.callToAction == nil
        iconImageView.image = nativeAd.icon?.image
        iconImageView.isHidden = nativeAd.icon == nil

        // MediaView must stay visible and ≥120×120 pt for AdMob validation (especially video).
        media.isHidden = false
        media.mediaContent = nativeAd.mediaContent

        layoutIfNeeded()
        self.nativeAd = nativeAd
    }
}
#endif

#if canImport(UIKit)
@MainActor
extension UIApplication {
    static var topViewController: UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                return topMostViewController(from: root)
            }
        }
        guard let root = scenes.first?.windows.first?.rootViewController else { return nil }
        return topMostViewController(from: root)
    }

    private static func topMostViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topMostViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return controller
    }
}
#endif
