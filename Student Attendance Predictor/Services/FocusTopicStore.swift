//
//  FocusTopicStore.swift
//  Student Attendance Predictor
//
//  Topic-wise focus tracking — add topics and see time spent per topic.
//

import Foundation
import Combine

struct FocusTopic: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var subjectID: UUID?
    var createdAt: Date

    init(id: UUID = UUID(), name: String, subjectID: UUID? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.subjectID = subjectID
        self.createdAt = createdAt
    }
}

enum FocusTopicStatsScope: Hashable {
    case today
    case week
    case allTime
}

@MainActor
final class FocusTopicStore: ObservableObject {
    static let shared = FocusTopicStore()

    static let maxTopics = 30

    @Published private(set) var topics: [FocusTopic] = []
    @Published var selectedTopicID: UUID?

    private var allTimeMinutes: [String: Int] = [:]
    private var dailyByTopic: [String: [String: Int]] = [:]

    private enum Keys {
        static let topics = "focus.topics.v1"
        static let allTime = "focus.topics.allTimeMinutes"
        static let daily = "focus.topics.dailyByTopic"
    }

    private let defaults = UserDefaults.standard

    init() {
        load()
        pruneOldDailyEntries()
    }

    var selectedTopic: FocusTopic? {
        guard let selectedTopicID else { return nil }
        return topics.first { $0.id == selectedTopicID }
    }

    func clearSelection() {
        selectedTopicID = nil
    }

    func syncSelectionWithSubject(_ subjectID: UUID?) {
        guard let selectedTopicID, let topic = topics.first(where: { $0.id == selectedTopicID }) else { return }
        guard let linked = topic.subjectID else { return }
        if subjectID == nil || linked != subjectID {
            self.selectedTopicID = nil
        }
    }

    @discardableResult
    func addTopic(name: String, subjectID: UUID?) -> FocusTopic? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard topics.count < Self.maxTopics else { return nil }

        let normalized = trimmed.prefix(48)
        if topics.contains(where: { $0.name.caseInsensitiveCompare(String(normalized)) == .orderedSame && $0.subjectID == subjectID }) {
            return topics.first {
                $0.name.caseInsensitiveCompare(String(normalized)) == .orderedSame && $0.subjectID == subjectID
            }
        }

        let topic = FocusTopic(name: String(normalized), subjectID: subjectID)
        topics.append(topic)
        topics.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistTopics()
        AnalyticsService.shared.log(.focusTopicAdded(hasSubjectLink: subjectID != nil, total: topics.count))
        return topic
    }

    func deleteTopic(id: UUID) {
        topics.removeAll { $0.id == id }
        allTimeMinutes[id.uuidString] = nil
        for day in dailyByTopic.keys {
            dailyByTopic[day]?[id.uuidString] = nil
        }
        if selectedTopicID == id {
            selectedTopicID = nil
        }
        persistTopics()
        persistStats()
    }

    func recordSession(topicID: UUID?, minutes: Int) {
        guard let topicID, minutes > 0 else { return }
        guard topics.contains(where: { $0.id == topicID }) else { return }

        allTimeMinutes[topicID.uuidString, default: 0] += minutes
        let day = Self.dayKey()
        var dayMap = dailyByTopic[day] ?? [:]
        dayMap[topicID.uuidString, default: 0] += minutes
        dailyByTopic[day] = dayMap
        persistStats()
        objectWillChange.send()
    }

    func topics(for subjectID: UUID?) -> [FocusTopic] {
        guard let subjectID else { return topics }
        return topics.filter { $0.subjectID == nil || $0.subjectID == subjectID }
    }

    func minutes(for topicID: UUID, scope: FocusTopicStatsScope) -> Int {
        switch scope {
        case .today:
            return dailyByTopic[Self.dayKey()]?[topicID.uuidString] ?? 0
        case .week:
            return minutesInCurrentWeek(topicID: topicID)
        case .allTime:
            return allTimeMinutes[topicID.uuidString] ?? 0
        }
    }

    func rankedTopics(scope: FocusTopicStatsScope, subjectID: UUID? = nil) -> [(topic: FocusTopic, minutes: Int)] {
        let pool = topics(for: subjectID)
        return pool
            .map { ($0, minutes(for: $0.id, scope: scope)) }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
            }
    }

    func totalMinutes(scope: FocusTopicStatsScope, subjectID: UUID? = nil) -> Int {
        rankedTopics(scope: scope, subjectID: subjectID).reduce(0) { $0 + $1.minutes }
    }

    private func minutesInCurrentWeek(topicID: UUID) -> Int {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return dailyByTopic[Self.dayKey()]?[topicID.uuidString] ?? 0
        }
        var total = 0
        var cursor = week.start
        while cursor < week.end {
            total += dailyByTopic[Self.dayKey(date: cursor)]?[topicID.uuidString] ?? 0
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return total
    }

    private func load() {
        if let data = defaults.data(forKey: Keys.topics),
           let decoded = try? JSONDecoder().decode([FocusTopic].self, from: data) {
            topics = decoded
        }
        if let data = defaults.data(forKey: Keys.allTime),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            allTimeMinutes = decoded
        }
        if let data = defaults.data(forKey: Keys.daily),
           let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            dailyByTopic = decoded
        }
    }

    private func persistTopics() {
        if let data = try? JSONEncoder().encode(topics) {
            defaults.set(data, forKey: Keys.topics)
        }
    }

    private func persistStats() {
        if let data = try? JSONEncoder().encode(allTimeMinutes) {
            defaults.set(data, forKey: Keys.allTime)
        }
        if let data = try? JSONEncoder().encode(dailyByTopic) {
            defaults.set(data, forKey: Keys.daily)
        }
    }

    private func pruneOldDailyEntries() {
        let cutoff = Self.dayKey(date: Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date())
        let before = dailyByTopic.count
        dailyByTopic = dailyByTopic.filter { $0.key >= cutoff }
        if dailyByTopic.count != before {
            persistStats()
        }
    }

    private static func dayKey(date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
