//
//  GPAModels.swift
//  Student Attendance Predictor
//

import Foundation

enum LetterGrade: String, CaseIterable, Identifiable, Codable {
    case aPlus = "A+"
    case a = "A"
    case aMinus = "A-"
    case bPlus = "B+"
    case b = "B"
    case bMinus = "B-"
    case cPlus = "C+"
    case c = "C"
    case cMinus = "C-"
    case dPlus = "D+"
    case d = "D"
    case f = "F"

    var id: String { rawValue }

    /// Standard US 4.0 scale points.
    var points4_0: Double {
        switch self {
        case .aPlus, .a: return 4.0
        case .aMinus: return 3.7
        case .bPlus: return 3.3
        case .b: return 3.0
        case .bMinus: return 2.7
        case .cPlus: return 2.3
        case .c: return 2.0
        case .cMinus: return 1.7
        case .dPlus: return 1.3
        case .d: return 1.0
        case .f: return 0.0
        }
    }
}

struct GPACourse: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var credits: Double
    var grade: LetterGrade

    init(id: UUID = UUID(), name: String, credits: Double, grade: LetterGrade) {
        self.id = id
        self.name = name
        self.credits = max(0, credits)
        self.grade = grade
    }
}

enum GPACalculator {
    static func cumulativeGPA(courses: [GPACourse]) -> Double? {
        let totalCredits = courses.reduce(0.0) { $0 + $1.credits }
        guard totalCredits > 0 else { return nil }
        let points = courses.reduce(0.0) { $0 + ($1.credits * $1.grade.points4_0) }
        return points / totalCredits
    }

    /// Rough UK degree classification hint from average %.
    static func ukClassification(averagePercent: Double) -> String {
        switch averagePercent {
        case 70...: return "First Class"
        case 60..<70: return "Upper Second (2:1)"
        case 50..<60: return "Lower Second (2:2)"
        case 40..<50: return "Third Class"
        default: return "Below pass"
        }
    }
}

@MainActor
final class GPAStore: ObservableObject {
    @Published private(set) var courses: [GPACourse] = []

    private let key = "academics.gpa.courses"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var gpa: Double? {
        GPACalculator.cumulativeGPA(courses: courses)
    }

    func addCourse(name: String, credits: Double, grade: LetterGrade) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let course = GPACourse(
            name: cleaned.isEmpty ? "Course \(courses.count + 1)" : cleaned,
            credits: credits,
            grade: grade
        )
        courses.append(course)
        persist()
    }

    func update(_ course: GPACourse) {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else { return }
        courses[index] = course
        persist()
    }

    func delete(id: UUID) {
        courses.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GPACourse].self, from: data) else {
            courses = []
            return
        }
        courses = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(courses) {
            defaults.set(data, forKey: key)
        }
    }
}
