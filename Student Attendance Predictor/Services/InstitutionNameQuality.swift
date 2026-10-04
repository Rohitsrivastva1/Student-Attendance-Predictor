//
//  InstitutionNameQuality.swift
//  Student Attendance Predictor
//
//  Incomplete-name detection + canonical alias normalization for sync/analytics.
//

import Foundation

enum InstitutionNameQuality {
    /// Junk / placeholder names that caused (unknown)-style analytics noise.
    private static let incompleteExact: Set<String> = [
        "", ".", "-", "—", "…", "?", "na", "n/a", "nil", "none", "test",
        "college", "clg", "cllg", "collage", "uni", "university", "school",
        "institute", "ddd", "xxx", "abc", "asdf", "qwerty", "unknown",
        "my college", "my school", "my clg", "nm", "xyz"
    ]

    /// Canonical brand → preferred display name (short, stable for admin charts).
    private static let canonicalBrands: [(pattern: String, canonical: String)] = [
        ("nmims", "NMIMS"),
        ("narsee monjee", "NMIMS"),
        ("icfai", "ICFAI"),
        ("ifhe", "ICFAI"),
        ("chitkara", "Chitkara University"),
        ("lovely professional", "LPU"),
        ("\\blpu\\b", "LPU"),
        ("delhi technological", "DTU"),
        ("\\bdtu\\b", "DTU"),
        ("netaji subhas", "NSUT"),
        ("\\bnsut\\b", "NSUT"),
        ("jawaharlal nehru university", "JNU"),
        ("\\bjnu\\b", "JNU"),
        ("university of delhi", "University of Delhi"),
        ("delhi university", "University of Delhi"),
        ("\\bdu\\b", "University of Delhi"),
        ("assam down ?town", "Assam Down Town University"),
        ("vit vellore", "VIT Vellore"),
        ("vit chennai", "VIT Chennai"),
        ("bits pilani", "BITS Pilani"),
        ("rv college of engineering", "RV College of Engineering"),
        ("\\brvce\\b", "RV College of Engineering"),
        ("\\brvc\\b", "RV College of Engineering"),
        ("ambedkar college", "Ambedkar College"),
        ("bhimrao ambedkar college", "Ambedkar College"),
        ("loyola college", "Loyola College"),
        ("bhavan.?s? vivekananda", "Bhavan's Vivekananda College"),
        ("sardar vallabh", "Sardar Vallabhbhai Patel Institute"),
        ("manipal institute of technology", "MIT Manipal"),
        ("indian institute of technology bombay", "IIT Bombay"),
        ("indian institute of technology delhi", "IIT Delhi"),
        ("indian institute of technology madras", "IIT Madras"),
        ("indian institute of science", "IISc Bangalore"),
    ]

    static func trimmed(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func looksIncomplete(_ raw: String) -> Bool {
        let value = trimmed(raw)
        guard value.isEmpty == false else { return true }
        let lower = value.lowercased()
        if incompleteExact.contains(lower) { return true }
        if value.count < 3 { return true }
        if value.allSatisfy({ $0 == "." || $0 == "-" || $0.isWhitespace }) { return true }
        // Single vague token like "Clg" / "College"
        let letters = lower.filter(\.isLetter)
        if letters.count <= 3, incompleteExact.contains(letters) { return true }
        if lower == "clg" || lower == "cllg" || lower.hasPrefix("clg ") { return true }
        return false
    }

    /// Soft copy when the name looks like junk but user can still confirm.
    static func incompleteHint(for raw: String) -> String? {
        guard looksIncomplete(raw) else { return nil }
        let value = trimmed(raw)
        if value.isEmpty {
            return "Pick your college or school — required to continue"
        }
        return "“\(value)” looks incomplete — pick from the list or type the full name"
    }

    /// Normalize for storage + Schoolabe so admin charts don’t fragment.
    static func normalizedForStorage(_ raw: String) -> String {
        let value = trimmed(raw)
        guard value.isEmpty == false else { return value }
        let lower = value.lowercased()

        for pair in canonicalBrands {
            if let regex = try? NSRegularExpression(pattern: pair.pattern, options: .caseInsensitive),
               regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
                // Keep campus suffix when useful (e.g. "NMIMS Mumbai" → still NMIMS;
                // "VIT Chennai" already maps specifically above).
                return pair.canonical
            }
        }

        // Collapse whitespace / odd punctuation noise
        let collapsed = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed
    }

    static func isAcceptable(_ raw: String, allowIncompleteOverride: Bool) -> Bool {
        let value = trimmed(raw)
        guard value.isEmpty == false else { return false }
        if looksIncomplete(value) { return allowIncompleteOverride }
        return true
    }
}
