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
    private var skipVerb: String { market.skipVerb }

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)
    private let gold = Color(red: 1.0, green: 0.78, blue: 0.28)
    private let coral = Color(red: 1.0, green: 0.45, blue: 0.45)
    private let purple = Color(red: 0.72, green: 0.55, blue: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            toolsHeader

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

            toolSection(title: "Planning") {
                NavigationLink {
                    SkipPlannerToolScreen(subjectStore: subjectStore)
                } label: {
                    ToolHubRow(
                        icon: "calendar.badge.minus",
                        tint: green,
                        title: "Skip Planner",
                        subtitle: skipPlannerSubtitle,
                        showsLock: !entitlements.isPro
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SemesterForecastToolScreen(subjectStore: subjectStore)
                } label: {
                    ToolHubRow(
                        icon: "chart.line.uptrend.xyaxis",
                        tint: purple,
                        title: "Semester Forecast",
                        subtitle: forecastToolSubtitle,
                        showsLock: !entitlements.isForecastUnlocked
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
                        showsLock: !entitlements.isPro
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
            Text("Focus, planning, grades, and exports — open anytime. Daily attendance stays on Home.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
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
        if focusTimer.todayFocusMinutes > 0 {
            return "\(focusTimer.todayFocusMinutes)m focused today · \(focusTimer.todaySessionCount) session\(focusTimer.todaySessionCount == 1 ? "" : "s")"
        }
        return "Pomodoro timer · topics · Lock Screen live"
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

    private var skipPlannerSubtitle: String {
        if !entitlements.isPro {
            return "Know which days stay safe before you \(skipVerb)"
        }
        if let safest = SkipPlanner.safestSkipDay(subjects: subjects) {
            let day = safest.date.formatted(.dateTime.weekday(.wide))
            switch safest.riskLevel {
            case .safe: return "Safest day: \(day) · all subjects safe"
            case .mixed: return "Best option: \(day) · mixed risk"
            default: return "Tap a day to see if you can \(skipVerb)"
            }
        }
        return "Tap a day to see if you can \(skipVerb)"
    }

    private var forecastToolSubtitle: String {
        if !entitlements.isForecastUnlocked {
            return "Project end-of-semester attendance per subject"
        }
        let weeks = SemesterSettings.weeksRemaining()
        let atRisk = subjectStore.dashboardSummary.riskSubjects
        if atRisk > 0 {
            return "\(weeks) weeks left · \(atRisk) subject\(atRisk == 1 ? "" : "s") at risk"
        }
        return "\(weeks) weeks left · all subjects on track"
    }

    private var exportToolSubtitle: String {
        if !entitlements.isPro {
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
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.28))
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
