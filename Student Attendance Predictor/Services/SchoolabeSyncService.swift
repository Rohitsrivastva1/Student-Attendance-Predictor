//
//  SchoolabeSyncService.swift
//  Student Attendance Predictor
//
//  Single upsert API: anonymous client id + optional profile + subject list.
//  Does not send attendance marks or percentages — subjects only for now.
//

import Foundation

struct SchoolabeSyncPayload: Encodable {
    struct ProfilePayload: Encodable {
        let name: String?
        let age: Int?
        let classOrDegree: String?
        let institutionName: String?

        enum CodingKeys: String, CodingKey {
            case name, age
            case classOrDegree = "class_or_degree"
            case institutionName = "institution_name"
        }
    }

    struct SubjectPayload: Encodable {
        let id: String
        let name: String
        let requiredPercentage: Double
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id, name
            case requiredPercentage = "required_percentage"
            case createdAt = "created_at"
        }
    }

    struct MetaPayload: Encodable {
        let appVersion: String
        let market: String
        let platform: String

        enum CodingKeys: String, CodingKey {
            case appVersion = "app_version"
            case market, platform
        }
    }

    let clientUserId: String
    let profile: ProfilePayload?
    let subjects: [SubjectPayload]
    let meta: MetaPayload

    enum CodingKeys: String, CodingKey {
        case profile, subjects, meta
        case clientUserId = "client_user_id"
    }
}

enum SchoolabeSyncError: Error, LocalizedError {
    case invalidURL
    case offline
    case httpStatus(Int)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Schoolabe API URL is invalid."
        case .offline: return "No network connection."
        case let .httpStatus(code): return "Schoolabe API returned HTTP \(code)."
        case .encodingFailed: return "Could not encode sync payload."
        }
    }
}

@MainActor
final class SchoolabeSyncService {
    static let shared = SchoolabeSyncService()

    private var syncTask: Task<Void, Never>?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Debounced sync — call after profile save or subject changes.
    func scheduleSync(subjectStore: SubjectStore?) {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard Task.isCancelled == false else { return }
            await sync(subjectStore: subjectStore)
        }
    }

    func sync(subjectStore: SubjectStore?) async {
        guard SchoolabeAPIConfiguration.isConfigured,
              let url = SchoolabeAPIConfiguration.syncURL else { return }

        let profileStore = StudentProfileStore.shared
        let profile = profileStore.profile

        let profilePayload: SchoolabeSyncPayload.ProfilePayload? = {
            guard profile.hasAnyField else { return nil }
            let trimmedName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedClass = profile.classOrDegree.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSchool = profile.institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
            return SchoolabeSyncPayload.ProfilePayload(
                name: trimmedName.isEmpty ? nil : trimmedName,
                age: profile.age,
                classOrDegree: trimmedClass.isEmpty ? nil : trimmedClass,
                institutionName: trimmedSchool.isEmpty ? nil : trimmedSchool
            )
        }()

        let subjects = (subjectStore?.subjects ?? []).map { subject in
            SchoolabeSyncPayload.SubjectPayload(
                id: subject.id.uuidString,
                name: subject.name,
                requiredPercentage: subject.requiredPercentage,
                createdAt: iso8601(subject.createdAt)
            )
        }

        guard profilePayload != nil || subjects.isEmpty == false else { return }

        let payload = SchoolabeSyncPayload(
            clientUserId: AnalyticsService.shared.userId,
            profile: profilePayload,
            subjects: subjects,
            meta: .init(
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                market: StudentMarketStore.current.rawValue,
                platform: "ios"
            )
        )

        do {
            try await post(payload, to: url)
            AnalyticsService.shared.log(.schoolabeSyncSucceeded(subjectCount: subjects.count))
        } catch {
            AnalyticsService.shared.log(.schoolabeSyncFailed(reason: String(describing: error).prefix(80).description))
        }
    }

    private func post(_ payload: SchoolabeSyncPayload, to url: URL) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BunkPlanner/iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let body = try? encoder.encode(payload) else {
            throw SchoolabeSyncError.encodingFailed
        }
        request.httpBody = body

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SchoolabeSyncError.offline }
        guard (200...299).contains(http.statusCode) else {
            throw SchoolabeSyncError.httpStatus(http.statusCode)
        }
    }

    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
