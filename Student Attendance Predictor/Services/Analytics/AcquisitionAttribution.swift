//
//  AcquisitionAttribution.swift
//  Student Attendance Predictor
//
//  Resolves app-open acquisition: notification, deep link / UTM, Apple Search Ads
//  (AdServices token → Apple API), otherwise organic.
//

import Foundation
#if canImport(AdServices)
import AdServices
#endif

@MainActor
final class AcquisitionAttribution {
    static let shared = AcquisitionAttribution()

    struct Resolved {
        let source: String
        let campaign: String?
        let medium: String?
        let detail: String?
    }

    private let defaults: UserDefaults
    private let asaResolvedKey = "acquisition.asaResolved"
    private let asaSourceKey = "acquisition.asaSource"
    private let asaCampaignKey = "acquisition.asaCampaign"
    private let asaMediumKey = "acquisition.asaMedium"
    private let asaDetailKey = "acquisition.asaDetail"

    /// Pending deep-link / universal-link attribution for the next session start.
    private var pendingDeepLink: Resolved?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start() {
        refreshAppleSearchAdsIfNeeded()
    }

    /// Call from `onOpenURL` / universal links.
    func handleIncomingURL(_ url: URL) {
        pendingDeepLink = resolveURL(url)
    }

    /// Call from `onContinueUserActivity` when a web/universal link resumes the app.
    func handleUserActivity(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else { return }
        pendingDeepLink = resolveURL(url)
    }

    func resolveForSession(
        notificationOpenedAt: Date?,
        notificationWindow: TimeInterval
    ) -> Resolved {
        if let openedAt = notificationOpenedAt,
           Date().timeIntervalSince(openedAt) <= notificationWindow {
            return Resolved(source: "notification", campaign: nil, medium: "push", detail: nil)
        }

        if let deepLink = pendingDeepLink {
            pendingDeepLink = nil
            return deepLink
        }

        if defaults.bool(forKey: asaResolvedKey),
           let source = defaults.string(forKey: asaSourceKey),
           source != "organic" {
            return Resolved(
                source: source,
                campaign: defaults.string(forKey: asaCampaignKey),
                medium: defaults.string(forKey: asaMediumKey),
                detail: defaults.string(forKey: asaDetailKey)
            )
        }

        return Resolved(source: "organic", campaign: nil, medium: nil, detail: nil)
    }

    private func resolveURL(_ url: URL) -> Resolved {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }

        let utmSource = value("utm_source")
        let utmCampaign = value("utm_campaign")
        let utmMedium = value("utm_medium")
        let utmContent = value("utm_content")

        if utmSource != nil || utmCampaign != nil {
            return Resolved(
                source: utmSource ?? "deeplink",
                campaign: utmCampaign,
                medium: utmMedium ?? "deeplink",
                detail: utmContent ?? url.host
            )
        }

        return Resolved(
            source: "deeplink",
            campaign: url.host,
            medium: url.scheme,
            detail: String(url.path.prefix(40))
        )
    }

    private func refreshAppleSearchAdsIfNeeded() {
        guard defaults.bool(forKey: asaResolvedKey) == false else { return }
        #if canImport(AdServices)
        Task.detached(priority: .utility) {
            do {
                let token = try AAAttribution.attributionToken()
                guard let payload = await Self.fetchASAAttribution(token: token) else {
                    await MainActor.run {
                        self.defaults.set(true, forKey: self.asaResolvedKey)
                        self.defaults.set("organic", forKey: self.asaSourceKey)
                    }
                    return
                }
                await MainActor.run {
                    self.storeASA(payload)
                }
            } catch {
                await MainActor.run {
                    // Token unavailable (simulator / non-ASA) — mark resolved as organic once.
                    self.defaults.set(true, forKey: self.asaResolvedKey)
                    self.defaults.set("organic", forKey: self.asaSourceKey)
                }
            }
        }
        #else
        defaults.set(true, forKey: asaResolvedKey)
        defaults.set("organic", forKey: asaSourceKey)
        #endif
    }

    private func storeASA(_ payload: ASAAttributionPayload) {
        defaults.set(true, forKey: asaResolvedKey)
        guard payload.attribution else {
            defaults.set("organic", forKey: asaSourceKey)
            return
        }
        defaults.set("apple_search_ads", forKey: asaSourceKey)
        if let campaignId = payload.campaignId {
            defaults.set(String(campaignId), forKey: asaCampaignKey)
        }
        defaults.set("asa", forKey: asaMediumKey)
        var detailParts: [String] = []
        if let adGroupId = payload.adGroupId { detailParts.append("ag:\(adGroupId)") }
        if let keywordId = payload.keywordId { detailParts.append("kw:\(keywordId)") }
        if let conversionType = payload.conversionType { detailParts.append(conversionType) }
        if detailParts.isEmpty == false {
            defaults.set(detailParts.joined(separator: "|"), forKey: asaDetailKey)
        }
        AnalyticsService.shared.setUserProperty("apple_search_ads", forName: "acq_source")
        if let campaignId = payload.campaignId {
            AnalyticsService.shared.setUserProperty(String(campaignId), forName: "acq_campaign")
        }
    }

    #if canImport(AdServices)
    private nonisolated static func fetchASAAttribution(token: String) async -> ASAAttributionPayload? {
        guard let url = URL(string: "https://api-adservices.apple.com/api/v1/") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(ASAAttributionPayload.self, from: data)
        } catch {
            return nil
        }
    }
    #endif
}

private struct ASAAttributionPayload: Decodable {
    let attribution: Bool
    let campaignId: Int?
    let adGroupId: Int?
    let keywordId: Int?
    let creativeSetId: Int?
    let conversionType: String?

    enum CodingKeys: String, CodingKey {
        case attribution
        case campaignId
        case adGroupId
        case keywordId
        case creativeSetId
        case conversionType
    }
}
