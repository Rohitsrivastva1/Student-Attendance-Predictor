//
//  NotificationPersonalization.swift
//  Student Attendance Predictor
//
//  Uses the onboarding first name in notification copy when available.
//

import Foundation

enum NotificationPersonalization {
    private static let profileKey = "student.profile.json"

    static func firstName(defaults: UserDefaults = .standard) -> String {
        guard let data = defaults.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(StudentProfile.self, from: data) else {
            return ""
        }
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        return trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? trimmed
    }

    static func apply(title: String, body: String, firstName: String? = nil) -> (title: String, body: String) {
        let first = (firstName ?? Self.firstName()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard first.isEmpty == false else { return (title, body) }

        let personalizedTitle = containsName(title, first) ? title : personalizeTitle(title, first: first)
        let personalizedBody = containsName(body, first) ? body : personalizeBody(body, first: first)
        return (personalizedTitle, personalizedBody)
    }

    static func personalizeTitle(_ title: String, firstName: String? = nil) -> String {
        let first = (firstName ?? Self.firstName()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard first.isEmpty == false else { return title }
        guard containsName(title, first) == false else { return title }
        return personalizeTitle(title, first: first)
    }

    static func personalizeBody(_ body: String, firstName: String? = nil) -> String {
        let first = (firstName ?? Self.firstName()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard first.isEmpty == false else { return body }
        guard containsName(body, first) == false else { return body }
        return personalizeBody(body, first: first)
    }

    private static func personalizeTitle(_ title: String, first: String) -> String {
        if title.contains(":") {
            return "\(first) — \(title)"
        }
        if title.hasSuffix("?") {
            return "\(first), \(lowercaseFirst(title.dropLast()))?"
        }
        if title.hasSuffix(".") || title.hasSuffix("!") {
            let punctuation = String(title.suffix(1))
            let core = String(title.dropLast())
            return "\(first), \(lowercaseFirst(core))\(punctuation)"
        }
        return "\(first), \(lowercaseFirst(title))"
    }

    private static func personalizeBody(_ body: String, first: String) -> String {
        if body.hasPrefix("You're") || body.hasPrefix("Your") || body.hasPrefix("You ") {
            return "\(first), \(lowercaseFirst(body))"
        }
        if body.hasPrefix("Nice work") {
            return body.replacingOccurrences(of: "Nice work", with: "Nice work, \(first)")
        }
        if body.hasPrefix("Ready for") {
            return "\(first), \(lowercaseFirst(body))"
        }
        return "\(first) — \(body)"
    }

    private static func containsName(_ text: String, _ first: String) -> Bool {
        text.range(of: first, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let firstChar = text.first else { return text }
        return firstChar.lowercased() + text.dropFirst()
    }

    private static func lowercaseFirst<S: StringProtocol>(_ text: S) -> String {
        lowercaseFirst(String(text))
    }
}

extension Notification.Name {
    static let studentProfileDidUpdate = Notification.Name("student.profile.didUpdate")
}
