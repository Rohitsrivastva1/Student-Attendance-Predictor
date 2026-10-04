//
//  ProPurchaseConfiguration.swift
//  Student Attendance Predictor
//

import Foundation

enum ProPurchaseConfiguration {
    /// Non-consumable product ID — must match App Store Connect (and the local StoreKit config).
    static let proProductID = "schoolabe.bunkplanner.pro"

    /// Legacy StoreKit IDs — honor on restore for early buyers.
    static let legacyProProductIDs: Set<String> = [
        "com.schoolabe.bunkplanner.monthly",
        "com.schoolabe.bunkplanner.annual",
        "com.schoolabe.bunkplanner.lifetime"
    ]

    static var allProProductIDs: Set<String> {
        legacyProProductIDs.union([proProductID])
    }

    /// Subscription IDs that can expire (monthly / annual).
    static let legacySubscriptionProductIDs: Set<String> = [
        "com.schoolabe.bunkplanner.monthly",
        "com.schoolabe.bunkplanner.annual"
    ]

    /// India App Store list price for paywall copy when StoreKit product has not loaded yet.
    /// Must match live ASC / Products.storekit (`49`). Do not use ROADMAP P3 ₹99/₹69.
    static let indiaListPriceDisplay = "₹49"

    /// Free tier subject count. Extra subjects stay on device but lock when Pro lapses.
    static let freeSubjectLimit = 3
}
