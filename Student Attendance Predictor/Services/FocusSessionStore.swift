//
//  FocusSessionStore.swift
//  Student Attendance Predictor
//
//  Student-facing study log — real sessions, streak, weekly bars.
//

import Foundation
import Combine

struct FocusSession: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let plannedMinutes: Int
    let actualSeconds: Int
    let subjectID: UUID?
    let subjectName: String?
    let topicID: UUID?
    let topicName: String?
    let completed: Bool

    var actualMinutes: Int {
        max(1, Int(round(Double(actualSeconds) / 60.0)))
    }
}

@MainActor
final class FocusSessionStore: ObservableObject {
    static let shared = FocusSessionStore()

    static let maxAgeDays = 90

    @Published private(set) var sessions: [FocusSession] = []

    private enum Keys {
        static let sessions = "focus.sessions.v1"
    }

    private let defaults = UserDefaults.standard
    private var focusSegmentStartedAt: Date?

    init() {
        load()
        prune()
    }

    var focusStreakDays: Int {
        let completedDays = Set(
            sessions.filter(\.completed).map { Self.dayKey(date: $0.endedAt) }
        )
        guard completedDays.isEmpty == false else { return 0 }

        let calendar = Calendar.current
        var cursor = Date()
        // If nothing today yet, start from yesterday so an evening streak still shows.
        if completedDays.contains(Self.dayKey(date: cursor)) == false {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            if completedDays.contains(Self.dayKey(date: cursor)) == false {
                return 0
            }
        }

        var streak = 0
        while completedDays.contains(Self.dayKey(date: cursor)) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    var recentSessions: [FocusSession] {
        Array(sessions.prefix(10))
    }

    func minutesByDayThisWeek() -> [(day: Date, minutes: Int)] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        var result: [(Date, Int)] = []
        var cursor = week.start
        while cursor < week.end {
            let key = Self.dayKey(date: cursor)
            let minutes = sessions
                .filter { $0.completed && Self.dayKey(date: $0.endedAt) == key }
                .reduce(0) { $0 + $1.actualMinutes }
            result.append((cursor, minutes))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    func noteFocusSegmentStarted() {
        focusSegmentStartedAt = Date()
    }

    func recordCompleted(
        plannedMinutes: Int,
        actualSeconds: Int,
        subjectID: UUID?,
        subjectName: String?,
        topicID: UUID?,
        topicName: String?
    ) {
        let ended = Date()
        let started = focusSegmentStartedAt ?? ended.addingTimeInterval(-TimeInterval(actualSeconds))
        focusSegmentStartedAt = nil
        let session = FocusSession(
            id: UUID(),
            startedAt: started,
            endedAt: ended,
            plannedMinutes: plannedMinutes,
            actualSeconds: max(actualSeconds, 60),
            subjectID: subjectID,
            subjectName: subjectName,
            topicID: topicID,
            topicName: topicName,
            completed: true
        )
        sessions.insert(session, at: 0)
        prune()
        persist()
    }

    func recordAbandonedIfNeeded(
        plannedMinutes: Int,
        actualSeconds: Int,
        subjectID: UUID?,
        subjectName: String?,
        topicID: UUID?,
        topicName: String?
    ) {
        guard actualSeconds >= 120 else {
            focusSegmentStartedAt = nil
            return
        }
        let ended = Date()
        let started = focusSegmentStartedAt ?? ended.addingTimeInterval(-TimeInterval(actualSeconds))
        focusSegmentStartedAt = nil
        let session = FocusSession(
            id: UUID(),
            startedAt: started,
            endedAt: ended,
            plannedMinutes: plannedMinutes,
            actualSeconds: actualSeconds,
            subjectID: subjectID,
            subjectName: subjectName,
            topicID: topicID,
            topicName: topicName,
            completed: false
        )
        sessions.insert(session, at: 0)
        prune()
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.sessions),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            sessions = []
            return
        }
        sessions = decoded.sorted { $0.endedAt > $1.endedAt }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            defaults.set(data, forKey: Keys.sessions)
        }
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.maxAgeDays, to: Date()) ?? Date()
        let before = sessions.count
        sessions = sessions.filter { $0.endedAt >= cutoff }
        if sessions.count != before {
            persist()
        }
    }

    static func dayKey(date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
