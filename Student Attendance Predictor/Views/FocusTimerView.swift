//
//  FocusTimerView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct FocusTimerView: View {
    @ObservedObject var timer: FocusTimerService
    var subjects: [SubjectSummary] = []

    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @ObservedObject private var topicStore = FocusTopicStore.shared
    @ObservedObject private var sessionStore = FocusSessionStore.shared
    @ObservedObject private var taskStore = StudyTaskStore.shared
    @State private var isShowingProPaywall = false
    @State private var topicStatsScope: FocusTopicStatsScope = .week

    private let cyan = BrandColor.colorAccentPrimary
    private let green = BrandColor.colorAttend
    private let gold = BrandColor.colorPremium

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Timer")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(timer.phaseLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(timer.todayFocusMinutes)m today")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(cyan)
                    if timer.isRunning, FocusTimerLiveActivityService.isSupported {
                        Text("Live on Lock Screen")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(green)
                    } else if timer.markPromptActive {
                        Text("Mark from Lock Screen")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(gold)
                    } else {
                        Text("\(timer.todaySessionCount) session\(timer.todaySessionCount == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.001, timer.progress))
                    .stroke(
                        timer.phase == .breakTime ? green : cyan,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.9), value: timer.remainingSeconds)

                VStack(spacing: 6) {
                    Text(timer.displayTime)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(timer.phase == .breakTime ? "Break" : focusCenterCaption)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)

            if timer.markPromptActive {
                markPromptBanner
            }

            focusTargetPicker

            if timer.selectedTaskID == nil, subjects.isEmpty == false {
                subjectPicker
            }

            if timer.phase == .idle {
                durationPicker
                if entitlements.hasProFeatures {
                    proControls
                } else {
                    proTeaser
                }
            } else if entitlements.hasProFeatures {
                weeklyRecap
            }

            if taskStore.pending.isEmpty {
                topicStatsSection
            }
            studentStudyLog

            controls
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            timer.clampToEntitlement(isPro: entitlements.hasProFeatures)
            timer.reconcileLiveActivityOnLaunchIfNeeded()
            if timer.selectedTaskID == nil,
               timer.phase == .idle,
               let first = taskStore.pending.first {
                timer.selectTask(first)
            }
        }
        .onChange(of: entitlements.hasProFeatures) { _, isUnlocked in
            timer.clampToEntitlement(isPro: isUnlocked)
        }
        .sheet(isPresented: $isShowingProPaywall) {
            ProPaywallView(source: "focus_custom")
        }
        .confirmationDialog(
            timer.pendingTaskWrapUp.map { "\($0.title)" } ?? "Session done",
            isPresented: Binding(
                get: { timer.pendingTaskWrapUp != nil },
                set: { if $0 == false { timer.dismissTaskWrapUp() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Continue") {
                timer.continueSelectedTask()
            }
            if let next = timer.pendingTaskWrapUp?.nextTitle {
                Button("Next: \(next)") {
                    timer.startNextPendingTask()
                }
            }
            if let topic = timer.pendingTaskWrapUp?.firstUncoveredTopic {
                Button("Covered: \(topic.title)") {
                    timer.coverFirstTopicFromWrapUp()
                }
            }
            Button("Mark done") {
                timer.markSelectedTaskDone()
            }
            Button("Not now", role: .cancel) {
                timer.dismissTaskWrapUp()
            }
        } message: {
            Text("Another block, the next task, or mark this done. 25 minutes does not auto-complete it.")
        }
        .alert(
            "Mark as learned?",
            isPresented: Binding(
                get: { timer.pendingSyllabusLearnPrompt != nil },
                set: { if $0 == false { timer.dismissSyllabusLearnedPrompt() } }
            )
        ) {
            Button("Mark learned") {
                timer.confirmSyllabusLearned()
            }
            Button("Not yet", role: .cancel) {
                timer.dismissSyllabusLearnedPrompt()
            }
        } message: {
            if let title = timer.pendingSyllabusLearnPrompt?.title {
                Text("Mark “\(title)” learned on your syllabus checklist?")
            }
        }
    }

    private var rankedTopicsForDisplay: [(topic: FocusTopic, minutes: Int)] {
        topicStore.rankedTopics(scope: topicStatsScope, subjectID: timer.taggedSubjectID)
    }

    private var rankedTopicsMaxMinutes: Int {
        max(rankedTopicsForDisplay.first?.minutes ?? 1, 1)
    }

    private var focusCenterCaption: String {
        if let task = timer.selectedTask {
            return task.title
        }
        if let topic = topicStore.selectedTopic?.name {
            return topic
        }
        return "Focus"
    }

    private var markPromptTopicSuffix: String {
        topicStore.selectedTopic.map { " · \($0.name)" } ?? ""
    }

    private var markPromptBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let name = timer.taggedSubjectName {
                Text("\(timer.selectedFocusMinutes)m focused on \(name)\(markPromptTopicSuffix) — mark today?")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            HStack(spacing: 10) {
                Button {
                    Task { await markFromPrompt(attended: true) }
                } label: {
                    Label("Attended", systemImage: "checkmark")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(green)

                Button {
                    Task { await markFromPrompt(attended: false) }
                } label: {
                    Label("Missed", systemImage: "xmark")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(gold.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(gold.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func markFromPrompt(attended: Bool) async {
        guard let subjectID = timer.taggedSubjectID else { return }
        await AttendanceIntentActions.markSubject(
            subjectID: subjectID,
            attended: attended,
            source: "focus_in_app"
        )
        timer.completeMarkPrompt(status: attended ? "attended" : "missed")
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus length")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 8) {
                ForEach(FocusTimerService.freeFocusOptions, id: \.self) { minutes in
                    durationChip(minutes: minutes, locked: false)
                }
                ForEach(FocusTimerService.proQuickOptions, id: \.self) { minutes in
                    durationChip(minutes: minutes, locked: entitlements.hasProFeatures == false)
                }
            }
        }
    }

    private func durationChip(minutes: Int, locked: Bool) -> some View {
        let selected = timer.selectedFocusMinutes == minutes && locked == false
        return Button {
            if locked {
                AnalyticsService.shared.log(.focusProDurationTapped)
                isShowingProPaywall = true
                return
            }
            timer.selectedFocusMinutes = minutes
        } label: {
            HStack(spacing: 4) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text("\(minutes)m")
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(selected ? .black : locked ? gold : .white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? cyan : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(locked ? gold.opacity(0.45) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var proControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom length")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Stepper(
                    "\(timer.selectedFocusMinutes) minutes",
                    value: $timer.selectedFocusMinutes,
                    in: FocusTimerService.minCustomMinutes...FocusTimerService.maxCustomMinutes,
                    step: 5
                )
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Break")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 8) {
                    ForEach(FocusTimerService.breakOptions, id: \.self) { minutes in
                        Button {
                            timer.selectedBreakMinutes = minutes
                        } label: {
                            Text("\(minutes)m")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(timer.selectedBreakMinutes == minutes ? .black : .white.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(timer.selectedBreakMinutes == minutes ? green : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Daily goal")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Stepper(
                    "\(timer.dailyGoalMinutes) minutes",
                    value: $timer.dailyGoalMinutes,
                    in: 15...180,
                    step: 15
                )
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .onChange(of: timer.dailyGoalMinutes) { _, _ in
                    timer.persistDailyGoal()
                }
            }

            weeklyRecap
        }
    }

    private var weeklyRecap: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This week")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(timer.weekFocusMinutes)m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(cyan)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(cyan)
                        .frame(width: max(8, geo.size.width * timer.dailyGoalProgress))
                }
            }
            .frame(height: 8)
            Text("\(timer.todayFocusMinutes)/\(timer.dailyGoalMinutes)m toward today's goal")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var proTeaser: some View {
        Button {
            AnalyticsService.shared.log(.focusProDurationTapped)
            isShowingProPaywall = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(gold)
                Text("Pro: 90m, custom lengths, longer breaks, weekly recap")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(gold.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tag subject (optional)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tagChip(title: "None", selected: timer.taggedSubjectID == nil) {
                        timer.taggedSubjectID = nil
                        timer.taggedSubjectName = nil
                    }
                    ForEach(subjects) { subject in
                        tagChip(title: subject.name, selected: timer.taggedSubjectID == subject.id) {
                            timer.taggedSubjectID = subject.id
                            timer.taggedSubjectName = subject.name
                        }
                    }
                }
            }
        }
    }

    private var focusTargetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What are you focusing on?")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(taskStore.pending.prefix(8)) { task in
                        taskChip(task)
                    }
                    tagChip(title: "Other", selected: timer.selectedTaskID == nil) {
                        timer.selectOtherFocus()
                    }
                }
            }

            if let task = timer.selectedTask {
                Text("Now: \(task.title) · \(task.displaySubject)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            } else if taskStore.pending.isEmpty {
                Text("No homework in the list. Photo it from Home, or start as Other.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func taskChip(_ task: StudyTask) -> some View {
        let selected = timer.selectedTaskID == task.id
        return Button {
            timer.selectTask(task)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .lineLimit(1)
                Text(task.dueLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? Color.black.opacity(0.55) : cyan.opacity(0.9))
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(selected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? cyan : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var studentStudyLog: some View {
        let streak = sessionStore.focusStreakDays
        let week = sessionStore.minutesByDayThisWeek()
        let maxDay = max(week.map(\.minutes).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR STUDY LOG")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(1.1)
                Spacer()
                if streak > 0 {
                    Text("\(streak)-day focus streak")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(gold)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(entry.minutes > 0 ? cyan : Color.white.opacity(0.08))
                            .frame(height: max(6, CGFloat(entry.minutes) / CGFloat(maxDay) * 48))
                        Text(shortWeekday(entry.day))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70)

            if sessionStore.recentSessions.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    ForEach(sessionStore.recentSessions.prefix(5)) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.topicName ?? session.subjectName ?? "Focus")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(session.endedAt, style: .date)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Text("\(session.actualMinutes)m")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(session.completed ? cyan : .white.opacity(0.45))
                        }
                    }
                }
            }
        }
    }

    private func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private var topicStatsSection: some View {
        Group {
            if topicStore.topics.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Time by topic")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Picker("Range", selection: $topicStatsScope) {
                            Text("Today").tag(FocusTopicStatsScope.today)
                            Text("Week").tag(FocusTopicStatsScope.week)
                            Text("All").tag(FocusTopicStatsScope.allTime)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                    }

                    if rankedTopicsForDisplay.isEmpty {
                        Text("Complete a tagged session to see topic breakdown.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    } else {
                        ForEach(rankedTopicsForDisplay, id: \.topic.id) { entry in
                            topicStatRow(
                                topic: entry.topic,
                                minutes: entry.minutes,
                                maxMinutes: rankedTopicsMaxMinutes
                            )
                        }
                    }
                }
            }
        }
    }

    private func topicStatRow(topic: FocusTopic, minutes: Int, maxMinutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(topic.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text("\(minutes)m")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(cyan)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(cyan.opacity(0.85))
                        .frame(width: max(6, geo.size.width * CGFloat(minutes) / CGFloat(maxMinutes)))
                }
            }
            .frame(height: 6)
            if let subjectID = topic.subjectID,
               let subject = subjects.first(where: { $0.id == subjectID }) {
                Text(subject.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.vertical, 2)
    }

    private func tagChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? .black : .white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? cyan : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var controls: some View {
        if timer.markPromptActive {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                if timer.isRunning {
                    controlButton(title: "Pause", systemImage: "pause.fill", tint: .orange) {
                        timer.pause()
                    }
                } else {
                    controlButton(
                        title: timer.phase == .idle ? "Start" : "Resume",
                        systemImage: "play.fill",
                        tint: cyan
                    ) {
                        NotificationService.requestAuthorizationIfNeeded()
                        timer.startOrResume()
                    }
                }

                controlButton(title: "Reset", systemImage: "arrow.counterclockwise", tint: Color.white.opacity(0.35)) {
                    timer.reset()
                }
            }

            if timer.phase == .focus {
                Button {
                    timer.skipToBreak()
                } label: {
                    Text("Skip to break")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }

            if entitlements.hasProFeatures {
                Toggle(isOn: Binding(
                    get: { timer.autoStartNextFocus },
                    set: { timer.setAutoStartNextFocus($0) }
                )) {
                    Text("Auto-start next focus after break")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .tint(cyan)
            }
        }
    }

    private func controlButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint)
                )
        }
        .buttonStyle(.plain)
    }
}
