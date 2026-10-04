//
//  AdEntitlementsStore.swift
//  Student Attendance Predictor
//
//  Tracks ad & feature entitlements from:
//  - permanent Pro IAP (features + ads off)
//  - invite trial (all Pro features, ads stay on)
//  - legacy short rewarded-video windows
//

import Foundation
import Combine

@MainActor
final class AdEntitlementsStore: ObservableObject {
    static let shared = AdEntitlementsStore()

    /// Hide-ads grant after a rewarded video.
    nonisolated static let adRemovalDuration: TimeInterval = 4 * 60 * 60
    /// Forecast unlock grant after a rewarded video.
    nonisolated static let forecastUnlockDuration: TimeInterval = 2 * 60 * 60

    private let defaults: UserDefaults
    private let bannersRemovedUntilKey = "ads.bannersRemovedUntil"
    private let forecastUnlockedUntilKey = "ads.forecastUnlockedUntil"
    private let inviteTrialUntilKey = "ads.inviteTrialUntil"
    private let isProKey = "iap.isPro"

    @Published private(set) var bannersRemovedUntil: Date
    @Published private(set) var forecastUnlockedUntil: Date
    @Published private(set) var inviteTrialUntil: Date
    @Published private(set) var isPro: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var banners = defaults.object(forKey: bannersRemovedUntilKey) as? Date ?? .distantPast
        var trial = defaults.object(forKey: inviteTrialUntilKey) as? Date ?? .distantPast
        forecastUnlockedUntil = defaults.object(forKey: forecastUnlockedUntilKey) as? Date ?? .distantPast
        isPro = defaults.bool(forKey: isProKey)

        // Older invite grants hid ads for 7 days. Move that window onto the
        // feature trial and turn ads back on.
        if banners.timeIntervalSinceNow > 12 * 60 * 60 {
            trial = max(trial, banners)
            banners = .distantPast
            defaults.set(trial, forKey: inviteTrialUntilKey)
            defaults.set(banners, forKey: bannersRemovedUntilKey)
        }

        bannersRemovedUntil = banners
        inviteTrialUntil = trial
    }

    /// Ads hide only for paid Pro or a short rewarded-video grant — never invite.
    var areBannersHidden: Bool { isPro || bannersRemovedUntil > Date() }

    var isInviteTrialActive: Bool { inviteTrialUntil > Date() }

    /// Forecast: Pro, rewarded window, or invite trial.
    var isForecastUnlocked: Bool { hasProFeatures || forecastUnlockedUntil > Date() }

    /// All Pro features except ads. Invite trial uses this; ads still show.
    var hasProFeatures: Bool { isPro || isInviteTrialActive }

    /// Free users may hold at most `freeSubjectLimit` subjects. Extra subjects stay
    /// on device but are locked (no new marks) until Pro / invite trial is active.
    func canAddSubject(currentCount: Int) -> Bool {
        hasProFeatures || currentCount < ProPurchaseConfiguration.freeSubjectLimit
    }

    /// Oldest subjects stay in the free slots so data is never deleted on Pro expiry.
    func isSubjectLocked(id: UUID, subjects: [SubjectSummary]) -> Bool {
        guard hasProFeatures == false else { return false }
        guard subjects.count > ProPurchaseConfiguration.freeSubjectLimit else { return false }
        return unlockedSubjectIDs(from: subjects).contains(id) == false
    }

    func unlockedSubjectIDs(from subjects: [SubjectSummary]) -> Set<UUID> {
        if hasProFeatures { return Set(subjects.map(\.id)) }
        let ordered = subjects.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return Set(ordered.prefix(ProPurchaseConfiguration.freeSubjectLimit).map(\.id))
    }

    func grantBannerRemoval(for duration: TimeInterval = AdEntitlementsStore.adRemovalDuration) {
        let until = Date().addingTimeInterval(duration)
        bannersRemovedUntil = until
        defaults.set(until, forKey: bannersRemovedUntilKey)
        Task { @MainActor in
            AnalyticsUserProfile.sync(subjectStore: nil)
        }
    }

    /// Invite reward: stack Pro-feature days. Ads keep running.
    func extendInviteTrial(days: Int) {
        guard days > 0 else { return }
        let extra = TimeInterval(days) * 24 * 60 * 60
        let base = max(inviteTrialUntil, Date())
        inviteTrialUntil = base.addingTimeInterval(extra)
        defaults.set(inviteTrialUntil, forKey: inviteTrialUntilKey)
        Task { @MainActor in
            AnalyticsUserProfile.sync(subjectStore: nil)
        }
    }

    func grantForecastUnlock(for duration: TimeInterval = AdEntitlementsStore.forecastUnlockDuration) {
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
