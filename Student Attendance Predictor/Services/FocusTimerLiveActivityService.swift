//
//  FocusTimerLiveActivityService.swift
//  Student Attendance Predictor
//
//  Starts / updates / ends the Focus Timer Live Activity.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
enum FocusTimerLiveActivityService {
    #if canImport(ActivityKit)
    private static var currentActivity: Activity<FocusTimerAttributes>?
    #endif

    static var isSupported: Bool {
        #if canImport(ActivityKit)
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        return false
        #endif
    }

    static func sync(
        phase: FocusTimerService.Phase,
        isRunning: Bool,
        remainingSeconds: Int,
        segmentDurationSeconds: Int,
        subjectName: String?
    ) {
        #if canImport(ActivityKit)
        guard isSupported else { return }

        switch phase {
        case .idle:
            end(dismissalPolicy: .immediate)
            return
        case .focus, .breakTime:
            let state = FocusTimerAttributes.ContentState(
                phase: phase == .focus ? FocusTimerActivityPhase.focus.rawValue : FocusTimerActivityPhase.breakTime.rawValue,
                endDate: Date().addingTimeInterval(TimeInterval(max(0, remainingSeconds))),
                isPaused: isRunning == false,
                pausedRemainingSeconds: max(0, remainingSeconds),
                segmentDurationSeconds: max(1, segmentDurationSeconds),
                subjectName: subjectName
            )
            push(state: state, startedPhase: state.phase)
        }
        #endif
    }

    static func showMarkPrompt(
        completedFocusMinutes: Int,
        subjectID: UUID,
        subjectName: String,
        expiresAt: Date,
        promptDurationSeconds: Int = 30
    ) {
        #if canImport(ActivityKit)
        guard isSupported else { return }

        let state = FocusTimerAttributes.ContentState(
            phase: FocusTimerActivityPhase.markPrompt.rawValue,
            endDate: expiresAt,
            isPaused: false,
            pausedRemainingSeconds: 0,
            segmentDurationSeconds: max(1, promptDurationSeconds),
            subjectName: subjectName,
            completedFocusMinutes: completedFocusMinutes,
            subjectID: subjectID.uuidString,
            markPromptExpiresAt: expiresAt
        )
        push(state: state, startedPhase: state.phase)
        AnalyticsService.shared.log(
            .focusMarkPromptShown(minutes: completedFocusMinutes, subjectName: subjectName)
        )
        #endif
    }

    static func end(dismissalPolicy: FocusLiveActivityDismissal = .default) {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else { return }
        currentActivity = nil
        let policy: ActivityUIDismissalPolicy = dismissalPolicy.activityPolicy
        Task {
            await activity.end(nil, dismissalPolicy: policy)
            AnalyticsService.shared.log(.focusLiveActivityEnded)
        }
        #endif
    }

    static func reconcileOnLaunch(
        phase: FocusTimerService.Phase,
        isRunning: Bool,
        remainingSeconds: Int,
        segmentDurationSeconds: Int,
        subjectName: String?,
        markPromptActive: Bool
    ) {
        #if canImport(ActivityKit)
        currentActivity = Activity<FocusTimerAttributes>.activities.first
        if phase == .idle, markPromptActive == false {
            if currentActivity != nil {
                end(dismissalPolicy: .immediate)
            }
            return
        }
        if markPromptActive {
            return
        }
        sync(
            phase: phase,
            isRunning: isRunning,
            remainingSeconds: remainingSeconds,
            segmentDurationSeconds: segmentDurationSeconds,
            subjectName: subjectName
        )
        #endif
    }

    enum FocusLiveActivityDismissal {
        case `default`
        case immediate

        #if canImport(ActivityKit)
        var activityPolicy: ActivityUIDismissalPolicy {
            switch self {
            case .default: return .default
            case .immediate: return .immediate
            }
        }
        #endif
    }

    #if canImport(ActivityKit)
    private static func push(state: FocusTimerAttributes.ContentState, startedPhase: String) {
        if currentActivity == nil {
            start(state: state, startedPhase: startedPhase)
        } else {
            update(state: state)
        }
    }

    private static func start(state: FocusTimerAttributes.ContentState, startedPhase: String) {
        let attributes = FocusTimerAttributes(sessionLabel: "Focus Timer")
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            if startedPhase != FocusTimerActivityPhase.markPrompt.rawValue {
                AnalyticsService.shared.log(.focusLiveActivityStarted(phase: startedPhase))
            }
        } catch {
            currentActivity = nil
        }
    }

    private static func update(state: FocusTimerAttributes.ContentState) {
        guard let activity = currentActivity else {
            start(state: state, startedPhase: state.phase)
            return
        }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }
    #endif
}
