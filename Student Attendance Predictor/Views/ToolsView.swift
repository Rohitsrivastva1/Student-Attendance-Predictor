//
//  ToolsView.swift
//  Student Attendance Predictor
//
//  Hub for study utilities — Focus Timer, CGPA/GPA, exam deadlines, planning, exports.
//

import SwiftUI

struct ToolsView: View {
    @ObservedObject var subjectStore: SubjectStore
    @ObservedObject var gpaStore: GPAStore
    @ObservedObject var deadlineStore: DeadlineStore
    @Binding var navigateToDeadlines: Bool
    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @ObservedObject private var focusTimer = FocusTimerService.shared
    @ObservedObject private var syllabusStore = SyllabusStore.shared
    @ObservedObject private var studyTasks = StudyTaskStore.shared

    @State private var showDeadlinesScreen = false

    init(
        subjectStore: SubjectStore,
        gpaStore: GPAStore,
        deadlineStore: DeadlineStore,
        navigateToDeadlines: Binding<Bool> = .constant(false)
    ) {
        self.subjectStore = subjectStore
        self.gpaStore = gpaStore
        self.deadlineStore = deadlineStore
        _navigateToDeadlines = navigateToDeadlines
    }

    private var subjects: [SubjectSummary] { subjectStore.subjects }
    private var market: StudentMarket { StudentMarketStore.current }

    /// Flip to `true` to show Syllabus again in Tools. Implementation stays in the project.
    private static let showSyllabusInTools = false

    private let cyan = BrandColor.colorAccentPrimary
    private let gold = BrandColor.colorPremium
    private let coral = BrandColor.colorMissed

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            toolsHeader

            if shouldShowFocusDiscoveryHero {
                focusDiscoveryHero
            }

            toolSection(title: "Study") {
                NavigationLink {
                    FocusTimerToolScreen(subjects: subjects)
                } label: {
                    ToolHubRow(
                        icon: "brain.head.profile",
                        tint: cyan,
                        title: "Focus Timer",
                        subtitle: focusTimerSubtitle
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    StudyTaskListScreen(subjects: subjects)
                } label: {
                    ToolHubRow(
                        icon: "checkmark.circle.fill",
                        tint: cyan,
                        title: "Tasks",
                        subtitle: tasksToolSubtitle
                    )
                }
                .buttonStyle(.plain)

                if Self.showSyllabusInTools {
                    NavigationLink {
                        SyllabusToolScreen(subjects: subjects)
                    } label: {
                        ToolHubRow(
                            icon: "list.bullet.clipboard.fill",
                            tint: cyan,
                            title: "Syllabus",
                            subtitle: syllabusToolSubtitle
                        )
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    AcademicsView(
                        gpaStore: gpaStore,
                        deadlineStore: deadlineStore,
                        subjects: subjects,
                        mode: .grades
                    )
                } label: {
                    ToolHubRow(
                        icon: "graduationcap.fill",
                        tint: gold,
                        title: gradesToolTitle,
                        subtitle: gradesToolSubtitle
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AcademicsView(
                        gpaStore: gpaStore,
                        deadlineStore: deadlineStore,
                        subjects: subjects,
                        mode: .deadlines
                    )
                } label: {
                    ToolHubRow(
                        icon: "calendar.badge.clock",
                        tint: coral,
                        title: "Exam Deadlines",
                        subtitle: deadlinesToolSubtitle
                    )
                }
                .buttonStyle(.plain)
            }

            toolSection(title: "Reports") {
                NavigationLink {
                    ExportToolScreen(subjectStore: subjectStore, gpaStore: gpaStore)
                } label: {
                    ToolHubRow(
                        icon: "square.and.arrow.up.on.square",
                        tint: cyan,
                        title: "Export Reports",
                        subtitle: exportToolSubtitle,
                        showsLock: !entitlements.hasProFeatures
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            AnalyticsService.shared.setScreen(.tools)
            AnalyticsService.shared.log(
                .toolsViewed(
                    focusMinutesToday: focusTimer.todayFocusMinutes,
                    courseCount: gpaStore.activeCourses.count,
                    deadlineCount: deadlineStore.upcoming.count
                )
            )
        }
        .onChange(of: navigateToDeadlines) { _, shouldOpen in
            guard shouldOpen else { return }
            showDeadlinesScreen = true
            navigateToDeadlines = false
        }
        .navigationDestination(isPresented: $showDeadlinesScreen) {
            AcademicsView(
                gpaStore: gpaStore,
                deadlineStore: deadlineStore,
                subjects: subjects,
                mode: .deadlines
            )
        }
    }

    private var toolsHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("More tools")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Focus, tasks, grades, and extras. Skip planner stays on Plan.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// W1 / first-use hook — Focus is the only Tools habit that reinforces daily return.
    private var shouldShowFocusDiscoveryHero: Bool {
        focusTimer.todayFocusMinutes == 0
            && focusTimer.isRunning == false
            && AnalyticsService.shared.daysSinceInstall < 14
    }

    private var focusDiscoveryHero: some View {
        NavigationLink {
            FocusTimerToolScreen(subjects: subjects)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(cyan.opacity(0.2))
                        .frame(width: 52, height: 52)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(cyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start a Focus session")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Mark done? Lock in 25 minutes on today’s subject.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(cyan))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [cyan.opacity(0.18), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(cyan.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            AnalyticsService.shared.log(.homePromoCardTapped(kind: "focus", action: "tools_hero"))
            MultiFeatureEngagementStore.record(.focus)
        })
    }

    @ViewBuilder
    private func toolSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.1)
            VStack(spacing: 12) {
                content()
            }
        }
    }

    private var gradesToolTitle: String {
        switch market {
        case .india: return "CGPA Calculator"
        case .unitedKingdom: return "Module Marks"
        case .unitedStates, .other: return "GPA Calculator"
        }
    }

    private var focusTimerSubtitle: String {
        if focusTimer.markPromptActive {
            return "Mark today's class from Lock Screen"
        }
        if focusTimer.isRunning {
            return "Session running · Live on Lock Screen"
        }
        let streak = FocusSessionStore.shared.focusStreakDays
        if streak >= 2 {
            return "\(streak)-day focus streak · \(focusTimer.todayFocusMinutes)m today"
        }
        if focusTimer.todayFocusMinutes > 0 {
            return "\(focusTimer.todayFocusMinutes)m focused today · \(focusTimer.todaySessionCount) session\(focusTimer.todaySessionCount == 1 ? "" : "s")"
        }
        if studyTasks.pending.isEmpty == false {
            return "Pick a task from your list, or Other"
        }
        return "Pomodoro timer · pick a task or Other"
    }

    private var tasksToolSubtitle: String {
        let due = studyTasks.dueSoon.count
        if due > 0 {
            return "\(due) due soon · photo to add more"
        }
        if studyTasks.pending.isEmpty == false {
            return "\(studyTasks.pending.count) open · photo or paste"
        }
        return "Photo a diary or datesheet · one tap to add"
    }

    private var syllabusToolSubtitle: String {
        let docs = syllabusStore.documents
        if docs.isEmpty {
            return "Photo or type · checklist · send to Focus"
        }
        let learned = docs.reduce(0) { $0 + $1.learnedCount }
        let total = docs.reduce(0) { $0 + $1.totalTopicCount }
        if total == 0 {
            return "\(docs.count) syllabus · add topics to track"
        }
        return "\(learned) of \(total) topics learned"
    }

    private var gradesToolSubtitle: String {
        if let summary = gpaStore.toolsScoreSummary(market: market) {
            return summary
        }
        switch market {
        case .india: return "10-point CGPA + semester target planner"
        case .unitedKingdom: return "Module % and classification"
        case .unitedStates, .other: return "4.0 GPA + target planner"
        }
    }

    private var deadlinesToolSubtitle: String {
        let upcoming = deadlineStore.upcoming.count
        if upcoming == 0 {
            return "No upcoming exams — tap to add reminders"
        }
        if upcoming == 1, let next = deadlineStore.upcoming.first {
            return "1 upcoming · \(next.title)"
        }
        return "\(upcoming) upcoming exams and deadlines"
    }

    private var exportToolSubtitle: String {
        if !entitlements.hasProFeatures {
            return "PDF summary & CSV log · Pro"
        }
        let count = subjects.count
        if count == 0 {
            return "PDF summary & CSV log"
        }
        return "Export \(count) subject\(count == 1 ? "" : "s") · PDF or CSV"
    }
}

struct FocusTimerToolScreen: View {
    var subjects: [SubjectSummary]
    @ObservedObject private var focusTimer = FocusTimerService.shared

    var body: some View {
        ScrollView {
            FocusTimerView(timer: focusTimer, subjects: subjects)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .navigationTitle("Focus Timer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AnalyticsService.shared.setScreen(.focusTimer)
        }
    }
}

struct ToolHubRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    var showsLock: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    if showsLock {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(BrandColor.colorPremium)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
