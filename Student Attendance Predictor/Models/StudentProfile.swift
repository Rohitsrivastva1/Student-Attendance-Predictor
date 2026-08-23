//
//  StudentProfile.swift
//  Student Attendance Predictor
//

import Foundation

/// Lightweight student profile — synced to Schoolabe when complete.
struct StudentProfile: Codable, Equatable {
    var name: String
    var age: Int?
    var classOrDegree: String
    var institutionName: String

    static let empty = StudentProfile(
        name: "",
        age: nil,
        classOrDegree: "",
        institutionName: ""
    )

    var hasAnyField: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || age != nil
            || classOrDegree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var isCompleteEnoughToSync: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && classOrDegree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

enum StudyLevelChip: String, CaseIterable, Identifiable {
    case class11 = "Class 11"
    case class12 = "Class 12"
    case ug1 = "UG 1st year"
    case ug2 = "UG 2nd year"
    case ug3 = "UG 3rd year"
    case ug4 = "UG 4th year"
    case pg = "PG"
    case diploma = "Diploma"

    var id: String { rawValue }
}
