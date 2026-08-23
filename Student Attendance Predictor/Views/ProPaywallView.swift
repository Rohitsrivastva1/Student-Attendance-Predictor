//
//  ProPaywallView.swift
//  Student Attendance Predictor
//
//  Full-screen Pro purchase experience — hero, benefits, purchase, success.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProPaywallView: View {
    var source: String = "settings"
    var onUnlocked: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchaseService = ProPurchaseService.shared
    @ObservedObject private var entitlements = AdEntitlementsStore.shared

    @State private var appearHero = false
    @State private var appearFeatures = false
    @State private var appearCTA = false
    @State private var orbPulse = false
    @State private var crownSpin = false
    @State private var showSuccess = false
    @State private var successBurst = false
    @State private var paywallAppearedAt = Date()
    @State private var didStartPurchase = false
    @State private var didLogPriceShown = false
    @State private var didLogDismiss = false
    @State private var didPurchaseSucceed = false
    @State private var lastFailureWasRestore = false

    private var purchaseAlertTitle: String {
        lastFailureWasRestore ? "Restore Purchases" : "Purchase"
    }

    private var isRestoreFailure: Bool { lastFailureWasRestore }

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let gold = Color(red: 1.0, green: 0.78, blue: 0.28)
    private let warmGlow = Color(red: 1.0, green: 0.62, blue: 0.22)

    private var features: [(icon: String, title: String, subtitle: String)] {
        let skipVerb = StudentMarketStore.current.skipVerb
        let ads = ("sparkles", "Study without interruptions", "Banners and full-screen ads stay gone for good.")
        let forecast = ("chart.line.uptrend.xyaxis", "Semester forecast for every subject", "See where each subject lands before you skip — not just today's %.")
        let subjects = ("books.vertical.fill", "Unlimited subjects", "Free includes \(ProPurchaseConfiguration.freeSubjectLimit). Pro tracks your full timetable.")
        let exports = ("square.and.arrow.up.fill", "PDF + CSV export", "Parent-ready PDF and a spreadsheet of every logged day.")
        let skip = ("calendar.badge.checkmark", "Skip planner", "Tap a future class day and see who stays safe if you \(skipVerb).")
        let focus = ("timer", "Custom Focus Timer", "90-minute sessions, custom lengths, longer breaks, and a weekly study recap.")
        switch source {
        case "forecast", "locked_forecast":
            return [forecast, skip, subjects, exports, focus, ads]
        case "at_risk_week", "at_risk_home", "at_risk_week_3":
            return [forecast, skip, subjects, exports, focus, ads]
        case "subject_limit":
            return [subjects, skip, forecast, exports, focus, ads]
        case "pdf_export", "csv_export":
            return [exports, skip, forecast, subjects, focus, ads]
        case "skip_planner":
            return [skip, forecast, subjects, exports, focus, ads]
        case "focus_custom":
            return [focus, skip, forecast, subjects, exports, ads]
        case "streak_7", "habit_value":
            return [skip, forecast, subjects, exports, focus, ads]
        default:
            return [skip, forecast, subjects, exports, focus, ads]
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if showSuccess {
                successLayer
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
                paywallContent
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            paywallAppearedAt = Date()
            didStartPurchase = false
            didLogPriceShown = false
            didLogDismiss = false
            didPurchaseSucceed = false
            AnalyticsService.shared.setLastProPaywallSource(source)
            AnalyticsService.shared.log(.proPaywallViewed(source: source))
            ProPurchaseService.shared.start()
            Task {
                await purchaseService.loadProduct(surfaceFailure: true)
                if purchaseService.isAvailable {
                    logPriceShownIfNeeded()
                } else {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await purchaseService.loadProduct(surfaceFailure: true)
                    logPriceShownIfNeeded(forceUnavailable: purchaseService.isAvailable == false)
                }
            }
            withAnimation(.easeOut(duration: 0.7)) { appearHero = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.12)) { appearFeatures = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.22)) { appearCTA = true }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { orbPulse = true }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) { crownSpin = true }
        }
        .onDisappear {
            logPaywallDismissedIfNeeded()
        }
        .onChange(of: purchaseService.displayPrice) { _, _ in
            logPriceShownIfNeeded()
        }
        .onChange(of: purchaseService.isAvailable) { _, _ in
            logPriceShownIfNeeded()
        }
        .onChange(of: purchaseService.phase) { _, newPhase in
            if newPhase == .success, entitlements.isPro {
                didPurchaseSucceed = true
                triggerSuccess()
            }
        }
        .alert(
            purchaseAlertTitle,
            isPresented: Binding(
                get: {
                    if case .failed = purchaseService.phase { return true }
                    return false
                },
                set: { presented in
                    if presented == false {
                        purchaseService.clearTransientError()
                    }
                }
            )
        ) {
            if isRestoreFailure == false {
                Button("Try Again") {
                    Task { await retryPurchase() }
                }
            }
            Button("Restore Purchases") {
                Task { await restorePurchases() }
            }
            Button("OK", role: .cancel) {}
        } message: {
            if case let .failed(message) = purchaseService.phase {
                Text(message)
            }
        }
    }

    // MARK: - Layers

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.09),
                    Color(red: 0.06, green: 0.07, blue: 0.13),
                    Color(red: 0.05, green: 0.08, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(gold.opacity(orbPulse ? 0.22 : 0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -90, y: -220)
                .allowsHitTesting(false)

            Circle()
                .fill(cyan.opacity(orbPulse ? 0.20 : 0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 120, y: 260)
                .allowsHitTesting(false)

            Circle()
                .fill(warmGlow.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: 40, y: -40)
                .allowsHitTesting(false)
        }
    }

    private var paywallContent: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    logPaywallDismissedIfNeeded()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    heroSection
                        .opacity(appearHero ? 1 : 0)
                        .offset(y: appearHero ? 0 : 18)

                    featuresSection
                        .opacity(appearFeatures ? 1 : 0)
                        .offset(y: appearFeatures ? 0 : 16)

                    comparisonChip
                        .opacity(appearFeatures ? 1 : 0)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }

            ctaSection
                .opacity(appearCTA ? 1 : 0)
                .offset(y: appearCTA ? 0 : 20)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
                .padding(.top, 8)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.05, blue: 0.09).opacity(0),
                            Color(red: 0.04, green: 0.05, blue: 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                )
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [gold.opacity(0.45), gold.opacity(0.0)],
                            center: .center,
                            startRadius: 10,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(orbPulse ? 1.08 : 0.92)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.86, blue: 0.42),
                                Color(red: 0.95, green: 0.58, blue: 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: gold.opacity(0.55), radius: 22, x: 0, y: 10)
                    .rotationEffect(.degrees(crownSpin ? 2 : -2))

                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
            }

            VStack(spacing: 8) {
                Text("BUNK PLANNER")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(cyan)
                    .tracking(2.4)

                Text(heroHeadline)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(heroSubtitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("No subscriptions.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(gold.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var featuresSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                featureRow(icon: feature.icon, title: feature.title, subtitle: feature.subtitle)
                    .opacity(appearFeatures ? 1 : 0)
                    .offset(y: appearFeatures ? 0 : 10)
                    .animation(.easeOut(duration: 0.45).delay(0.08 * Double(index)), value: appearFeatures)
            }
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(gold)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var comparisonChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(cyan)
            Text("Lifetime purchase · No subscriptions · Restorable anywhere")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await buy() }
            } label: {
                HStack(spacing: 10) {
                    if purchaseService.phase == .purchasing || purchaseService.phase == .loading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                    }
                    Text(primaryCTATitle)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.88, blue: 0.48),
                                    Color(red: 1.0, green: 0.70, blue: 0.28),
                                    Color(red: 0.98, green: 0.52, blue: 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: gold.opacity(0.45), radius: 18, x: 0, y: 8)
                )
            }
            .buttonStyle(ProPressableStyle())
            .disabled(isBusy)

            Button {
                Task { await restorePurchases() }
            } label: {
                HStack(spacing: 6) {
                    if purchaseService.phase == .restoring {
                        ProgressView()
                            .tint(.white.opacity(0.7))
                            .scaleEffect(0.8)
                    }
                    Text(purchaseService.phase == .restoring ? "Restoring…" : "Restore Purchases")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .disabled(isBusy)

            Text("Payment is charged to your Apple ID. Restore anytime on a new device.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .multilineTextAlignment(.center)
        }
    }

    private var successLayer: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(i % 2 == 0 ? gold : cyan)
                        .frame(width: 8, height: 8)
                        .offset(y: successBurst ? -90 : 0)
                        .rotationEffect(.degrees(Double(i) * 45))
                        .opacity(successBurst ? 0 : 1)
                        .scaleEffect(successBurst ? 1.4 : 0.4)
                }

                Circle()
                    .fill(gold.opacity(0.25))
                    .frame(width: 160, height: 160)
                    .scaleEffect(successBurst ? 1.15 : 0.7)
                    .blur(radius: 20)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 84, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gold, warmGlow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(successBurst ? 1 : 0.6)
                    .shadow(color: gold.opacity(0.5), radius: 24, x: 0, y: 8)
            }

            VStack(spacing: 10) {
                Text("You're Pro")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Ads are off. Skip planner, forecast, unlimited subjects,\nPDF + CSV, and custom Focus Timer are yours.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button {
                onUnlocked?()
                dismiss()
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule(style: .continuous)
                            .fill(cyan)
                    )
            }
            .buttonStyle(ProPressableStyle())
            .padding(.horizontal, 28)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.85)) {
                successBurst = true
            }
        }
    }

    // MARK: - Actions

    private var heroHeadline: String {
        let market = StudentMarketStore.current
        switch source {
        case "forecast", "locked_forecast":
            return market == .india ? "Know before you bunk" : "Know before you skip"
        case "at_risk_week", "at_risk_home", "at_risk_week_3":
            return market == .india ? "Don't get detained" : "Protect your attendance"
        case "subject_limit":
            return "Track every \(market.courseNoun)"
        case "pdf_export", "csv_export":
            return "Share the proof"
        case "skip_planner":
            return market == .india ? "Know before you bunk" : "Know before you skip"
        case "focus_custom":
            return "Study on your clock"
        case "streak_7":
            return "Keep the streak"
        case "habit_value":
            return "Plan the semester"
        default:
            return "Go Pro"
        }
    }

    private var heroSubtitle: String {
        let skip = StudentMarketStore.current.skipVerb
        switch source {
        case "forecast", "locked_forecast":
            return "Unlock semester forecast — know who you can \(skip) before it's too late."
        case "at_risk_week", "at_risk_home", "at_risk_week_3":
            return "See exactly how many classes it takes to get back above target."
        case "subject_limit":
            return "Free includes \(ProPurchaseConfiguration.freeSubjectLimit) subjects. Pro tracks the full timetable."
        case "pdf_export":
            return "Parent-ready PDF with attendance + grades. One tap to share."
        case "csv_export":
            return "Export every logged day as a spreadsheet — plus the parent-ready PDF."
        case "skip_planner":
            return "See exactly which future class days stay safe if you \(skip) — before you decide."
        case "focus_custom":
            return "90-minute sessions, custom lengths, longer breaks, and a weekly study recap."
        case "streak_7":
            return "Unlock semester forecast and track every subject — you've built the habit."
        case "habit_value":
            return "See where each subject lands by semester end — you've been logging consistently."
        default:
            return "Skip planner, semester forecast, unlimited subjects, and PDF + CSV — one lifetime purchase."
        }
    }

    private var isBusy: Bool {
        switch purchaseService.phase {
        case .purchasing, .restoring, .loading:
            return true
        default:
            return false
        }
    }

    private var primaryCTATitle: String {
        switch purchaseService.phase {
        case .loading:
            return "Loading…"
        case .purchasing:
            return "Unlocking…"
        default:
            if let price = purchaseService.displayPrice {
                return "Unlock Pro — \(price) lifetime"
            }
            return "Unlock Pro — pay once"
        }
    }

    private func retryPurchase() async {
        lastFailureWasRestore = false
        purchaseService.clearTransientError()
        await purchaseService.loadProduct(surfaceFailure: true)
        await buy()
    }

    private func buy() async {
        lastFailureWasRestore = false
        didStartPurchase = true
        AnalyticsService.shared.log(.proPurchaseStarted(source: source))
        let ok = await purchaseService.purchase()
        if ok {
            didPurchaseSucceed = true
            // Success + revenue logged in ProPurchaseService.finish (deduped by transaction id).
        } else if case let .failed(message) = purchaseService.phase {
            AnalyticsService.shared.log(
                .proPurchaseFailed(source: source, reason: Self.analyticsFailureReason(message))
            )
        } else {
            AnalyticsService.shared.log(.proPurchaseCancelled(source: source))
        }
    }

    private func logPriceShownIfNeeded(forceUnavailable: Bool = false) {
        guard didLogPriceShown == false else { return }
        if let price = purchaseService.displayPrice, purchaseService.isAvailable {
            didLogPriceShown = true
            AnalyticsService.shared.log(
                .proPriceShown(
                    source: source,
                    price: price,
                    currency: purchaseService.currencyCode ?? "",
                    available: true
                )
            )
            return
        }
        guard forceUnavailable || {
            if case .failed = purchaseService.phase { return true }
            return false
        }() else { return }
        didLogPriceShown = true
        AnalyticsService.shared.log(
            .proPriceShown(source: source, price: "", currency: "", available: false)
        )
    }

    /// X / swipe-away without a successful purchase. Not fired for StoreKit cancel
    /// while the paywall stays open (`pro_purchase_cancelled` covers that).
    private func logPaywallDismissedIfNeeded() {
        guard didLogDismiss == false else { return }
        guard didPurchaseSucceed == false, entitlements.isPro == false else { return }
        didLogDismiss = true
        let seconds = max(0, Int(Date().timeIntervalSince(paywallAppearedAt)))
        AnalyticsService.shared.log(
            .proPaywallDismissed(
                source: source,
                hadPrice: purchaseService.displayPrice != nil,
                didStartPurchase: didStartPurchase,
                secondsVisible: seconds
            )
        )
    }

    /// Short, stable reason tokens for Firebase (avoid free-form sentence spam).
    private static func analyticsFailureReason(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("unavailable") || lower.contains("couldn't load") {
            return "product_unavailable"
        }
        if lower.contains("offline") || lower.contains("internet") || lower.contains("network") {
            return "network"
        }
        if lower.contains("pending") {
            return "pending_approval"
        }
        if lower.contains("verif") {
            return "verification_failed"
        }
        if lower.contains("not available on this platform") {
            return "unsupported_platform"
        }
        return String(message.prefix(40))
    }

    private func restorePurchases() async {
        lastFailureWasRestore = true
        AnalyticsService.shared.log(.proRestoreStarted)
        let ok = await purchaseService.restore()
        if ok {
            lastFailureWasRestore = false
            AnalyticsService.shared.log(.proRestoreSucceeded)
            AnalyticsUserProfile.sync(subjectStore: nil)
        } else {
            AnalyticsService.shared.log(.proRestoreFailed)
        }
    }

    private func triggerSuccess() {
        guard showSuccess == false else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            showSuccess = true
        }
    }
}

private struct ProPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ProPaywallView(source: "preview")
}
