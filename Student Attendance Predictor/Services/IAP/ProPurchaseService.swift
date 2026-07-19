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
    @Published private(set) var isAvailable = false

#if canImport(StoreKit)
    private var product: Product?
    private var updatesTask: Task<Void, Never>?
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

    func loadProduct() async {
#if canImport(StoreKit)
        phase = displayPrice == nil ? .loading : phase
        do {
            let products = try await Product.products(for: [ProPurchaseConfiguration.proProductID])
            product = products.first
            displayPrice = product?.displayPrice
            isAvailable = product != nil
            if case .loading = phase { phase = .idle }
            if product == nil {
                phase = .failed("Pro is unavailable right now. Please try again later.")
            }
        } catch {
            isAvailable = false
            phase = .failed(friendlyMessage(for: error))
        }
#else
        phase = .failed("In-app purchases are not available on this platform.")
#endif
    }

    @discardableResult
    func purchase() async -> Bool {
#if canImport(StoreKit)
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            phase = .failed("Couldn't load Pro. Check your connection and try again.")
            return false
        }

        phase = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let ok = await finish(verification)
                phase = ok ? .success : .failed("Purchase couldn't be verified. Please try Restore Purchases.")
                return ok
            case .userCancelled:
                phase = .idle
                return false
            case .pending:
                phase = .failed("Purchase is pending approval. You'll get Pro once it's approved.")
                return false
            @unknown default:
                phase = .idle
                return false
            }
        } catch {
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
        await transaction.finish()
        return unlocked
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
