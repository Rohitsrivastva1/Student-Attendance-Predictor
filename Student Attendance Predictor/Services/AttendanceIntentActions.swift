//
//  AttendanceIntentActions.swift
//  Student Attendance Predictor
//
//  Shared actions for Siri, Shortcuts, and Live Activity mark buttons.
//

import Foundation

extension Notification.Name {
    static let attendanceDataChanged = Notification.Name("attendanceDataChanged")
}

@MainActor
enum AttendanceIntentActions {
    static func markSubject(
        subjectID: UUID,
        attended: Bool,
        source: String
    ) async {
        await PersistenceController.shared.waitForStoreIfNeeded()
        let store = SubjectStore()
        let today = Date()
        let scheduled = max(1, store.classesScheduledToday(for: subjectID, on: today))
        store.markDay(
            subjectID: subjectID,
            date: today,
            attendedCount: attended ? scheduled : 0,
            scheduledCount: scheduled,
            isHoliday: false,
            source: source
        )
        NotificationCenter.default.post(name: .attendanceDataChanged, object: nil)
    }

    static func markAllSubjectsAttendedToday(source: String = "siri_shortcut") async -> String {
        await PersistenceController.shared.waitForStoreIfNeeded()
        let store = SubjectStore()
        let today = Date()
        let targets = store.subjectsForMarkToday(on: today).filter {
            store.logEntry(subjectID: $0.id, date: today) == nil
        }

        guard targets.isEmpty == false else {
            return store.hasLoggedToday(date: today)
                ? "You're already marked for today."
                : "Add a subject in Bunk Planner first."
        }

        for subject in targets {
            let scheduled = max(1, store.classesScheduledToday(for: subject.id, on: today))
            store.markDay(
                subjectID: subject.id,
                date: today,
                attendedCount: scheduled,
                scheduledCount: scheduled,
                isHoliday: false,
                source: source
            )
        }

        NotificationCenter.default.post(name: .attendanceDataChanged, object: nil)
        AnalyticsService.shared.log(.siriMarkAllAttended(count: targets.count))

        let noun = targets.count == 1 ? "subject" : "subjects"
        return "Marked \(targets.count) \(noun) attended for today."
    }

    static func safestSkipThisWeekMessage(source: String = "siri_shortcut") async -> String {
        await PersistenceController.shared.waitForStoreIfNeeded()
        let store = SubjectStore()
        AnalyticsService.shared.log(.siriSafestSkipRequested)

        guard store.subjects.isEmpty == false else {
            return "Add a subject in Bunk Planner to see skip advice."
        }

        guard let result = SkipPlanner.safestSkipDay(subjects: store.subjects) else {
            return "No class days found in the next two weeks."
        }

        let market = StudentMarketStore.current
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayName = dayFormatter.string(from: result.date)

        switch result.riskLevel {
        case .safe:
            return "\(dayName) is your safest \(market.skipVerb) this week — all \(result.scheduledSubjectCount) subjects stay above target."
        case .mixed:
            return "\(dayName) is mixed — \(result.safeCount) of \(result.scheduledSubjectCount) subjects stay safe if you \(market.skipVerb)."
        case .unsafe:
            return "No fully safe \(market.skipNounPlural) this week. \(dayName) hits \(result.unsafeCount) subject\(result.unsafeCount == 1 ? "" : "s") — attend if you can."
        case .noClass:
            return "No class days found in the next two weeks."
        }
    }
}
