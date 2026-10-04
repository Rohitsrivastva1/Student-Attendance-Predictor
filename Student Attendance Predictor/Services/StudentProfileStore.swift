//
//  StudentProfileStore.swift
//  Student Attendance Predictor
//

import Foundation
import Combine

@MainActor
final class StudentProfileStore: ObservableObject {
    static let shared = StudentProfileStore()

    @Published private(set) var profile: StudentProfile
    @Published private(set) var didSkipProfile: Bool
    @Published private(set) var didCompleteProfileStep: Bool

    private enum Keys {
        static let profileJSON = "student.profile.json"
        static let didSkip = "student.profile.didSkip"
        static let didComplete = "student.profile.didComplete"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.profileJSON),
           let decoded = try? decoder.decode(StudentProfile.self, from: data) {
            var migrated = decoded
            let normalized = InstitutionNameQuality.normalizedForStorage(decoded.institutionName)
            if normalized != decoded.institutionName {
                migrated.institutionName = normalized
                if let encoded = try? encoder.encode(migrated) {
                    defaults.set(encoded, forKey: Keys.profileJSON)
                }
            }
            profile = migrated
        } else {
            profile = .empty
        }
        didSkipProfile = defaults.bool(forKey: Keys.didSkip)
        didCompleteProfileStep = defaults.bool(forKey: Keys.didComplete)
    }

    func save(_ profile: StudentProfile, skipped: Bool) {
        var cleaned = profile
        cleaned.institutionName = InstitutionNameQuality.normalizedForStorage(profile.institutionName)
        self.profile = cleaned
        didSkipProfile = skipped
        didCompleteProfileStep = true
        defaults.set(skipped, forKey: Keys.didSkip)
        defaults.set(true, forKey: Keys.didComplete)
        if let data = try? encoder.encode(cleaned) {
            defaults.set(data, forKey: Keys.profileJSON)
        }
        NotificationCenter.default.post(name: .studentProfileDidUpdate, object: nil)
        AnalyticsService.shared.setUserProperty(skipped ? "skipped" : "completed", forName: "student_profile_status")
        if cleaned.name.isEmpty == false {
            AnalyticsService.shared.setUserProperty(String(cleaned.name.prefix(24)), forName: "student_name_initial")
        }
        if cleaned.classOrDegree.isEmpty == false {
            AnalyticsService.shared.setUserProperty(String(cleaned.classOrDegree.prefix(32)), forName: "student_class")
        }
        if cleaned.institutionName.isEmpty == false {
            AnalyticsService.shared.setUserProperty(
                String(cleaned.institutionName.prefix(40)),
                forName: "student_institution"
            )
        }
    }

    func update(_ profile: StudentProfile) {
        save(profile, skipped: false)
    }

    func clearLocalProfile() {
        profile = .empty
        didSkipProfile = false
        defaults.removeObject(forKey: Keys.profileJSON)
        defaults.set(false, forKey: Keys.didSkip)
        AnalyticsService.shared.setUserProperty(nil, forName: "student_profile_status")
        AnalyticsService.shared.setUserProperty(nil, forName: "student_name_initial")
        AnalyticsService.shared.setUserProperty(nil, forName: "student_class")
        NotificationCenter.default.post(name: .studentProfileDidUpdate, object: nil)
    }
}
