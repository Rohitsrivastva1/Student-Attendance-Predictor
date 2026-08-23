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

    /// Free tier subject count. Users with more keep them (grandfathered) but cannot add until Pro.
    static let freeSubjectLimit = 3
}
