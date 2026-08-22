//
//  FocusTimerMarkIntents.swift
//  Student Attendance Predictor
//
//  Live Activity buttons after a tagged focus session completes.
//

import AppIntents
import Foundation

struct MarkFocusSubjectAttendedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mark Attended"
    static var description = IntentDescription("Mark today's class as attended.")

    @Parameter(title: "Subject ID")
    var subjectID: String

    init() {
        subjectID = ""
    }

    init(subjectID: String) {
        self.subjectID = subjectID
    }

    func perform() async throws -> some IntentResult {
#if BUNK_PLANNER_WIDGET
        return .result()
#else
        guard let id = UUID(uuidString: subjectID) else { return .result() }
        await AttendanceIntentActions.markSubject(
            subjectID: id,
            attended: true,
            source: "focus_live_activity"
        )
        await FocusTimerService.shared.completeMarkPrompt(status: "attended")
        return .result()
#endif
    }
}

struct MarkFocusSubjectMissedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mark Missed"
    static var description = IntentDescription("Mark today's class as missed.")

    @Parameter(title: "Subject ID")
    var subjectID: String

    init() {
        subjectID = ""
    }

    init(subjectID: String) {
        self.subjectID = subjectID
    }

    func perform() async throws -> some IntentResult {
#if BUNK_PLANNER_WIDGET
        return .result()
#else
        guard let id = UUID(uuidString: subjectID) else { return .result() }
        await AttendanceIntentActions.markSubject(
            subjectID: id,
            attended: false,
            source: "focus_live_activity"
        )
        await FocusTimerService.shared.completeMarkPrompt(status: "missed")
        return .result()
#endif
    }
}
