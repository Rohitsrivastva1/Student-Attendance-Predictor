//
//  SyllabusModels.swift
//  Student Attendance Predictor
//
//  On-device syllabus outline + learning checklist.
//

import Foundation

enum SyllabusLearnStatus: String, Codable, CaseIterable {
    case pending
    case inProgress
    case learned

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In progress"
        case .learned: return "Learned"
        }
    }
}

enum SyllabusSource: String, Codable {
    case photo
    case manual
    case mixed
}

struct SyllabusTopic: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String?
    var status: SyllabusLearnStatus
    var learnedAt: Date?
    var linkedFocusTopicID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        status: SyllabusLearnStatus = .pending,
        learnedAt: Date? = nil,
        linkedFocusTopicID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.learnedAt = learnedAt
        self.linkedFocusTopicID = linkedFocusTopicID
    }
}

struct SyllabusUnit: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var topics: [SyllabusTopic]

    init(id: UUID = UUID(), title: String, topics: [SyllabusTopic] = []) {
        self.id = id
        self.title = title
        self.topics = topics
    }
}

struct SyllabusDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var subjectID: UUID?
    var title: String
    var source: SyllabusSource
    var rawText: String
    var units: [SyllabusUnit]
    var updatedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        subjectID: UUID? = nil,
        title: String,
        source: SyllabusSource,
        rawText: String = "",
        units: [SyllabusUnit] = [],
        updatedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.subjectID = subjectID
        self.title = title
        self.source = source
        self.rawText = rawText
        self.units = units
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }

    var allTopics: [SyllabusTopic] {
        units.flatMap(\.topics)
    }

    var learnedCount: Int {
        allTopics.filter { $0.status == .learned }.count
    }

    var totalTopicCount: Int {
        allTopics.count
    }

    var progressFraction: Double {
        guard totalTopicCount > 0 else { return 0 }
        return Double(learnedCount) / Double(totalTopicCount)
    }

    var progressLabel: String {
        "\(learnedCount) of \(totalTopicCount) learned"
    }
}

struct FocusTopicSuggestion: Identifiable, Equatable {
    let id: UUID
    var title: String
    var syllabusTopicIDs: [UUID]
    var isSelected: Bool
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        title: String,
        syllabusTopicIDs: [UUID] = [],
        isSelected: Bool = true,
        isCustom: Bool = false
    ) {
        self.id = id
        self.title = title
        self.syllabusTopicIDs = syllabusTopicIDs
        self.isSelected = isSelected
        self.isCustom = isCustom
    }
}
