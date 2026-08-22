//
//  ProPurchaseConfiguration.swift
//  Student Attendance Predictor
//

import Foundation

enum ProPurchaseConfiguration {
    /// Non-consumable product ID — must match App Store Connect (and the local StoreKit config).
    static let proProductID = "schoolabe.bunkplanner.pro"

    /// Free tier subject count. Users with more keep them (grandfathered) but cannot add until Pro.
    static let freeSubjectLimit = 3
}
