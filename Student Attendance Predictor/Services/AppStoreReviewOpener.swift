//
//  AppStoreReviewOpener.swift
//  Student Attendance Predictor
//
//  Opens the App Store write-review page from Settings → Rate Us.
//

import Foundation
#if canImport(UIKit)
import StoreKit
import UIKit
#endif

enum AppStoreReviewOpener {
    static let appStoreID = "6761951427"

    /// Tries App Store deep links first, then falls back to the in-app review prompt.
    @MainActor
    static func openWriteReview() async -> Bool {
        #if canImport(UIKit)
        let urlStrings = [
            "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review",
            "itms-apps://apps.apple.com/app/id\(appStoreID)?action=write-review",
            "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        ]

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            if await UIApplication.shared.open(url) {
                return true
            }
        }

        return requestInAppReview()
        #else
        return false
        #endif
    }

    #if canImport(UIKit)
    @MainActor
    @discardableResult
    private static func requestInAppReview() -> Bool {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard let scene else { return false }
        SKStoreReviewController.requestReview(in: scene)
        return true
    }
    #endif
}
