//
//  SyllabusAIService.swift
//  Student Attendance Predictor
//
//  Calls Schoolabe syllabus/structure (Groq key lives on server as GROQ_SYLLABUS_API_KEY).
//

import Foundation

enum SyllabusAIError: LocalizedError, Equatable {
    case notConfigured
    case aiNotConfigured
    case rateLimited
    case emptyText
    case invalidResponse
    case httpStatus(Int)
    case offline
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Schoolabe isn’t configured on this build."
        case .aiNotConfigured:
            return "AI polish isn’t available yet. You can still edit units manually."
        case .rateLimited:
            return "Daily AI limit reached. Try again tomorrow or edit the outline yourself."
        case .emptyText:
            return "Add some syllabus text first."
        case .invalidResponse:
            return "Couldn’t read the AI response. Try again."
        case let .httpStatus(code):
            return "Server error (\(code)). Try again."
        case .offline:
            return "You’re offline. Connect to use Make better."
        case let .unknown(message):
            return message
        }
    }
}

struct SyllabusStructureResponse: Decodable {
    struct UnitDTO: Decodable {
        let title: String
        let topics: [String]
    }

    let units: [UnitDTO]
    let error: String?
}

@MainActor
final class SyllabusAIService {
    static let shared = SyllabusAIService()

    private let session: URLSession
    private let maxChars = 12_000

    init(session: URLSession = .shared) {
        self.session = session
    }

    func structureSyllabus(
        rawText: String,
        subjectName: String?,
        market: String
    ) async throws -> [SyllabusUnit] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { throw SyllabusAIError.emptyText }

        guard let url = SchoolabeAPIConfiguration.syllabusStructureURL else {
            throw SyllabusAIError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BunkPlanner/iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 45

        let body: [String: Any] = [
            "client_user_id": AnalyticsService.shared.userId,
            "raw_text": String(trimmed.prefix(maxChars)),
            "market": market,
            "subject_name": subjectName ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SyllabusAIError.offline }

            if http.statusCode == 429 {
                throw SyllabusAIError.rateLimited
            }
            if http.statusCode == 503 {
                throw SyllabusAIError.aiNotConfigured
            }
            // Transient upstream / model failures — let caller fall back to on-device outline.
            if http.statusCode == 502 {
                throw SyllabusAIError.aiNotConfigured
            }
            guard (200...299).contains(http.statusCode) else {
                if let dto = try? JSONDecoder().decode(SyllabusStructureResponse.self, from: data),
                   let err = dto.error?.lowercased() {
                    if err.contains("not_configured") || err.contains("ai_not_configured") {
                        throw SyllabusAIError.aiNotConfigured
                    }
                    if err.contains("rate") {
                        throw SyllabusAIError.rateLimited
                    }
                }
                throw SyllabusAIError.httpStatus(http.statusCode)
            }

            let decoded = try JSONDecoder().decode(SyllabusStructureResponse.self, from: data)
            if let err = decoded.error?.lowercased(), err.isEmpty == false {
                if err.contains("not_configured") || err.contains("ai_not_configured") {
                    throw SyllabusAIError.aiNotConfigured
                }
                throw SyllabusAIError.unknown(decoded.error ?? "AI error")
            }

            let units = decoded.units.compactMap { unit -> SyllabusUnit? in
                let title = unit.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let topics = unit.topics
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
                    .prefix(40)
                    .map { SyllabusTopic(title: String($0.prefix(120))) }
                guard title.isEmpty == false || topics.isEmpty == false else { return nil }
                return SyllabusUnit(
                    title: title.isEmpty ? "Unit" : String(title.prefix(80)),
                    topics: Array(topics)
                )
            }
            guard units.isEmpty == false else { throw SyllabusAIError.invalidResponse }
            return units
        } catch let error as SyllabusAIError {
            throw error
        } catch let urlError as URLError {
            if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                throw SyllabusAIError.offline
            }
            throw SyllabusAIError.unknown(urlError.localizedDescription)
        } catch {
            throw SyllabusAIError.invalidResponse
        }
    }

    /// Offline fallback when AI isn’t available — split lines into a single unit.
    static func heuristicUnits(from rawText: String) -> [SyllabusUnit] {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false && $0.count > 2 }
            .prefix(60)

        var units: [SyllabusUnit] = []
        var currentTitle = "Topics"
        var currentTopics: [SyllabusTopic] = []

        func flush() {
            if currentTopics.isEmpty == false {
                units.append(SyllabusUnit(title: currentTitle, topics: currentTopics))
            }
            currentTopics = []
        }

        for line in lines {
            let looksLikeHeading =
                line.count < 48
                && (line.uppercased() == line || line.hasPrefix("Unit") || line.hasPrefix("Module") || line.hasPrefix("Chapter"))
            if looksLikeHeading && currentTopics.isEmpty == false {
                flush()
                currentTitle = String(line.prefix(80))
            } else if looksLikeHeading && currentTopics.isEmpty {
                currentTitle = String(line.prefix(80))
            } else {
                currentTopics.append(SyllabusTopic(title: String(line.prefix(120))))
            }
        }
        flush()
        if units.isEmpty {
            return [SyllabusUnit(title: "Topics", topics: lines.map { SyllabusTopic(title: String($0.prefix(120))) })]
        }
        return units
    }
}
