//
//  ReferralService.swift
//  Student Attendance Predictor
//
//  Invite loop: Schoolabe HTTP + anonymous analytics user id.
//  Both sides get 7 days ad-free when a friend redeems.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ReferralService: ObservableObject {
    static let shared = ReferralService()

    @Published private(set) var inviteCode: String?
    @Published private(set) var friendsJoined: Int = 0
    @Published private(set) var adFreeDaysEarned: Int = 0
    @Published private(set) var isBusy = false
    @Published var lastError: String?
    @Published var rewardBannerText: String?
    @Published var isShowingRedeem = false
    @Published var redeemCodeInput = ""

    private let defaults: UserDefaults
    private let session: URLSession
    private let friendsKey = "referral.friendsJoined"
    private let daysEarnedKey = "referral.adFreeDaysEarned"
    private let inviteCodeKey = "referral.inviteCode"
    private let clipboardScannedKey = "referral.didScanClipboard"
    private let didRedeemKey = "referral.didRedeemInvite"
    private var didStart = false
    private var refreshTask: Task<Void, Never>?

    var inviteURL: URL? {
        guard let inviteCode else { return nil }
        return ReferralConfiguration.inviteURL(code: inviteCode)
    }

    var isBackendAvailable: Bool {
        SchoolabeAPIConfiguration.inviteEnsureURL != nil
    }

    /// True when this install already redeemed (success or server already_redeemed).
    /// Do not use invite trial here — referrers also get a trial via claim.
    var hasAlreadyRedeemed: Bool {
        defaults.bool(forKey: didRedeemKey)
    }

    /// Unlock button enabled when the code is valid and not this install's own code.
    var canSubmitRedeem: Bool {
        let code = CrockfordBase32.normalize(redeemCodeInput)
        guard CrockfordBase32.isValid(code) else { return false }
        if let inviteCode, code == inviteCode { return false }
        return hasAlreadyRedeemed == false
    }

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        friendsJoined = defaults.integer(forKey: friendsKey)
        adFreeDaysEarned = defaults.integer(forKey: daysEarnedKey)
        if let stored = defaults.string(forKey: inviteCodeKey), CrockfordBase32.isValid(stored) {
            inviteCode = CrockfordBase32.normalize(stored)
        }
    }

    func start() {
        guard didStart == false else { return }
        didStart = true
        Task {
            await refreshRewards(showBusy: true)
        }
        startForegroundRefresh()
    }

    /// Reads clipboard only from Redeem screen — never on cold launch (avoids iOS paste prompt).
    func prefillRedeemFromClipboardIfNeeded() {
        scanClipboardIfNeeded()
    }

    /// Poll claim + ensure while the app is open so the inviter updates live.
    /// 90s cadence stays under Schoolabe's ~3 req/min rate limit.
    func startForegroundRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while let self, Task.isCancelled == false {
                await self.refreshRewards(showBusy: false)
                try? await Task.sleep(nanoseconds: 90_000_000_000)
            }
        }
    }

    func stopForegroundRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshRewards(showBusy: Bool = true) async {
        await claimReferralRewards()
        if inviteCode == nil {
            await ensureInviteCode(showBusy: showBusy)
        }
    }

    /// Returns true when the URL is an invite link (custom scheme or universal).
    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let code = ReferralConfiguration.code(from: url), CrockfordBase32.isValid(code) else {
            return false
        }
        presentRedeem(code: code, source: "deep_link")
        return true
    }

    func presentRedeem(code: String? = nil, source: String = "settings") {
        if let code, CrockfordBase32.isValid(code) {
            redeemCodeInput = CrockfordBase32.normalize(code)
        }
        isShowingRedeem = true
        AnalyticsService.shared.log(.inviteRedeemStarted(source: source))
    }

    func shareInviteLine() -> String? {
        guard let inviteCode else { return nil }
        let invite = ReferralConfiguration.inviteURL(code: inviteCode).absoluteString
        let store = ReferralConfiguration.appStoreURL().absoluteString
        return "Try Bunk Planner with my invite code \(inviteCode) — 7 days of all Pro features.\n\(invite)\n\(store)"
    }

    func ensureInviteCode(showBusy: Bool = true) async {
        guard isBackendAvailable else { return }
        if showBusy { isBusy = true }
        defer { if showBusy { isBusy = false } }
        do {
            let payload = try await post(
                InviteClientIDPayload(clientUserId: AnalyticsService.shared.userId),
                to: SchoolabeAPIConfiguration.inviteEnsureURL,
                as: InviteEnsureResponse.self
            )
            applyCode(payload.code)
            lastError = nil
            if let count = payload.redeemCount {
                friendsJoined = count
                defaults.set(count, forKey: friendsKey)
            }
        } catch {
            if showBusy {
                lastError = userMessage(for: error)
            }
            #if DEBUG
            print("Invite ensure failed \(SchoolabeAPIConfiguration.inviteEnsureURL?.absoluteString ?? "nil"): \(error)")
            #endif
        }
    }

    func redeemEnteredCode() async {
        let code = CrockfordBase32.normalize(redeemCodeInput)
        guard CrockfordBase32.isValid(code) else {
            lastError = "Enter the 6-character invite code from your friend."
            // Don't log empty Unlock taps — they inflated fail counts ~7× per user.
            return
        }
        if let inviteCode, code == inviteCode {
            lastError = "That’s your code — send it to a friend."
            AnalyticsService.shared.log(.inviteRedeemFailed(reason: "self_redeem"))
            return
        }
        if hasAlreadyRedeemed {
            lastError = "This install already used an invite."
            AnalyticsService.shared.log(.inviteRedeemFailed(reason: "already_redeemed"))
            isShowingRedeem = false
            return
        }
        await redeem(code: code)
    }

    func redeem(code: String) async {
        guard isBackendAvailable else {
            lastError = "Invite rewards need a network connection. Try again in a moment."
            return
        }
        let normalized = CrockfordBase32.normalize(code)
        if let inviteCode, normalized == inviteCode {
            lastError = "That’s your code — send it to a friend."
            AnalyticsService.shared.log(.inviteRedeemFailed(reason: "self_redeem"))
            return
        }
        if hasAlreadyRedeemed {
            lastError = "This install already used an invite."
            AnalyticsService.shared.log(.inviteRedeemFailed(reason: "already_redeemed"))
            isShowingRedeem = false
            return
        }
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            let payload = try await post(
                InviteRedeemPayload(
                    clientUserId: AnalyticsService.shared.userId,
                    code: normalized
                ),
                to: SchoolabeAPIConfiguration.inviteRedeemURL,
                as: InviteRedeemResponse.self
            )
            let days = payload.grantDays ?? ReferralConfiguration.grantDays
            AdEntitlementsStore.shared.extendInviteTrial(days: days)
            defaults.set(true, forKey: didRedeemKey)
            rewardBannerText = "\(days) days of Pro features unlocked. Ads still run."
            isShowingRedeem = false
            redeemCodeInput = ""
            AnalyticsService.shared.log(
                .inviteRedeemSucceeded(
                    days: days,
                    code: payload.code ?? normalized,
                    referrerClientUserId: payload.referrerClientUserId ?? ""
                )
            )
        } catch {
            let token = errorToken(error)
            lastError = userMessage(for: error)
            AnalyticsService.shared.log(.inviteRedeemFailed(reason: token))
            if token == "already_redeemed" {
                defaults.set(true, forKey: didRedeemKey)
                isShowingRedeem = false
            }
            #if DEBUG
            print("Invite redeem failed \(SchoolabeAPIConfiguration.inviteRedeemURL?.absoluteString ?? "nil"): \(error)")
            #endif
        }
    }

    func claimReferralRewards() async {
        guard isBackendAvailable else { return }
        do {
            let payload = try await post(
                InviteClientIDPayload(clientUserId: AnalyticsService.shared.userId),
                to: SchoolabeAPIConfiguration.inviteClaimURL,
                as: InviteClaimResponse.self
            )
            let days = payload.grantedDays ?? 0
            let totalFriends = payload.redeemCount ?? friendsJoined
            friendsJoined = totalFriends
            defaults.set(totalFriends, forKey: friendsKey)
            if days > 0 {
                AdEntitlementsStore.shared.extendInviteTrial(days: days)
                adFreeDaysEarned += days
                defaults.set(adFreeDaysEarned, forKey: daysEarnedKey)
                rewardBannerText = "A friend joined — \(days) days of Pro features."
                AnalyticsService.shared.log(.referralRewardClaimed(days: days))
            }
            applyCode(payload.code)
        } catch {
            // Silent on launch — backend may not be deployed yet.
        }
    }

    /// Copies the 6-character invite code. Returns false if there is no code yet.
    @discardableResult
    func copyInviteCode() -> Bool {
        guard let inviteCode, CrockfordBase32.isValid(inviteCode) else { return false }
        #if canImport(UIKit)
        UIPasteboard.general.string = inviteCode
        #endif
        AnalyticsService.shared.log(.inviteLinkShared)
        return true
    }

    func copyInviteLink() {
        _ = copyInviteCode()
    }

    func dismissRewardBanner() {
        rewardBannerText = nil
    }

    private func applyCode(_ raw: String?) {
        guard let raw, CrockfordBase32.isValid(raw) else { return }
        let code = CrockfordBase32.normalize(raw)
        inviteCode = code
        defaults.set(code, forKey: inviteCodeKey)
    }

    private func scanClipboardIfNeeded() {
        guard defaults.bool(forKey: clipboardScannedKey) == false else { return }
        #if canImport(UIKit)
        guard let raw = UIPasteboard.general.string else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let found: String?
        if let url = URL(string: trimmed), let fromURL = ReferralConfiguration.code(from: url) {
            found = fromURL
        } else if let fromShare = ReferralConfiguration.code(fromShareText: trimmed) {
            found = fromShare
        } else {
            let code = CrockfordBase32.normalize(trimmed)
            found = CrockfordBase32.isValid(code) ? code : nil
        }
        // Only mark scanned once we actually found a code — empty pasteboard
        // should not permanently disable clipboard redeem.
        guard let found, CrockfordBase32.isValid(found) else { return }
        if let inviteCode, found == inviteCode { return }
        defaults.set(true, forKey: clipboardScannedKey)
        redeemCodeInput = CrockfordBase32.normalize(found)
        #endif
    }

    private func post<Body: Encodable, Response: Decodable>(
        _ payload: Body,
        to url: URL?,
        as type: Response.Type
    ) async throws -> Response {
        guard let url else { throw ReferralClientError.backendUnavailable }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BunkPlanner/iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let body = try? encoder.encode(payload) else {
            throw ReferralClientError.backendUnavailable
        }
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReferralClientError.backendUnavailable
        }
        if (200...299).contains(http.statusCode) {
            return try JSONDecoder().decode(type, from: data)
        }
        throw ReferralClientError.api(status: http.statusCode, detail: decodeDetail(data))
    }

    private func decodeDetail(_ data: Data) -> String {
        if let body = try? JSONDecoder().decode(SchoolabeDetailBody.self, from: data),
           let detail = body.detailToken {
            return detail
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func userMessage(for error: Error) -> String {
        switch errorToken(error) {
        case "already_redeemed":
            return "This install already used an invite."
        case "not_found":
            return "That invite code wasn’t found. Check it and try again."
        case "self_redeem":
            return "You can’t redeem your own invite."
        case "cap_reached":
            return "This invite has hit its friend limit for now."
        default:
            return "Couldn’t reach invite rewards. Try again in a moment."
        }
    }

    private func errorToken(_ error: Error) -> String {
        if let api = error as? ReferralClientError, case let .api(_, detail) = api {
            return normalizeToken(detail)
        }
        return normalizeToken(error.localizedDescription)
    }

    /// Canonical analytics reasons: self_redeem / already_redeemed / not_found / cap_reached.
    private func normalizeToken(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("already_redeemed")
            || lower.contains("already-exists")
            || lower.contains("already_exists") {
            return "already_redeemed"
        }
        if lower.contains("self_redeem")
            || lower.contains("failed-precondition")
            || lower.contains("failed_precondition") {
            return "self_redeem"
        }
        if lower.contains("not-found") || lower.contains("not_found") {
            return "not_found"
        }
        if lower.contains("cap_reached") || lower.contains("resource-exhausted") {
            return "cap_reached"
        }
        return String(lower.prefix(40))
    }
}

private struct InviteClientIDPayload: Encodable {
    let clientUserId: String

    enum CodingKeys: String, CodingKey {
        case clientUserId = "client_user_id"
    }
}

private struct InviteRedeemPayload: Encodable {
    let clientUserId: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case code
        case clientUserId = "client_user_id"
    }
}

private struct InviteEnsureResponse: Decodable {
    let code: String?
    let redeemCount: Int?

    enum CodingKeys: String, CodingKey {
        case code
        case redeemCount = "redeem_count"
    }
}

private struct InviteRedeemResponse: Decodable {
    let grantDays: Int?
    let code: String?
    let referrerClientUserId: String?
    let inviteeClientUserId: String?

    enum CodingKeys: String, CodingKey {
        case code
        case grantDays = "grant_days"
        case referrerClientUserId = "referrer_client_user_id"
        case inviteeClientUserId = "invitee_client_user_id"
    }
}

private struct InviteClaimResponse: Decodable {
    let grantedDays: Int?
    let redeemCount: Int?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case code
        case grantedDays = "granted_days"
        case redeemCount = "redeem_count"
    }
}

private struct SchoolabeDetailBody: Decodable {
    let detail: FlexibleDetail?

    var detailToken: String? { detail?.token }

    enum FlexibleDetail: Decodable {
        case text(String)
        case list([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
                return
            }
            if let items = try? container.decode([String].self) {
                self = .list(items)
                return
            }
            self = .text("")
        }

        var token: String {
            switch self {
            case let .text(text): return text
            case let .list(items): return items.joined(separator: " ")
            }
        }
    }
}

private enum ReferralClientError: Error {
    case backendUnavailable
    case api(status: Int, detail: String)
}
