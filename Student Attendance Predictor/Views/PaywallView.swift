//
//  PaywallView.swift
//  Student Attendance Predictor
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeKit: StoreKitManager
    @Environment(\.dismiss) private var dismiss

    @State private var alertMessage: String?
    @State private var isShowingTerms = false
    @State private var isShowingPrivacy = false

    private let orderedProductIDs = [
        "com.schoolabe.bunkplanner.annual",
        "com.schoolabe.bunkplanner.monthly",
        "com.schoolabe.bunkplanner.lifetime"
    ]

    private var orderedProducts: [Product] {
        storeKit.products.sorted { lhs, rhs in
            let lhsIndex = orderedProductIDs.firstIndex(of: lhs.id) ?? orderedProductIDs.count
            let rhsIndex = orderedProductIDs.firstIndex(of: rhs.id) ?? orderedProductIDs.count
            return lhsIndex < rhsIndex
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.1)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(orderedProducts, id: \.id) { product in
                        productCard(for: product)
                    }

                    if orderedProducts.isEmpty {
                        emptyStateCard
                    }

                    restoreButton
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .overlay {
            if storeKit.isLoading {
                loadingOverlay
            }
        }
        .task {
            if storeKit.products.isEmpty {
                await storeKit.fetchProducts()
            }

            if let message = storeKit.errorMessage {
                alertMessage = message
            }
        }
        .onChange(of: storeKit.errorMessage) { _, newValue in
            alertMessage = newValue
        }
        .alert("StoreKit", isPresented: Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    alertMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $isShowingTerms) {
            NavigationStack {
                TermsOfUseView()
            }
        }
        .sheet(isPresented: $isShowingPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PaywallPressableButtonStyle())
            }

            Text("Upgrade to Pro")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("Unlock unlimited subjects, attendance trends, subject forecasts, timetable planning, and the faculty dashboard.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private func productCard(for product: Product) -> some View {
        let isAnnual = product.id == "com.schoolabe.bunkplanner.annual"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(durationLabel(for: product))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if isAnnual {
                        Text("Best Value")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(red: 0.45, green: 0.92, blue: 0.7))
                            )
                    }

                    Text(product.displayPrice)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            Button {
                Task {
                    let purchased = await storeKit.purchase(product)
                    if purchased {
                        try? await Task.sleep(for: .seconds(0.5))
                        dismiss()
                    }
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    )
            }
            .buttonStyle(PaywallPressableButtonStyle())
            .disabled(storeKit.isLoading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isAnnual ? Color(red: 0.45, green: 0.92, blue: 0.7).opacity(0.7) : Color.white.opacity(0.14), lineWidth: isAnnual ? 1.4 : 1)
                )
        )
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No products available")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Try again in a moment.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var restoreButton: some View {
        Button {
            Task {
                await storeKit.restorePurchases()
                if storeKit.hasProAccess {
                    dismiss()
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PaywallPressableButtonStyle())
        .padding(.top, 4)
        .padding(.bottom, 8)
        .disabled(storeKit.isLoading)
    }

    private var legalFooter: some View {
        HStack(spacing: 12) {
            Button("Terms of Use") {
                isShowingTerms = true
            }
            .buttonStyle(.plain)

            Text("•")
                .foregroundStyle(.white.opacity(0.35))

            Button("Privacy Policy") {
                isShowingPrivacy = true
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.7))
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                Text("Loading...")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    private func durationLabel(for product: Product) -> String {
        if let period = product.subscription?.subscriptionPeriod {
            let unit: String
            switch period.unit {
            case .day:
                unit = period.value == 1 ? "day" : "days"
            case .week:
                unit = period.value == 1 ? "week" : "weeks"
            case .month:
                unit = period.value == 1 ? "month" : "months"
            case .year:
                unit = period.value == 1 ? "year" : "years"
            @unknown default:
                unit = "period"
            }
            return "\(period.value) \(unit)"
        }

        switch product.type {
        case .nonConsumable:
            return "Lifetime"
        default:
            return "Plan"
        }
    }
}

private struct PaywallPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
