//
//  InstitutionCatalog.swift
//  Student Attendance Predictor
//
//  Offline school/college autocomplete from bundled institutions.json
//

import Foundation

struct InstitutionRecord: Hashable, Identifiable, Sendable {
    let name: String
    let country: String
    let state: String?
    let kind: String?
    /// Short codes students type (IIT, DTU, DU, …).
    let aliases: [String]

    var id: String { "\(name)|\(country)|\(state ?? "")" }

    var subtitle: String {
        var parts: [String] = []
        switch kind {
        case "s": parts.append("School")
        case "c": parts.append("College")
        default: break
        }
        if let state, state.isEmpty == false { parts.append(state) }
        if country.isEmpty == false { parts.append(country) }
        return parts.joined(separator: " · ")
    }
}

/// Loads the bundled institution list once and answers typeahead queries.
@MainActor
final class InstitutionCatalog: ObservableObject {
    static let shared = InstitutionCatalog()

    @Published private(set) var isReady = false
    @Published private(set) var loadFailed = false

    private var records: [InstitutionRecord] = []

    /// Popular India picks when the field is focused with an empty query.
    private static let popularNames: [String] = [
        "IIT Bombay", "IIT Delhi", "IIT Madras", "NIT Trichy", "NIT Surathkal",
        "BITS Pilani", "VIT Vellore", "SRM Institute of Science and Technology",
        "NMIMS", "DTU", "NSUT", "University of Delhi", "JNU",
        "IIIT Hyderabad", "IIIT Delhi", "Manipal Institute of Technology",
        "RV College of Engineering", "PES University", "Christ University",
        "Amity University", "LPU", "Chitkara University", "ICFAI",
        "Assam Down Town University", "Loyola College", "Ambedkar College"
    ]

    /// Major city → search needles for “local” top suggestions.
    private static let cityNeedles: [String: [String]] = [
        "delhi": ["delhi", "noida", "gurgaon", "gurugram", "faridabad"],
        "mumbai": ["mumbai", "thane", "navi mumbai"],
        "bengaluru": ["bengaluru", "bangalore"],
        "bangalore": ["bengaluru", "bangalore"],
        "hyderabad": ["hyderabad", "secunderabad"],
        "chennai": ["chennai", "madras"],
        "kolkata": ["kolkata", "calcutta"],
        "pune": ["pune"],
        "ahmedabad": ["ahmedabad"],
        "jaipur": ["jaipur"],
        "chandigarh": ["chandigarh", "mohali"],
        "lucknow": ["lucknow"],
        "indore": ["indore"],
        "bhopal": ["bhopal"],
        "kochi": ["kochi", "cochin"],
        "guwahati": ["guwahati", "assam"],
    ]

    private init() {
        Task(priority: .utility) { await loadIfNeeded() }
    }

    func loadIfNeeded() async {
        guard isReady == false, loadFailed == false else { return }
        guard let url = Bundle.main.url(forResource: "institutions", withExtension: "json") else {
            loadFailed = true
            #if DEBUG
            print("[Institutions] Missing institutions.json in bundle")
            #endif
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Payload].self, from: data)
            records = decoded.map {
                InstitutionRecord(
                    name: $0.n,
                    country: $0.c,
                    state: $0.s,
                    kind: $0.k,
                    aliases: $0.a ?? []
                )
            }
            isReady = true
            #if DEBUG
            print("[Institutions] Loaded \(records.count) records")
            #endif
        } catch {
            loadFailed = true
            #if DEBUG
            print("[Institutions] Load failed: \(error)")
            #endif
        }
    }

    /// Top popular colleges when the field is empty / first focused.
    func popularSuggestions(limit: Int = 10) async -> [InstitutionRecord] {
        await loadIfNeeded()
        var out: [InstitutionRecord] = []
        var seen = Set<String>()
        for name in Self.popularNames {
            if let match = records.first(where: {
                $0.country == "India" && (
                    $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                        || $0.aliases.contains(where: { $0.compare(name, options: .caseInsensitive) == .orderedSame })
                        || $0.name.localizedCaseInsensitiveContains(name)
                )
            }) {
                if seen.insert(match.id).inserted {
                    out.append(match)
                }
            } else {
                let synthetic = InstitutionRecord(name: name, country: "India", state: nil, kind: "c", aliases: [])
                if seen.insert(synthetic.id).inserted {
                    out.append(synthetic)
                }
            }
            if out.count >= limit { break }
        }
        return out
    }

    /// Top colleges whose name/state matches a city (or city typed as the query).
    func suggestions(forCity city: String, limit: Int = 10) async -> [InstitutionRecord] {
        await loadIfNeeded()
        let key = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard key.count >= 3 else { return [] }
        let needles = Self.cityNeedles[key] ?? [key]
        let snapshot = records
        let popular = Self.popularNames
        return await Task.detached(priority: .userInitiated) {
            var hits: [InstitutionRecord] = []
            var seen = Set<String>()
            for record in snapshot where record.country == "India" {
                let hay = "\(record.name) \(record.state ?? "")".lowercased()
                guard needles.contains(where: { hay.contains($0) }) else { continue }
                // Prefer colleges/universities over schools for city browse.
                if record.kind == "s" { continue }
                if seen.insert(record.id).inserted {
                    hits.append(record)
                }
                if hits.count >= limit * 3 { break }
            }
            hits.sort { lhs, rhs in
                let lPop = popular.contains(where: { lhs.name.localizedCaseInsensitiveContains($0) })
                let rPop = popular.contains(where: { rhs.name.localizedCaseInsensitiveContains($0) })
                if lPop != rPop { return lPop && rPop == false }
                return lhs.name.count < rhs.name.count
            }
            return Array(hits.prefix(limit))
        }.value
    }

    /// Detect if the query is primarily a city name for local browse mode.
    func detectedCity(from query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 3 else { return nil }
        if Self.cityNeedles[trimmed] != nil { return trimmed }
        for (city, needles) in Self.cityNeedles where needles.contains(trimmed) {
            return city
        }
        return nil
    }

    /// Returns up to `limit` matches.
    /// Short queries (2–3 chars) only match word tokens / aliases — not mid-string
    /// (so "DU" won't hit "Dehradun", "IIM" won't hit "AIIMS").
    func search(query: String, limit: Int = 12) async -> [InstitutionRecord] {
        await loadIfNeeded()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        if let city = detectedCity(from: trimmed) {
            let local = await suggestions(forCity: city, limit: limit)
            if local.isEmpty == false { return local }
        }

        let needle = trimmed.lowercased()
        let shortQuery = needle.count <= 3
        let snapshot = records
        return await Task.detached(priority: .userInitiated) {
            struct Scored {
                let record: InstitutionRecord
                let score: Int
            }
            var scored: [Scored] = []
            scored.reserveCapacity(limit * 3)

            for record in snapshot {
                guard let score = institutionMatchScore(
                    record: record,
                    needle: needle,
                    shortQuery: shortQuery
                ) else { continue }
                scored.append(Scored(record: record, score: score))
            }

            scored.sort { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                let lIndia = lhs.record.country == "India"
                let rIndia = rhs.record.country == "India"
                if lIndia != rIndia { return lIndia && rIndia == false }
                return lhs.record.name.count < rhs.record.name.count
            }

            var seen = Set<String>()
            var out: [InstitutionRecord] = []
            out.reserveCapacity(limit)
            for item in scored {
                if seen.insert(item.record.id).inserted {
                    out.append(item.record)
                    if out.count >= limit { break }
                }
            }
            return out
        }.value
    }

    private struct Payload: Decodable {
        let n: String
        let c: String
        let s: String?
        let k: String?
        let a: [String]?
    }
}

/// Lower score = better. nil = no match. Nonisolated so search can run off the main actor.
private func institutionMatchScore(
    record: InstitutionRecord,
    needle: String,
    shortQuery: Bool
) -> Int? {
    let name = record.name.lowercased()
    let aliases = record.aliases.map { $0.lowercased() }

    if name == needle || aliases.contains(needle) {
        return 0
    }

    let tokens = institutionTokenize(name)
    if tokens.contains(needle) || aliases.contains(where: { institutionTokenize($0).contains(needle) }) {
        return 1
    }

    if tokens.contains(where: { $0.hasPrefix(needle) }) {
        return 2
    }

    if aliases.contains(where: { $0.hasPrefix(needle) }) {
        return 2
    }

    if name.hasPrefix(needle) {
        return 3
    }

    // Mid-string contains only for longer queries — avoids DU→Dehradun, IIM→AIIMS.
    if shortQuery == false, name.contains(needle) {
        return 5
    }

    return nil
}

private func institutionTokenize(_ text: String) -> [String] {
    text.lowercased()
        .split { ch in
            ch.isWhitespace || ch == "-" || ch == "," || ch == "." || ch == "/" || ch == "&" || ch == "(" || ch == ")"
        }
        .map(String.init)
        .filter { $0.isEmpty == false }
}
