//
//  FocusTimerActivityAttributes.swift
//  Student Attendance Predictor
//
//  Shared ActivityKit model — compiled into the app and widget extension.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct FocusTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var endDate: Date
        var isPaused: Bool
        var pausedRemainingSeconds: Int
        var segmentDurationSeconds: Int
        var subjectName: String?
        var completedFocusMinutes: Int
        var subjectID: String?
        var markPromptExpiresAt: Date?

        init(
            phase: String,
            endDate: Date,
            isPaused: Bool,
            pausedRemainingSeconds: Int,
            segmentDurationSeconds: Int,
            subjectName: String? = nil,
            completedFocusMinutes: Int = 0,
            subjectID: String? = nil,
            markPromptExpiresAt: Date? = nil
        ) {
            self.phase = phase
            self.endDate = endDate
            self.isPaused = isPaused
            self.pausedRemainingSeconds = pausedRemainingSeconds
            self.segmentDurationSeconds = segmentDurationSeconds
            self.subjectName = subjectName
            self.completedFocusMinutes = completedFocusMinutes
            self.subjectID = subjectID
            self.markPromptExpiresAt = markPromptExpiresAt
        }
    }

    var sessionLabel: String
}
#endif

enum FocusTimerActivityPhase: String {
    case focus
    case breakTime = "break"
    case markPrompt

    var displayTitle: String {
        switch self {
        case .focus: return "Focus"
        case .breakTime: return "Break"
        case .markPrompt: return "Mark class"
        }
    }
}

#if canImport(ActivityKit)
extension FocusTimerAttributes.ContentState {
    var phaseKind: FocusTimerActivityPhase {
        FocusTimerActivityPhase(rawValue: phase) ?? .focus
    }

    var isMarkPrompt: Bool {
        phaseKind == .markPrompt
    }

    var progress: Double {
        guard segmentDurationSeconds > 0 else { return 0 }
        if phaseKind == .markPrompt, let expires = markPromptExpiresAt {
            let total = Double(segmentDurationSeconds)
            let remaining = max(0, expires.timeIntervalSinceNow)
            return 1 - (remaining / total)
        }
        if isPaused {
            return 1 - (Double(pausedRemainingSeconds) / Double(segmentDurationSeconds))
        }
        let remaining = max(0, endDate.timeIntervalSinceNow)
        return 1 - (remaining / Double(segmentDurationSeconds))
    }
}
#endif
