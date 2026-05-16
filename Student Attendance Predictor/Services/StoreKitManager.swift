//
//  StoreKitManager.swift
//  Student Attendance Predictor
//

import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let productIDs: Set<String> = [
        "com.schoolabe.bunkplanner.monthly",
        "com.schoolabe.bunkplanner.annual",
        "com.schoolabe.bunkplanner.lifetime"
    ]
    static let shared = StoreKitManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var hasProAccess: Bool {
        !purchasedProductIDs.isDisjoint(with: Self.productIDs)
    }

    var isPro: Bool {
        get async {
            await Self.hasCurrentEntitlement()
        }
    }

    init() {
        transactionUpdatesTask = listenForTransactions()

        Task {
            await fetchProducts()
            await refreshPurchasedProducts()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func fetchProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedProducts = try await Product.products(for: Array(Self.productIDs))
            products = Self.sortedProducts(fetchedProducts)
        } catch {
            errorMessage = StoreKitManagerError.productFetchFailed(error).localizedDescription
        }

        isLoading = false
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                await transaction.finish()
                await refreshPurchasedProducts()
                return true

            case .pending:
                errorMessage = StoreKitManagerError.purchasePending.localizedDescription
                return false

            case .userCancelled:
                return false

            @unknown default:
                errorMessage = StoreKitManagerError.unknownPurchaseResult.localizedDescription
                return false
            }
        } catch {
            errorMessage = StoreKitManagerError.purchaseFailed(error).localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        errorMessage = nil

        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
        } catch {
            errorMessage = StoreKitManagerError.restoreFailed(error).localizedDescription
        }
    }

    func refreshPurchasedProducts() async {
        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard Self.productIDs.contains(transaction.productID) else { continue }
                guard transaction.revocationDate == nil else { continue }
                guard transaction.expirationDate.map({ $0 > Date() }) ?? true else { continue }
                guard transaction.isUpgraded == false else { continue }

                activeProductIDs.insert(transaction.productID)
            } catch {
                errorMessage = StoreKitManagerError.transactionVerificationFailed(error).localizedDescription
            }
        }

        purchasedProductIDs = activeProductIDs
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try await MainActor.run { try self.checkVerified(result) }
                    await transaction.finish()
                    await self.refreshPurchasedProducts()
                } catch {
                    await MainActor.run {
                        self.setTransactionError(error)
                    }
                }
            }
        }
    }

    private func setTransactionError(_ error: Error) {
        errorMessage = StoreKitManagerError.transactionVerificationFailed(error).localizedDescription
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw StoreKitManagerError.transactionVerificationFailed(error)
        }
    }

    private static func hasCurrentEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard productIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            guard transaction.isUpgraded == false else { continue }
            return true
        }

        return false
    }

    private static func sortedProducts(_ products: [Product]) -> [Product] {
        let order = [
            "com.schoolabe.bunkplanner.annual",
            "com.schoolabe.bunkplanner.monthly",
            "com.schoolabe.bunkplanner.lifetime"
        ]

        return products.sorted { lhs, rhs in
            let lhsIndex = order.firstIndex(of: lhs.id) ?? order.count
            let rhsIndex = order.firstIndex(of: rhs.id) ?? order.count
            return lhsIndex < rhsIndex
        }
    }
}

enum StoreKitManagerError: LocalizedError {
    case productFetchFailed(Error)
    case purchaseFailed(Error)
    case purchasePending
    case restoreFailed(Error)
    case transactionVerificationFailed(Error)
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .productFetchFailed(let error):
            return "Unable to load StoreKit products. \(error.localizedDescription)"
        case .purchaseFailed(let error):
            return "Purchase failed. \(error.localizedDescription)"
        case .purchasePending:
            return "Purchase is pending approval."
        case .restoreFailed(let error):
            return "Unable to restore purchases. \(error.localizedDescription)"
        case .transactionVerificationFailed(let error):
            return "Unable to verify StoreKit transaction. \(error.localizedDescription)"
        case .unknownPurchaseResult:
            return "StoreKit returned an unknown purchase result."
        }
    }
}
