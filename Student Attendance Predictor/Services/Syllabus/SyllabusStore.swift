//
//  SyllabusStore.swift
//  Student Attendance Predictor
//
//  Persists syllabus documents + learning checklist on device.
//

import Foundation
import Combine

@MainActor
final class SyllabusStore: ObservableObject {
    static let shared = SyllabusStore()

    static let maxDocuments = 20
    static let maxTopicsPerDocument = 80

    @Published private(set) var documents: [SyllabusDocument] = []

    private enum Keys {
        static let documents = "syllabus.documents.v1"
    }

    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    func document(id: UUID) -> SyllabusDocument? {
        documents.first { $0.id == id }
    }

    func documents(for subjectID: UUID?) -> [SyllabusDocument] {
        guard let subjectID else { return documents }
        return documents.filter { $0.subjectID == subjectID }
    }

    @discardableResult
    func createDocument(
        title: String,
        subjectID: UUID?,
        source: SyllabusSource,
        rawText: String = ""
    ) -> SyllabusDocument? {
        guard documents.count < Self.maxDocuments else { return nil }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let doc = SyllabusDocument(
            subjectID: subjectID,
            title: trimmedTitle.isEmpty ? "Syllabus" : String(trimmedTitle.prefix(80)),
            source: source,
            rawText: rawText
        )
        documents.insert(doc, at: 0)
        persist()
        return doc
    }

    func updateDocument(_ document: SyllabusDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        var next = document
        next.updatedAt = Date()
        documents[index] = next
        persist()
    }

    func deleteDocument(id: UUID) {
        documents.removeAll { $0.id == id }
        persist()
    }

    func setRawText(documentID: UUID, text: String, sourceBump: SyllabusSource? = nil) {
        guard var doc = document(id: documentID) else { return }
        doc.rawText = text
        if let sourceBump {
            switch (doc.source, sourceBump) {
            case (.manual, .photo), (.photo, .manual):
                doc.source = .mixed
            case (.mixed, _):
                break
            default:
                if doc.rawText.isEmpty {
                    doc.source = sourceBump
                } else if doc.source != sourceBump {
                    doc.source = .mixed
                }
            }
        }
        updateDocument(doc)
    }

    func replaceUnits(documentID: UUID, units: [SyllabusUnit]) {
        guard var doc = document(id: documentID) else { return }
        var capped = units
        var topicBudget = Self.maxTopicsPerDocument
        for i in capped.indices {
            if capped[i].topics.count > topicBudget {
                capped[i].topics = Array(capped[i].topics.prefix(topicBudget))
            }
            topicBudget -= capped[i].topics.count
            if topicBudget <= 0 {
                capped = Array(capped.prefix(i + 1))
                break
            }
        }
        doc.units = capped
        updateDocument(doc)
    }

    func markUnitLearned(documentID: UUID, unitID: UUID) {
        guard var doc = document(id: documentID) else { return }
        guard let index = doc.units.firstIndex(where: { $0.id == unitID }) else { return }
        for topicIndex in doc.units[index].topics.indices {
            doc.units[index].topics[topicIndex].status = .learned
            doc.units[index].topics[topicIndex].learnedAt = Date()
        }
        updateDocument(doc)
    }

    func setTopicStatus(documentID: UUID, topicID: UUID, status: SyllabusLearnStatus) {
        guard var doc = document(id: documentID) else { return }
        for u in doc.units.indices {
            guard let t = doc.units[u].topics.firstIndex(where: { $0.id == topicID }) else { continue }
            doc.units[u].topics[t].status = status
            doc.units[u].topics[t].learnedAt = status == .learned ? Date() : nil
            updateDocument(doc)
            return
        }
    }

    func linkFocusTopic(documentID: UUID, topicID: UUID, focusTopicID: UUID) {
        guard var doc = document(id: documentID) else { return }
        for u in doc.units.indices {
            guard let t = doc.units[u].topics.firstIndex(where: { $0.id == topicID }) else { continue }
            doc.units[u].topics[t].linkedFocusTopicID = focusTopicID
            if doc.units[u].topics[t].status == .pending {
                doc.units[u].topics[t].status = .inProgress
            }
            updateDocument(doc)
            return
        }
    }

    func topic(linkedToFocusTopicID focusID: UUID) -> (document: SyllabusDocument, topic: SyllabusTopic)? {
        for doc in documents {
            for topic in doc.allTopics where topic.linkedFocusTopicID == focusID {
                return (doc, topic)
            }
        }
        return nil
    }

    /// Build Focus suggestions from pending / in-progress topics (skip learned by default).
    func focusSuggestions(
        for documentID: UUID,
        includeLearned: Bool = false,
        existingFocusNames: [String] = []
    ) -> [FocusTopicSuggestion] {
        guard let doc = document(id: documentID) else { return [] }
        let existing = Set(existingFocusNames.map { $0.lowercased() })
        var suggestions: [FocusTopicSuggestion] = []

        for unit in doc.units {
            for topic in unit.topics {
                if topic.status == .learned && includeLearned == false { continue }
                let name = topic.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard name.isEmpty == false else { continue }
                if existing.contains(name.lowercased()) { continue }
                suggestions.append(
                    FocusTopicSuggestion(
                        title: String(name.prefix(48)),
                        syllabusTopicIDs: [topic.id],
                        isSelected: topic.status != .learned,
                        isCustom: false
                    )
                )
            }
        }
        return suggestions
    }

    /// Apply accepted suggestions into FocusTopicStore and link back.
    @discardableResult
    func applyFocusSuggestions(
        documentID: UUID,
        suggestions: [FocusTopicSuggestion],
        subjectID: UUID?
    ) -> Int {
        guard document(id: documentID) != nil else { return 0 }
        var added = 0
        var firstFocusID: UUID?
        for suggestion in suggestions where suggestion.isSelected {
            let title = suggestion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false else { continue }
            guard let focus = FocusTopicStore.shared.addTopic(
                name: title,
                subjectID: subjectID,
                syllabusTopicID: suggestion.syllabusTopicIDs.first
            ) else { continue }
            added += 1
            if firstFocusID == nil { firstFocusID = focus.id }
            for syllabusTopicID in suggestion.syllabusTopicIDs {
                linkFocusTopic(documentID: documentID, topicID: syllabusTopicID, focusTopicID: focus.id)
            }
        }
        if let firstFocusID {
            FocusTopicStore.shared.selectTopic(id: firstFocusID)
        }
        return added
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.documents),
              let decoded = try? JSONDecoder().decode([SyllabusDocument].self, from: data) else {
            documents = []
            return
        }
        documents = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(documents) {
            defaults.set(data, forKey: Keys.documents)
        }
    }
}
