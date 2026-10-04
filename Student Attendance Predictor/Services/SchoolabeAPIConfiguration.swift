//
//  SchoolabeAPIConfiguration.swift
//  Student Attendance Predictor
//

import Foundation

enum SchoolabeAPIConfiguration {
    static let productionSyncURL = "https://api.schoolabe.com/api/v1/bunk-planner/sync"
    static let localSimulatorSyncURL = "http://127.0.0.1:8000/api/v1/bunk-planner/sync"
    static let debugOverrideKey = "debug.schoolabeAPIBaseURL"

    /// Simulator always uses local FastAPI. Info.plist production URL is ignored there.
    /// Physical device uses production, or a Debug override for your Mac's LAN IP.
    static var syncURL: URL? {
        #if targetEnvironment(simulator)
        return URL(string: localSimulatorSyncURL)
        #else
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: debugOverrideKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           override.isEmpty == false,
           let url = URL(string: override) {
            return url
        }
        #endif
        if let configured = Bundle.main.object(forInfoDictionaryKey: "SchoolabeAPIBaseURL") as? String,
           configured.isEmpty == false,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: productionSyncURL)
        #endif
    }

    static var isConfigured: Bool { syncURL != nil }

    static var isUsingLocalServer: Bool {
        guard let host = syncURL?.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost" || host.hasPrefix("192.168.") || host.hasPrefix("10.")
    }

    static var deleteUserDataURL: URL? {
        guard let sync = syncURL else { return nil }
        return sync.deletingLastPathComponent().appendingPathComponent("user-data")
    }

    /// Batched product analytics: screens, session time, setup funnel, daily activity.
    static var eventsURL: URL? {
        guard let sync = syncURL else { return nil }
        return sync.deletingLastPathComponent().appendingPathComponent("events")
    }

    static var inviteEnsureURL: URL? {
        inviteURL("ensure")
    }

    static var inviteRedeemURL: URL? {
        inviteURL("redeem")
    }

    static var inviteClaimURL: URL? {
        inviteURL("claim")
    }

    /// Groq-backed syllabus structure. Key: `GROQ_SYLLABUS_API_KEY` on Schoolabe only.
    static var syllabusStructureURL: URL? {
        guard let sync = syncURL else { return nil }
        return sync.deletingLastPathComponent().appendingPathComponent("syllabus/structure")
    }

    /// Groq-backed homework / exam extract. Same Groq key as syllabus.
    static var tasksExtractURL: URL? {
        guard let sync = syncURL else { return nil }
        return sync.deletingLastPathComponent().appendingPathComponent("tasks/extract")
    }

    #if DEBUG
    static func setDebugSyncURL(_ raw: String?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: debugOverrideKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: debugOverrideKey)
        }
    }
    #endif

    private static func inviteURL(_ action: String) -> URL? {
        guard let sync = syncURL else { return nil }
        return sync
            .deletingLastPathComponent()
            .appendingPathComponent("invite")
            .appendingPathComponent(action)
    }
}
