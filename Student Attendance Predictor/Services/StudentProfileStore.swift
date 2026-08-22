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
            profile = decoded
        } else {
            profile = .empty
        }
        didSkipProfile = defaults.bool(forKey: Keys.didSkip)
        didCompleteProfileStep = defaults.bool(forKey: Keys.didComplete)
    }

    func save(_ profile: StudentProfile, skipped: Bool) {
        self.profile = profile
        didSkipProfile = skipped
        didCompleteProfileStep = true
        defaults.set(skipped, forKey: Keys.didSkip)
        defaults.set(true, forKey: Keys.didComplete)
        if let data = try? encoder.encode(profile) {
            defaults.set(data, forKey: Keys.profileJSON)
        }
        NotificationCenter.default.post(name: .studentProfileDidUpdate, object: nil)
        AnalyticsService.shared.setUserProperty(skipped ? "skipped" : "completed", forName: "student_profile_status")
        if profile.name.isEmpty == false {
            AnalyticsService.shared.setUserProperty(String(profile.name.prefix(24)), forName: "student_name_initial")
        }
        if profile.classOrDegree.isEmpty == false {
            AnalyticsService.shared.setUserProperty(String(profile.classOrDegree.prefix(32)), forName: "student_class")
        }
    }

    func update(_ profile: StudentProfile) {
        save(profile, skipped: false)
    }
}
