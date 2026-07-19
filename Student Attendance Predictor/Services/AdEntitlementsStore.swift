//
//  AdEntitlementsStore.swift
//  Student Attendance Predictor
//
//  Tracks ad & forecast entitlements from:
//  - time-limited rewarded ads (24h)
//  - permanent Pro IAP
//

import Foundation
import Combine

@MainActor
final class AdEntitlementsStore: ObservableObject {
    static let shared = AdEntitlementsStore()

    /// Reward duration granted per rewarded-ad view.
    nonisolated static let rewardDuration: TimeInterval = 24 * 60 * 60

    private let defaults: UserDefaults
    private let bannersRemovedUntilKey = "ads.bannersRemovedUntil"
    private let forecastUnlockedUntilKey = "ads.forecastUnlockedUntil"
    private let isProKey = "iap.isPro"

    @Published private(set) var bannersRemovedUntil: Date
    @Published private(set) var forecastUnlockedUntil: Date
    @Published private(set) var isPro: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bannersRemovedUntil = defaults.object(forKey: bannersRemovedUntilKey) as? Date ?? .distantPast
        forecastUnlockedUntil = defaults.object(forKey: forecastUnlockedUntilKey) as? Date ?? .distantPast
        isPro = defaults.bool(forKey: isProKey)
    }

    /// True while ads should be hidden (Pro or active rewarded window).
    var areBannersHidden: Bool { isPro || bannersRemovedUntil > Date() }

    /// True while forecast should be unlocked (Pro or active rewarded window).
    var isForecastUnlocked: Bool { isPro || forecastUnlockedUntil > Date() }

    func grantBannerRemoval(for duration: TimeInterval = AdEntitlementsStore.rewardDuration) {
        let until = Date().addingTimeInterval(duration)
        bannersRemovedUntil = until
        defaults.set(until, forKey: bannersRemovedUntilKey)
        Task { @MainActor in
            AnalyticsUserProfile.sync(subjectStore: nil)
        }
    }

    func grantForecastUnlock(for duration: TimeInterval = AdEntitlementsStore.rewardDuration) {
        let until = Date().addingTimeInterval(duration)
        forecastUnlockedUntil = until
        defaults.set(until, forKey: forecastUnlockedUntilKey)
    }

    /// Called by StoreKit after purchase, restore, or entitlement sync.
    func setProUnlocked(_ unlocked: Bool) {
        guard isPro != unlocked else { return }
        isPro = unlocked
        defaults.set(unlocked, forKey: isProKey)
        Task { @MainActor in
            AnalyticsUserProfile.sync(subjectStore: nil)
        }
    }

    /// Human-readable remaining time (e.g. "23h 14m"), or nil if expired.
    func remaining(until date: Date) -> String? {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return nil }
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
