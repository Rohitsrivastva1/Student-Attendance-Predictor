//
//  AnalyticsBackend.swift
//  Student Attendance Predictor
//
//  A pluggable analytics sink. AnalyticsService fans every event out to all
//  registered backends, so the app code never talks to a specific SDK directly.
//
//  Shipping backends:
//  - FirebaseAnalyticsBackend: live product analytics (compiled in only when the
//    Firebase SPM package is added; see FIREBASE_SETUP in AnalyticsService).
//  - ConsoleAnalyticsBackend: DEBUG-only console logging so events are verifiable
//    immediately, even before Firebase is wired up.
//

import Foundation

protocol AnalyticsBackend: AnyObject {
    func log(name: String, parameters: [String: Any])
    func setUserID(_ id: String?)
    func setUserProperty(_ value: String?, forName name: String)
    func setCollectionEnabled(_ enabled: Bool)
    /// Firebase standard purchase event for revenue reporting. Optional for backends that ignore it.
    func logPurchase(value: Double, currency: String, productID: String)
}

extension AnalyticsBackend {
    func logPurchase(value: Double, currency: String, productID: String) {
        log(
            name: "purchase",
            parameters: [
                "value": value,
                "currency": currency,
                "item_id": productID
            ]
        )
    }
}

// MARK: - Console backend (DEBUG)

#if DEBUG
final class ConsoleAnalyticsBackend: AnalyticsBackend {
    func log(name: String, parameters: [String: Any]) {
        let pairs = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        print("[Analytics] \(name) { \(pairs) }")
    }

    func setUserID(_ id: String?) {
        print("[Analytics] userID = \(id ?? "nil")")
    }

    func setUserProperty(_ value: String?, forName name: String) {
        print("[Analytics] userProperty \(name) = \(value ?? "nil")")
    }

    func setCollectionEnabled(_ enabled: Bool) {
        print("[Analytics] collectionEnabled = \(enabled)")
    }
}
#endif

// MARK: - Firebase backend

// Compiles only once the Firebase SPM package is added to the project. Until
// then `canImport(FirebaseAnalytics)` is false and this type simply doesn't
// exist, keeping the app buildable.
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics

final class FirebaseAnalyticsBackend: AnalyticsBackend {
    func log(name: String, parameters: [String: Any]) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func setUserID(_ id: String?) {
        Analytics.setUserID(id)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func setCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    func logPurchase(value: Double, currency: String, productID: String) {
        var parameters: [String: Any] = [
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterItemID: productID
        ]
        parameters[AnalyticsParameterItems] = [
            [
                AnalyticsParameterItemID: productID,
                AnalyticsParameterItemName: "Bunk Planner Pro",
                AnalyticsParameterItemCategory: "iap",
                AnalyticsParameterPrice: value,
                AnalyticsParameterQuantity: 1
            ]
        ]
        Analytics.logEvent(AnalyticsEventPurchase, parameters: parameters)
    }
}
#endif
