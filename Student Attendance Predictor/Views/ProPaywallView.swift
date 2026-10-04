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
    @State private var didCancelCheckout = false
    @State private var lastFailureWasRestore = false

    private var purchaseAlertTitle: String {
        lastFailureWasRestore ? "Restore Purchases" : "Purchase"
    }

    private var isRestoreFailure: Bool { lastFailureWasRestore }

    private let cyan = BrandColor.colorAccentPrimary
    private let gold = BrandColor.colorPremium
    private let warmGlow = BrandColor.colorPremiumDeep

    private var features: [(icon: String, title: String, subtitle: String)] {
        let skipVerb = StudentMarketStore.current.skipVerb
        let skip = ("calendar.badge.checkmark", "See the safe day before you \(skipVerb)", "We already did the math. Pro shows which lecture you can miss.")
        let forecast = ("chart.line.uptrend.xyaxis", "Know where you'll land", "Subject-wise forecast before the semester ends — not after detention.")
        let subjects = ("books.vertical.fill", "Every \(StudentMarketStore.current.courseNoun), not just 3", "Free includes \(ProPurchaseConfiguration.freeSubjectLimit). Add the rest of your semester with Pro.")
        switch source {
        case "subject_limit":
            return [subjects, skip, forecast]
        default:
            return [skip, forecast, subjects]
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
            didCancelCheckout = false
            AnalyticsService.shared.setLastProPaywallSource(source)
            AnalyticsService.shared.setLastProPaywallLayout(paywallLayout)
            AnalyticsService.shared.log(.proPaywallViewed(source: source, layout: paywallLayout))
            SoftPaywallCoordinator.shared.confirmPresented(source: source)
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
                    BrandColor.colorBackground,
                    Color(hex: 0x10141C),
                    BrandColor.colorBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(gold.opacity(orbPulse ? 0.12 : 0.06))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -90, y: -220)
                .allowsHitTesting(false)

            Circle()
                .fill(cyan.opacity(orbPulse ? 0.10 : 0.05))
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

                    if showsSkipPlannerPreview {
                        skipPlannerPreviewSection
                            .opacity(appearFeatures ? 1 : 0)
                            .offset(y: appearFeatures ? 0 : 16)
                    } else {
                        featuresSection
                            .opacity(appearFeatures ? 1 : 0)
                            .offset(y: appearFeatures ? 0 : 16)

                        comparisonTable
                            .opacity(appearFeatures ? 1 : 0)

                        comparisonChip
                            .opacity(appearFeatures ? 1 : 0)
                    }
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
                    .fill(BrandColor.premiumGradient)
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

                Text(priceAnchorLine)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(gold.opacity(0.95))
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

    /// First soft sheets lead with a blurred Skip Planner preview (intent match), not a generic feature list.
    private var showsSkipPlannerPreview: Bool {
        switch source {
        case "habit_value", "at_risk_week", "at_risk_week_3", "streak_7":
            return true
        default:
            return false
        }
    }

    private var paywallLayout: String {
        showsSkipPlannerPreview ? "skip_planner_preview" : "feature_list"
    }

    private var skipPlannerPreviewSection: some View {
        let skip = StudentMarketStore.current.skipVerb
        return VStack(alignment: .leading, spacing: 12) {
            Text("YOUR SKIP PLANNER")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(cyan)
                .tracking(1.2)

            ZStack {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Thu · 25 Sep")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(cyan)
                        Spacer()
                        Text("Safe to \(skip)")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(BrandColor.colorAttend)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(BrandColor.colorAttend.opacity(0.18)))
                    }

                    previewImpactRow(
                        name: "DSA",
                        detail: "2 classes · 82% → 78%",
                        safe: true,
                        note: "Still above 75% · 1 \(skip) left"
                    )
                    previewImpactRow(
                        name: "Maths",
                        detail: "1 class · 71% → 68%",
                        safe: false,
                        note: "Drops below your 75% target"
                    )
                    previewImpactRow(
                        name: "Physics",
                        detail: "1 class · 88% → 84%",
                        safe: true,
                        note: "Still above 75% · 3 \(skip)s left"
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .blur(radius: 4.5)
                .allowsHitTesting(false)

                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(gold)
                    Text("Reveal which days stay safe")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Unlock Skip Planner — see the day before you \(skip).")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                )
            }

            Text("Your real subjects fill this once you unlock.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func previewImpactRow(name: String, detail: String, safe: Bool, note: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(safe ? BrandColor.colorAttend : BrandColor.colorMissed)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text(note)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(safe ? BrandColor.colorAttend.opacity(0.9) : BrandColor.colorMissed.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
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

    private var comparisonTable: some View {
        let skip = StudentMarketStore.current.skipVerb
        let rows: [(String, String, String)] = [
            ("Subjects", "3", "Unlimited"),
            ("Before you \(skip)", "Guess", "See the day"),
            ("Semester forecast", "Locked", "Every subject"),
            ("Ads", "On", "Off forever")
        ]
        return VStack(spacing: 0) {
            HStack {
                Text("Why pay")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("Free")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 72, alignment: .trailing)
                Text("Pro")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(gold)
                    .frame(width: 88, alignment: .trailing)
            }
            .padding(.bottom, 10)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.38))
                        .frame(width: 72, alignment: .trailing)
                    Text(row.2)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 88, alignment: .trailing)
                }
                .padding(.vertical, 8)
                if index < rows.count - 1 {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(gold.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var comparisonChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(cyan)
            Text("Pay once · No monthly · Restorable on a new phone")
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
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule(style: .continuous)
                        .fill(BrandColor.premiumGradient)
                        .shadow(color: BrandColor.colorElevation, radius: 12, y: 6)
                )
            }
            .buttonStyle(ProPressableStyle())
            .disabled(isBusy)

            if didCancelCheckout {
                Text(checkoutCancelHint)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(gold.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if StudentMarketStore.current == .india, isBusy == false, let price = resolvedDisplayPrice {
                Text("\(price) · one-time · charged to Apple ID")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

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

    private var checkoutCancelHint: String {
        if StudentMarketStore.current == .india {
            return "No charge. If Apple's sheet closed, add a card or UPI in Settings → Apple ID → Payment, then tap again."
        }
        return "No charge. If checkout closed, add a payment method to your Apple ID in Settings, then tap again."
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
        case "forecast", "locked_forecast", "skip_planner":
            return market == .india ? "Don't bunk the wrong day" : "Don't skip the wrong day"
        case "subject_limit":
            return "Your other papers are waiting"
        case "pdf_export", "csv_export":
            return "Show them the proof"
        case "focus_custom":
            return "Study on your clock"
        case "streak_7":
            return "You earned the planner"
        case "habit_value":
            return market == .india ? "Don't bunk the wrong day" : "Don't skip the wrong day"
        case "at_risk_week", "at_risk_week_3":
            return "You're at risk — plan the recovery"
        default:
            return market == .india ? "Know before you bunk" : "Know before you skip"
        }
    }

    private var heroSubtitle: String {
        let skip = StudentMarketStore.current.skipVerb
        switch source {
        case "forecast", "locked_forecast", "skip_planner":
            return "Guessing a \(skip) is how the 75% line gets crossed. Pro shows the day before you walk out."
        case "subject_limit":
            return "Free includes \(ProPurchaseConfiguration.freeSubjectLimit) \(StudentMarketStore.current.courseNounPlural). Unlock the rest so every lecture is tracked."
        case "pdf_export":
            return "Parent-ready PDF with attendance + grades. One tap to share."
        case "csv_export":
            return "Export every logged day as a spreadsheet — plus the parent-ready PDF."
        case "focus_custom":
            return "90-minute sessions, custom lengths, longer breaks, and a weekly study recap."
        case "streak_7":
            return "You've been logging. Don't waste that streak on a guessed \(skip)."
        case "habit_value":
            return "Your numbers are in. Here's the map of which days stay safe — unlock to see yours."
        case "at_risk_week", "at_risk_week_3":
            return "Skip Planner shows which lectures you must attend to climb back above the line."
        default:
            return "Skip planner + forecast for every subject. Pay once. Keep it all semester."
        }
    }

    /// StoreKit price when loaded; India falls back to live list ₹49 so copy never blanks.
    private var resolvedDisplayPrice: String? {
        if let price = purchaseService.displayPrice {
            return price
        }
        return StudentMarketStore.current == .india
            ? ProPurchaseConfiguration.indiaListPriceDisplay
            : nil
    }

    private var priceAnchorLine: String {
        if let price = resolvedDisplayPrice {
            if StudentMarketStore.current == .india {
                return "\(price) once · less than a canteen snack · no monthly"
            }
            return "\(price) once · no subscription · keep it forever"
        }
        return "Pay once · no subscription · keep it forever"
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
            return "Loading price…"
        case .purchasing:
            return "Starting…"
        default:
            let price = resolvedDisplayPrice
            switch source {
            case "skip_planner", "forecast", "locked_forecast", "habit_value", "streak_7", "at_risk_week", "at_risk_week_3":
                return price.map { "Start — reveal safe days · \($0)" } ?? "Start — reveal safe days"
            case "subject_limit":
                return price.map { "Start — unlock all subjects · \($0)" } ?? "Start — unlock all subjects"
            default:
                return price.map { "Start Pro — \($0) once" } ?? "Start Pro — pay once"
            }
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
            didCancelCheckout = true
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
                secondsVisible: seconds,
                layout: paywallLayout
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
