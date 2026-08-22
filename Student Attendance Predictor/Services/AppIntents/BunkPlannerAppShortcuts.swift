//
//  BunkPlannerAppShortcuts.swift
//  Student Attendance Predictor
//
//  Siri phrases and Shortcuts app discovery.
//

import AppIntents

struct SafestSkipThisWeekIntent: AppIntent {
    static var title: LocalizedStringResource = "Safest Skip This Week"
    static var description = IntentDescription("Find the safest day to skip class in the next week.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await AttendanceIntentActions.safestSkipThisWeekMessage()
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct MarkAllSubjectsAttendedTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark All Attended Today"
    static var description = IntentDescription("Mark every subject scheduled today as attended.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await AttendanceIntentActions.markAllSubjectsAttendedToday()
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct BunkPlannerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SafestSkipThisWeekIntent(),
            phrases: [
                "Where's my safest bunk this week in \(.applicationName)",
                "Where's my safest skip this week in \(.applicationName)",
                "Safest bunk this week in \(.applicationName)",
                "Safest skip this week in \(.applicationName)"
            ],
            shortTitle: "Safest Skip",
            systemImageName: "calendar.badge.minus"
        )
        AppShortcut(
            intent: MarkAllSubjectsAttendedTodayIntent(),
            phrases: [
                "Mark all subjects attended today in \(.applicationName)",
                "Mark everyone attended in \(.applicationName)",
                "Mark today attended in \(.applicationName)"
            ],
            shortTitle: "Mark All Attended",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
