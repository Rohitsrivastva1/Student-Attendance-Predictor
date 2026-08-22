//
//  ProPurchaseService.swift
//  Student Attendance Predictor
//
//  StoreKit 2 purchase + entitlement sync for Bunk Planner Pro.
//

import Foundation
import Combine
#if canImport(StoreKit)
import StoreKit
#endif

@MainActor
final class ProPurchaseService: ObservableObject {
    static let shared = ProPurchaseService()

    enum PurchasePhase: Equatable {
        case idle
        case loading
        case purchasing
        case restoring
        case success
        case failed(String)
    }

    @Published private(set) var phase: PurchasePhase = .idle
    @Published private(set) var displayPrice: String?
    /// Numeric price for Firebase purchase revenue (nil until product loads).
    @Published private(set) var priceValue: Double?
    /// ISO currency code for Firebase purchase revenue (e.g. "INR").
    @Published private(set) var currencyCode: String?
    @Published private(set) var isAvailable = false

#if canImport(StoreKit)
    private var product: Product?
    private var updatesTask: Task<Void, Never>?
    private let loggedPurchaseIDsKey = "iap.loggedPurchaseTransactionIDs"
    private var purchaseFlowActive = false
#endif

    private init() {}

    func start() {
#if canImport(StoreKit)
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task { await refreshEntitlements() }
        Task { await loadProduct() }
#endif
    }

    /// Loads the Pro product. Pass `surfaceFailure: true` from the paywall / purchase
    /// path so missing products show an error; launch-time loads stay silent.
    func loadProduct(surfaceFailure: Bool = false) async {
#if canImport(StoreKit)
        if displayPrice == nil {
            phase = .loading
        }
        do {
            let products = try await Product.products(for: [ProPurchaseConfiguration.proProductID])
            product = products.first
            displayPrice = product?.displayPrice
            if let product {
                priceValue = NSDecimalNumber(decimal: product.price).doubleValue
                currencyCode = product.priceFormatStyle.currencyCode
            } else {
                priceValue = nil
                currencyCode = nil
            }
            isAvailable = product != nil
            if product == nil {
                phase = surfaceFailure
                    ? .failed("Pro is unavailable right now. Please try again later.")
                    : .idle
            } else if case .loading = phase {
                phase = .idle
            } else if case .failed = phase {
                phase = .idle
            }
        } catch {
            isAvailable = false
            phase = surfaceFailure
                ? .failed(friendlyMessage(for: error))
                : .idle
        }
#else
        if surfaceFailure {
            phase = .failed("In-app purchases are not available on this platform.")
        }
#endif
    }

    @discardableResult
    func purchase() async -> Bool {
#if canImport(StoreKit)
        if product == nil {
            await loadProduct(surfaceFailure: true)
        }
        guard let product else {
            phase = .failed("Couldn't load Pro. Check your connection and try again.")
            return false
        }

        phase = .purchasing
        purchaseFlowActive = true
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let ok = await finish(verification)
                purchaseFlowActive = false
                phase = ok ? .success : .failed("Purchase couldn't be verified. Please try Restore Purchases.")
                return ok
            case .userCancelled:
                purchaseFlowActive = false
                phase = .idle
                return false
            case .pending:
                purchaseFlowActive = false
                phase = .failed("Purchase is pending approval. You'll get Pro once it's approved.")
                return false
            @unknown default:
                purchaseFlowActive = false
                phase = .failed("Purchase didn't complete. Please try again.")
                return false
            }
        } catch {
            purchaseFlowActive = false
            phase = .failed(friendlyMessage(for: error))
            return false
        }
#else
        phase = .failed("In-app purchases are not available on this platform.")
        return false
#endif
    }

    @discardableResult
    func restore() async -> Bool {
#if canImport(StoreKit)
        phase = .restoring
        do {
            try await AppStore.sync()
            let unlocked = await refreshEntitlements()
            if unlocked {
                phase = .success
            } else {
                phase = .failed("No previous Pro purchase found for this Apple ID.")
            }
            return unlocked
        } catch {
            phase = .failed(friendlyMessage(for: error))
            return false
        }
#else
        phase = .failed("Restore isn’t available on this platform.")
        return false
#endif
    }

    @discardableResult
    func refreshEntitlements() async -> Bool {
#if canImport(StoreKit)
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == ProPurchaseConfiguration.proProductID,
               transaction.revocationDate == nil {
                unlocked = true
                break
            }
        }
        AdEntitlementsStore.shared.setProUnlocked(unlocked)
        return unlocked
#else
        return AdEntitlementsStore.shared.isPro
#endif
    }

    func clearTransientError() {
        if case .failed = phase {
            phase = .idle
        }
    }

#if canImport(StoreKit)
    private func handle(transactionResult: VerificationResult<Transaction>) async {
        _ = await finish(transactionResult)
        await refreshEntitlements()
    }

    private func finish(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else {
            return false
        }
        guard transaction.productID == ProPurchaseConfiguration.proProductID else {
            await transaction.finish()
            return false
        }
        let unlocked = transaction.revocationDate == nil
        AdEntitlementsStore.shared.setProUnlocked(unlocked)
        if unlocked {
            logPurchaseAnalyticsIfNeeded(for: transaction)
        }
        await transaction.finish()
        return unlocked
    }

    /// Central purchase analytics — covers paywall `buy()` and background `Transaction.updates`.
    private func logPurchaseAnalyticsIfNeeded(for transaction: Transaction) {
        let isNewPurchase = transaction.reason == .purchase || purchaseFlowActive
        guard isNewPurchase else { return }

        let transactionID = String(transaction.id)
        var logged = Set(UserDefaults.standard.stringArray(forKey: loggedPurchaseIDsKey) ?? [])
        guard logged.insert(transactionID).inserted else { return }
        if logged.count > 100 {
            logged = Set(logged.suffix(100))
        }
        UserDefaults.standard.set(Array(logged), forKey: loggedPurchaseIDsKey)

        let source = AnalyticsService.shared.lastProPaywallSource
        AnalyticsService.shared.log(.proPurchaseSucceeded(source: source))

        let value = NSDecimalNumber(decimal: transaction.price ?? 0).doubleValue
        let currency = transaction.currency?.identifier ?? currencyCode ?? "INR"
        if value > 0 {
            AnalyticsService.shared.logPurchase(
                value: value,
                currency: currency,
                productID: ProPurchaseConfiguration.proProductID
            )
        } else if let priceValue, let currencyCode {
            AnalyticsService.shared.logPurchase(
                value: priceValue,
                currency: currencyCode,
                productID: ProPurchaseConfiguration.proProductID
            )
        }
        AnalyticsUserProfile.sync(subjectStore: nil)
    }
#endif

    private func friendlyMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return "You're offline. Connect to the internet and try again."
        }
        return error.localizedDescription
    }
}
