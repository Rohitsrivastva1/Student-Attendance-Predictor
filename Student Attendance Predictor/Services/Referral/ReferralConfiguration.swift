//
//  ReferralConfiguration.swift
//  Student Attendance Predictor
//

import Foundation

enum ReferralConfiguration {
    static let grantDays = 7
    static let maxSuccessfulReferralsPerWindow = 10
    static let referralWindowDays = 30
    static let appStoreID = "6761951427"
    static let inviteHost = "schoolabe.com"

    /// System share sheet / Home invite CTAs. Keep off until redeem reason
    /// breakdown (self_redeem / already_redeemed / not_found) looks clean in prod.
    /// Copy-code + Settings redeem stay available so the loop can be verified.
    static let inviteSystemShareEnabled = false

    static func inviteURL(code: String) -> URL {
        URL(string: "https://\(inviteHost)/i/\(code)")!
    }

    static func appStoreURL() -> URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    static func code(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let scheme = url.scheme?.lowercased() ?? ""

        if scheme == "bunkplanner" {
            let parts = url.path.split(separator: "/").map(String.init)
            if url.host?.lowercased() == "invite", let first = parts.first {
                return CrockfordBase32.normalize(first)
            }
            if parts.first?.lowercased() == "invite", let code = parts.dropFirst().first {
                return CrockfordBase32.normalize(code)
            }
        }

        if host == inviteHost || host == "www.\(inviteHost)" {
            let parts = url.path.split(separator: "/").map(String.init)
            if parts.first?.lowercased() == "i", let code = parts.dropFirst().first {
                return CrockfordBase32.normalize(code)
            }
        }

        return nil
    }

    /// Pull a 6-character code out of share text like "invite code ABC123".
    static func code(fromShareText text: String) -> String? {
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           let fromURL = code(from: url) {
            return fromURL
        }
        let pattern = #"(?:invite\s+)?code\s+([0-9A-Za-z]{6})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let codeRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let code = CrockfordBase32.normalize(String(text[codeRange]))
        return CrockfordBase32.isValid(code) ? code : nil
    }
}

enum CrockfordBase32 {
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func normalize(_ raw: String) -> String {
        let mapped = raw.uppercased().map { ch -> Character in
            switch ch {
            case "I", "L": return "1"
            case "O": return "0"
            case "U": return "V"
            default: return ch
            }
        }
        return String(mapped.filter { alphabet.contains($0) })
    }

    static func isValid(_ raw: String) -> Bool {
        let code = normalize(raw)
        return code.count == 6 && code.allSatisfy { alphabet.contains($0) }
    }
}
