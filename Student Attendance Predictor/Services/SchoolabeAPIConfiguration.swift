//
//  SchoolabeAPIConfiguration.swift
//  Student Attendance Predictor
//

import Foundation

enum SchoolabeAPIConfiguration {
    /// Override in Info.plist → `SchoolabeAPIBaseURL` when backend is live.
    static var syncURL: URL? {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "SchoolabeAPIBaseURL") as? String,
           configured.isEmpty == false,
           let url = URL(string: configured) {
            return url
        }
        return URL(string: "https://api.schoolabe.com/api/v1/bunk-planner/sync")
    }

    static var isConfigured: Bool { syncURL != nil }
}
