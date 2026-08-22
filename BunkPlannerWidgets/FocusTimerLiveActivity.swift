//
//  FocusTimerLiveActivity.swift
//  BunkPlannerWidgets
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let focusTint = Color(red: 0.32, green: 0.84, blue: 1.0)
private let breakTint = Color(red: 0.2, green: 0.9, blue: 0.5)
private let markTint = Color(red: 0.98, green: 0.78, blue: 0.2)

struct FocusTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerAttributes.self) { context in
            if context.state.isMarkPrompt {
                FocusTimerMarkPromptLockView(context: context)
                    .activityBackgroundTint(Color(red: 0.06, green: 0.07, blue: 0.12))
            } else {
                FocusTimerLiveActivityLockView(context: context)
                    .activityBackgroundTint(Color(red: 0.06, green: 0.07, blue: 0.12))
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isMarkPrompt {
                        FocusTimerMarkPromptLeading(context: context)
                    } else {
                        FocusTimerPhaseBadge(context: context)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isMarkPrompt {
                        Text("\(context.state.completedFocusMinutes)m")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(markTint)
                    } else {
                        FocusTimerCountdownText(context: context)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isMarkPrompt {
                        FocusTimerMarkPromptButtons(context: context)
                            .padding(.top, 4)
                    } else {
                        FocusTimerLiveActivityProgress(context: context)
                            .padding(.top, 4)
                    }
                }
            } compactLeading: {
                if context.state.isMarkPrompt {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(markTint)
                } else {
                    Image(systemName: context.state.phaseKind == .focus ? "brain.head.profile" : "cup.and.saucer.fill")
                        .foregroundStyle(tint(for: context.state.phaseKind))
                }
            } compactTrailing: {
                if context.state.isMarkPrompt {
                    Text("Mark?")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                } else {
                    FocusTimerCountdownText(context: context)
                        .monospacedDigit()
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            } minimal: {
                if context.state.isMarkPrompt {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(markTint)
                } else {
                    FocusTimerCountdownText(context: context)
                        .monospacedDigit()
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private func tint(for phase: FocusTimerActivityPhase) -> Color {
        phase == .focus ? focusTint : breakTint
    }
}

private struct FocusTimerMarkPromptLockView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(markTint)
                Text("\(context.state.completedFocusMinutes)m focused")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            if let subject = context.state.subjectName, subject.isEmpty == false {
                Text("Mark today's \(subject) class?")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                Text("Mark today's class?")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }

            FocusTimerMarkPromptButtons(context: context)

            FocusTimerLiveActivityProgress(context: context)
        }
        .padding(.horizontal, 4)
    }
}

private struct FocusTimerMarkPromptLeading: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mark class")
                .font(.system(size: 15, weight: .black, design: .rounded))
            if let subject = context.state.subjectName {
                Text(subject)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct FocusTimerMarkPromptButtons: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var body: some View {
        let subjectID = context.state.subjectID ?? ""
        HStack(spacing: 10) {
            Button(intent: MarkFocusSubjectAttendedIntent(subjectID: subjectID)) {
                Label("Attended", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(breakTint)

            Button(intent: MarkFocusSubjectMissedIntent(subjectID: subjectID)) {
                Label("Missed", systemImage: "xmark")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.35))
        }
    }
}

private struct FocusTimerLiveActivityLockView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: context.state.phaseKind == .focus ? "brain.head.profile" : "cup.and.saucer.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(context.state.phaseKind.displayTitle)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                    if context.state.isPaused {
                        Text("Paused")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                }
                .foregroundStyle(tint)

                if let subject = context.state.subjectName, subject.isEmpty == false {
                    Text(subject)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                FocusTimerLiveActivityProgress(context: context)
            }

            Spacer(minLength: 0)

            FocusTimerCountdownText(context: context)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 4)
    }

    private var tint: Color {
        context.state.phaseKind == .focus ? focusTint : breakTint
    }
}

private struct FocusTimerPhaseBadge: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(context.state.phaseKind.displayTitle)
                .font(.system(size: 15, weight: .black, design: .rounded))
            if context.state.isPaused {
                Text("Paused")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FocusTimerLiveActivityProgress: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var body: some View {
        ProgressView(value: min(max(context.state.progress, 0), 1))
            .tint(progressTint)
    }

    private var progressTint: Color {
        switch context.state.phaseKind {
        case .focus: return focusTint
        case .breakTime: return breakTint
        case .markPrompt: return markTint
        }
    }
}

private struct FocusTimerCountdownText: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    var body: some View {
        if context.state.isMarkPrompt, let expires = context.state.markPromptExpiresAt {
            Text(timerInterval: Date.now...expires, countsDown: true)
        } else if context.state.isPaused {
            Text(format(focusSeconds: context.state.pausedRemainingSeconds))
        } else {
            Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
        }
    }

    private func format(focusSeconds seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
