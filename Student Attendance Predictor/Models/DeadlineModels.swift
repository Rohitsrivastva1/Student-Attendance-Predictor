//
//  DeadlineModels.swift
//  Student Attendance Predictor
//

import Foundation

enum AcademicDeadlineKind: String, CaseIterable, Identifiable, Codable {
    case exam
    case assignment
    case project
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exam: return "Exam"
        case .assignment: return "Assignment"
        case .project: return "Project"
        case .other: return "Deadline"
        }
    }

    var systemImage: String {
        switch self {
        case .exam: return "pencil.and.list.clipboard"
        case .assignment: return "doc.text.fill"
        case .project: return "shippingbox.fill"
        case .other: return "flag.fill"
        }
    }
}

struct AcademicDeadline: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var dueDate: Date
    var kind: AcademicDeadlineKind
    var courseName: String
    var notes: String

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date,
        kind: AcademicDeadlineKind,
        courseName: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.kind = kind
        self.courseName = courseName
        self.notes = notes
    }

    var daysRemaining: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: dueDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    var countdownLabel: String {
        let days = daysRemaining
        if days < 0 { return "\(-days)d overdue" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days left"
    }
}

@MainActor
final class DeadlineStore: ObservableObject {
    @Published private(set) var deadlines: [AcademicDeadline] = []

    private let key = "academics.deadlines"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var upcoming: [AcademicDeadline] {
        deadlines
            .filter { $0.daysRemaining >= 0 }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var past: [AcademicDeadline] {
        deadlines
            .filter { $0.daysRemaining < 0 }
            .sorted { $0.dueDate > $1.dueDate }
    }

    func add(_ deadline: AcademicDeadline) {
        deadlines.append(deadline)
        persist()
    }

    func update(_ deadline: AcademicDeadline) {
        guard let index = deadlines.firstIndex(where: { $0.id == deadline.id }) else { return }
        deadlines[index] = deadline
        persist()
    }

    func delete(id: UUID) {
        deadlines.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AcademicDeadline].self, from: data) else {
            deadlines = []
            return
        }
        deadlines = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(deadlines) {
            defaults.set(data, forKey: key)
        }
    }
}
