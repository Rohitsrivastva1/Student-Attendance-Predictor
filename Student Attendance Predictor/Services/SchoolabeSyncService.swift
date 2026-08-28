//
//  SchoolabeSyncService.swift
//  Student Attendance Predictor
//
//  Single upsert API: profile, subjects, full attendance log, last_active_date, is_pro.
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

    struct AttendancePayload: Encodable {
        let id: String
        let subjectId: String
        let date: String
        let scheduledClasses: Int
        let attendedClasses: Int
        let isHoliday: Bool
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case subjectId = "subject_id"
            case date
            case scheduledClasses = "scheduled_classes"
            case attendedClasses = "attended_classes"
            case isHoliday = "is_holiday"
            case updatedAt = "updated_at"
        }
    }

    struct MetaPayload: Encodable {
        let appVersion: String
        let market: String
        let platform: String
        let isPro: Bool

        enum CodingKeys: String, CodingKey {
            case appVersion = "app_version"
            case market, platform
            case isPro = "is_pro"
        }
    }

    let clientUserId: String
    let profile: ProfilePayload?
    let subjects: [SubjectPayload]
    let attendanceEntries: [AttendancePayload]?
    let lastActiveDate: String?
    let meta: MetaPayload

    enum CodingKeys: String, CodingKey {
        case profile, subjects, meta
        case clientUserId = "client_user_id"
        case attendanceEntries = "attendance_entries"
        case lastActiveDate = "last_active_date"
    }
}

enum SchoolabeSyncError: Error, LocalizedError {
    case invalidURL
    case offline
    case httpStatus(Int)
    case encodingFailed
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Schoolabe API URL is invalid."
        case .offline: return "No network connection."
        case let .httpStatus(code): return "Schoolabe API returned HTTP \(code)."
        case .encodingFailed: return "Could not encode sync payload."
        case let .deleteFailed(message): return message
        }
    }
}

private struct SchoolabeDeleteUserDataPayload: Encodable {
    let clientUserId: String

    enum CodingKeys: String, CodingKey {
        case clientUserId = "client_user_id"
    }
}

@MainActor
final class SchoolabeSyncService {
    static let shared = SchoolabeSyncService()

    private var syncTask: Task<Void, Never>?
    private let session: URLSession
    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private enum Keys {
        static let lastActiveSyncedDay = "schoolabe.lastActiveSyncedDay"
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Debounced sync — call after profile save, subject changes, or attendance marks.
    func scheduleSync(subjectStore: SubjectStore?) {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard Task.isCancelled == false else { return }
            await sync(subjectStore: subjectStore)
        }
    }

    /// Once per local calendar day when the app opens — stamps last_active_date.
    func scheduleActiveTodaySyncIfNeeded(subjectStore: SubjectStore?) {
        let today = dateOnlyFormatter.string(from: Date())
        let last = UserDefaults.standard.string(forKey: Keys.lastActiveSyncedDay)
        guard last != today else { return }
        scheduleSync(subjectStore: subjectStore)
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

        let attendanceEntries: [SchoolabeSyncPayload.AttendancePayload]? = {
            guard let subjectStore else { return nil }
            return subjectStore.allLogEntries().map { entry in
                SchoolabeSyncPayload.AttendancePayload(
                    id: entry.id.uuidString,
                    subjectId: entry.subjectID.uuidString,
                    date: dateOnlyFormatter.string(from: entry.date),
                    scheduledClasses: entry.scheduledClasses,
                    attendedClasses: entry.attendedClasses,
                    isHoliday: entry.isHoliday,
                    updatedAt: iso8601(entry.updatedAt)
                )
            }
        }()

        let today = dateOnlyFormatter.string(from: Date())
        let hasAttendance = (attendanceEntries?.isEmpty == false)
        let shouldSync = profilePayload != nil
            || subjects.isEmpty == false
            || hasAttendance
            || UserDefaults.standard.bool(forKey: "onboarding.didComplete")
        guard shouldSync else { return }

        let payload = SchoolabeSyncPayload(
            clientUserId: AnalyticsService.shared.userId,
            profile: profilePayload,
            subjects: subjects,
            attendanceEntries: attendanceEntries,
            lastActiveDate: today,
            meta: .init(
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                market: StudentMarketStore.current.rawValue,
                platform: "ios",
                isPro: AdEntitlementsStore.shared.isPro
            )
        )

        do {
            try await post(payload, to: url)
            UserDefaults.standard.set(today, forKey: Keys.lastActiveSyncedDay)
            AnalyticsService.shared.log(.schoolabeSyncSucceeded(subjectCount: subjects.count))
        } catch {
            AnalyticsService.shared.log(.schoolabeSyncFailed(reason: String(describing: error).prefix(80).description))
        }
    }

    /// Soft-delete flag on Schoolabe for this anonymous client id.
    func deleteUserData() async throws {
        guard SchoolabeAPIConfiguration.isConfigured,
              let url = SchoolabeAPIConfiguration.deleteUserDataURL else {
            throw SchoolabeSyncError.invalidURL
        }

        let payload = SchoolabeDeleteUserDataPayload(
            clientUserId: AnalyticsService.shared.userId
        )
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
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
        AnalyticsService.shared.log(.schoolabeUserDataDeleted)
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
