//
//  AcademicsView.swift
//  Student Attendance Predictor
//
//  Market-aware grades hub: India 10-point CGPA · US 4.0 GPA · UK modules %.
//

import SwiftUI

enum AcademicsToolMode {
    case grades
    case deadlines
}

struct AcademicsView: View {
    @ObservedObject var gpaStore: GPAStore
    @ObservedObject var deadlineStore: DeadlineStore
    var subjects: [SubjectSummary] = []
    var mode: AcademicsToolMode = .grades
    private var market: StudentMarket { StudentMarketStore.current }

    @State private var showAddCourse = false
    @State private var showAddDeadline = false
    @State private var editingCourse: GPACourse?
    @State private var editingDeadline: AcademicDeadline?

    @State private var courseName = ""
    @State private var courseCredits = "3"
    @State private var courseGrade: LetterGrade = .b
    @State private var indiaGrade: IndiaGrade = .a
    @State private var moduleMarkPercent = "65"
    @State private var ukYear = 2

    @State private var deadlineTitle = ""
    @State private var deadlineCourse = ""
    @State private var deadlineKind: AcademicDeadlineKind = .exam
    @State private var deadlineDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    @State private var targetInput = ""
    @State private var remainingCreditsInput = ""
    @State private var showArchiveConfirm = false
    @State private var newTermName = ""
    @State private var showArchivedTerms = false
    @State private var lastLoggedTargetResult: String?

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let coral = Color(red: 1.0, green: 0.45, blue: 0.45)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch mode {
                case .grades:
                    gpaCard
                    if gpaStore.activeCourses.isEmpty == false || gpaStore.courses.isEmpty == false {
                        targetCard
                    }
                case .deadlines:
                    deadlinesContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 0.05, green: 0.06, blue: 0.1).ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if mode == .grades {
                    addCourseToolbarButton
                } else {
                    addDeadlineToolbarButton
                }
            }
        }
        .onAppear {
            AnalyticsService.shared.setScreen(.academics)
            AnalyticsService.shared.log(
                .academicsViewed(
                    market: market.rawValue,
                    courseCount: gpaStore.activeCourses.count,
                    deadlineCount: deadlineStore.upcoming.count + deadlineStore.past.count,
                    focusMinutesToday: FocusTimerService.shared.todayFocusMinutes,
                    focusSessionsToday: FocusTimerService.shared.todaySessionCount,
                    mode: modeAnalyticsValue
                )
            )
            resetFormDefaults()
        }
        .sheet(isPresented: $showAddCourse) { courseEditorSheet(existing: nil) }
        .sheet(item: $editingCourse) { course in
            courseEditorSheet(existing: course)
        }
        .sheet(isPresented: $showAddDeadline) { deadlineEditorSheet(existing: nil) }
        .sheet(item: $editingDeadline) { item in
            deadlineEditorSheet(existing: item)
        }
        .alert("Archive semester?", isPresented: $showArchiveConfirm) {
            TextField("New semester name", text: $newTermName)
            Button("Archive & start new") {
                let name = newTermName
                newTermName = ""
                _ = gpaStore.archiveActiveTermAndStartNew(named: name)
            }
            Button("Cancel", role: .cancel) {
                newTermName = ""
            }
        } message: {
            Text("Moves \(gpaStore.activeTerm?.name ?? "this term") to history and opens a blank semester for new grades.")
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .grades:
            switch market {
            case .india: return "CGPA Calculator"
            case .unitedKingdom: return "Module Marks"
            case .unitedStates, .other: return "GPA Calculator"
            }
        case .deadlines:
            return "Exam Deadlines"
        }
    }

    private var modeAnalyticsValue: String {
        switch mode {
        case .grades: return "grades"
        case .deadlines: return "deadlines"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerTitle)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(headerSubtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var addCourseToolbarButton: some View {
        Button {
            AnalyticsService.shared.log(.academicCourseAddTapped(market: market.rawValue))
            resetFormDefaults()
            showAddCourse = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(cyan)
        }
        .accessibilityLabel("Add subject")
    }

    private var addDeadlineToolbarButton: some View {
        Button {
            AnalyticsService.shared.log(.academicDeadlineAddTapped)
            resetDeadlineDefaults()
            showAddDeadline = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(coral)
        }
        .accessibilityLabel("Add deadline")
    }

    private var headerTitle: String {
        switch mode {
        case .grades:
            switch market {
            case .india: return "10-point CGPA"
            case .unitedKingdom: return "Module marks"
            case .unitedStates: return "4.0 GPA"
            case .other: return "GPA tracker"
            }
        case .deadlines:
            return "Exams & deadlines"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .grades: return market.academicsSubtitle
        case .deadlines:
            return "Local reminders before exams and assignments — tap a row to edit."
        }
    }

    // MARK: - GPA / CGPA / Modules card

    private var gpaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if gpaStore.activeCourses.isEmpty && gpaStore.courses.isEmpty {
                gradesEmptyState
            } else {
                scoreHero

                if gpaStore.openTerms.count > 1 || gpaStore.archivedTerms.isEmpty == false {
                    termChrome
                } else if let term = gpaStore.activeTerm {
                    Text(term.name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule(style: .continuous).fill(cyan.opacity(0.15)))
                }

                if gpaStore.activeCourses.isEmpty == false {
                    VStack(spacing: 0) {
                        ForEach(gpaStore.activeCourses) { course in
                            courseRow(course)
                            if course.id != gpaStore.activeCourses.last?.id {
                                Divider().overlay(Color.white.opacity(0.08))
                            }
                        }
                    }
                }

                if gpaStore.archivedTerms.isEmpty == false {
                    archivedTermsSection
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var gradesEmptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(cyan.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(cyan)
            }

            VStack(spacing: 6) {
                Text(emptyCoursesHeadline)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(emptyCoursesCopy)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            Button {
                AnalyticsService.shared.log(.academicCourseAddTapped(market: market.rawValue))
                resetFormDefaults()
                showAddCourse = true
            } label: {
                Text(addFirstCourseLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule(style: .continuous).fill(cyan))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var emptyCoursesHeadline: String {
        switch market {
        case .india: return "No subjects yet"
        case .unitedKingdom: return "No modules yet"
        case .unitedStates, .other: return "No courses yet"
        }
    }

    private var addFirstCourseLabel: String {
        switch market {
        case .india: return "Add first subject"
        case .unitedKingdom: return "Add first module"
        case .unitedStates, .other: return "Add first course"
        }
    }

    private var emptyCoursesCopy: String {
        switch market {
        case .india: return "UGC grades O–F with credits — we’ll calculate CGPA and SGPA."
        case .unitedKingdom: return "Enter module % and credits to see your average and classification."
        case .unitedStates, .other: return "Letter grades and credits — live semester and cumulative GPA."
        }
    }

    private func courseRow(_ course: GPACourse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(courseDetailLabel(course))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button {
                prepareEditCourse(course)
                editingCourse = course
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            Button(role: .destructive) {
                gpaStore.delete(id: course.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var termChrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(gpaStore.openTerms) { term in
                        Button {
                            gpaStore.selectTerm(term.id)
                        } label: {
                            Text(term.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(term.id == gpaStore.activeTermID ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(term.id == gpaStore.activeTermID ? cyan : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                if let termScore = activeTermScoreText {
                    Text(termScore)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(cyan)
                }
                Spacer()
                if gpaStore.activeCourses.isEmpty == false {
                    Button {
                        newTermName = ""
                        showArchiveConfirm = true
                    } label: {
                        Label("Archive semester", systemImage: "archivebox")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activeTermScoreText: String? {
        guard let term = gpaStore.activeTerm else { return nil }
        guard let score = gpaStore.score(for: term.id, market: market) else { return nil }
        let label = gpaStore.termScoreLabel(for: market)
        switch market {
        case .india:
            return "\(term.name): \(label) \(String(format: "%.2f", score))"
        case .unitedKingdom:
            return "\(term.name): \(label) \(String(format: "%.0f%%", score))"
        case .unitedStates, .other:
            return "\(term.name): \(label) \(String(format: "%.2f", score))"
        }
    }

    private var archivedTermsSection: some View {
        DisclosureGroup(isExpanded: $showArchivedTerms) {
            ForEach(gpaStore.archivedTerms) { term in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(term.name)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        if let score = gpaStore.score(for: term.id, market: market) {
                            Text(archivedScoreText(score))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    ForEach(gpaStore.courses(in: term.id)) { course in
                        Text("\(course.name) · \(courseDetailLabel(course))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(.vertical, 6)
            }
        } label: {
            Text("Archived semesters (\(gpaStore.archivedTerms.count))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .tint(.white.opacity(0.55))
    }

    private func archivedScoreText(_ score: Double) -> String {
        switch market {
        case .india: return String(format: "SGPA %.2f", score)
        case .unitedKingdom: return String(format: "%.0f%%", score)
        case .unitedStates, .other: return String(format: "GPA %.2f", score)
        }
    }

    @ViewBuilder
    private var scoreHero: some View {
        switch market {
        case .india:
            if let cgpa = gpaStore.indiaCGPA {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "%.2f", cgpa))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CGPA / 10 · all semesters")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        if let pct = gpaStore.indiaPercentage {
                            Text("~\(String(format: "%.0f", pct))% (× 9.5)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        if let sgpa = gpaStore.indiaSGPA {
                            Text("This semester SGPA \(String(format: "%.2f", sgpa))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    Spacer()
                }
            } else {
                compactScorePlaceholder(icon: "plus", message: compactEmptyScoreMessage)
            }

        case .unitedKingdom:
            if let average = gpaStore.ukCumulativeAveragePercent ?? gpaStore.ukAveragePercent {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "%.0f%%", average))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(GPACalculator.ukClassification(averagePercent: average))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text(ukAverageCaption)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
            } else {
                compactScorePlaceholder(icon: "plus", message: compactEmptyScoreMessage)
            }

        case .unitedStates, .other:
            if let gpa = gpaStore.cumulativeGPA ?? gpaStore.gpa {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "%.2f", gpa))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cumulative GPA")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(gpaStore.courses.count) course\(gpaStore.courses.count == 1 ? "" : "s") · all semesters")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        if let termGPA = gpaStore.gpa {
                            Text("This semester \(String(format: "%.2f", termGPA))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    Spacer()
                }
            } else {
                compactScorePlaceholder(icon: "plus", message: compactEmptyScoreMessage)
            }
        }
    }

    private var compactEmptyScoreMessage: String {
        switch market {
        case .india: return "Add subjects this semester to update SGPA."
        case .unitedKingdom: return "Add modules this term to update your average."
        case .unitedStates, .other: return "Add courses this semester to update GPA."
        }
    }

    private func compactScorePlaceholder(icon: String, message: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cyan.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(cyan.opacity(0.7))
            }
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 0)
        }
    }

    private var ukAverageCaption: String {
        let hasYears = gpaStore.courses.contains { ($0.ukYear ?? 0) >= 2 }
        let base = "\(gpaStore.courses.count) module\(gpaStore.courses.count == 1 ? "" : "s") · all terms"
        return hasYears ? "\(base) · year-weighted (33/67)" : "\(base) · credit-weighted"
    }

    // MARK: - Target / what-if

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(targetTitle)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(targetHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(targetFieldLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    TextField(targetPlaceholder, text: $targetInput)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Remaining credits")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    TextField("e.g. 18", text: $remainingCreditsInput)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
                }
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)

            if let result = targetResultText {
                Text(result)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(cyan)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(cyan.opacity(0.1))
                    )
            }
        }
        .padding(16)
        .background(cardBackground)
        .onChange(of: targetInput) { _, _ in logTargetResultIfNeeded() }
        .onChange(of: remainingCreditsInput) { _, _ in logTargetResultIfNeeded() }
    }

    private var targetFieldLabel: String {
        switch market {
        case .india: return "Target CGPA"
        case .unitedKingdom: return "Target average %"
        case .unitedStates, .other: return "Target GPA"
        }
    }

    private func logTargetResultIfNeeded() {
        guard let result = targetResultText else {
            lastLoggedTargetResult = nil
            return
        }
        guard result != lastLoggedTargetResult else { return }
        lastLoggedTargetResult = result
        AnalyticsService.shared.log(.academicTargetViewed(market: market.rawValue))
    }

    private var targetTitle: String {
        switch market {
        case .india: return "Target CGPA"
        case .unitedKingdom: return "Target classification %"
        case .unitedStates, .other: return "Target GPA"
        }
    }

    private var targetHint: String {
        switch market {
        case .india: return "What average grade points do you need in remaining credits?"
        case .unitedKingdom: return "What average mark do you need in remaining credits?"
        case .unitedStates, .other: return "What average grade points do you need in remaining credits?"
        }
    }

    private var targetPlaceholder: String {
        switch market {
        case .india: return "e.g. 8.5"
        case .unitedKingdom: return "e.g. 60"
        case .unitedStates, .other: return "e.g. 3.5"
        }
    }

    private var targetResultText: String? {
        let target = Double(targetInput.replacingOccurrences(of: ",", with: "."))
        let remaining = Double(remainingCreditsInput.replacingOccurrences(of: ",", with: "."))
        guard let target, let remaining, remaining > 0 else { return nil }

        switch market {
        case .india:
            let modules = gpaStore.courses.filter { $0.indiaGrade != nil }
            let credits = modules.reduce(0.0) { $0 + $1.credits }
            let points = modules.reduce(0.0) { $0 + ($1.credits * ($1.indiaGrade?.points10 ?? 0)) }
            guard let needed = GPACalculator.requiredAverageInRemaining(
                currentPoints: points,
                currentCredits: credits,
                remainingCredits: remaining,
                targetAverage: target
            ) else { return nil }
            if needed > 10 {
                return "Need \(String(format: "%.1f", needed))/10 in remaining credits — above the O grade ceiling. Raise remaining credits or lower the target."
            }
            if needed <= 0 {
                return "You're already at or above \(String(format: "%.1f", target)) CGPA."
            }
            return "Need \(String(format: "%.1f", needed))/10 average in the next \(remaining.cleanCredits) credits."

        case .unitedKingdom:
            let modules = gpaStore.courses.filter { $0.markPercent != nil }
            let credits = modules.reduce(0.0) { $0 + $1.credits }
            let points = modules.reduce(0.0) { $0 + ($1.credits * ($1.markPercent ?? 0)) }
            guard let needed = GPACalculator.requiredAverageInRemaining(
                currentPoints: points,
                currentCredits: credits,
                remainingCredits: remaining,
                targetAverage: target
            ) else { return nil }
            if needed > 100 {
                return "Need \(String(format: "%.0f", needed))% — above 100%. Raise remaining credits or lower the target."
            }
            if needed <= 0 {
                return "You're already at or above \(String(format: "%.0f", target))%."
            }
            return "Need \(String(format: "%.0f", needed))% average in the next \(remaining.cleanCredits) credits (\(GPACalculator.ukClassification(averagePercent: target)))."

        case .unitedStates, .other:
            let credits = gpaStore.courses.reduce(0.0) { $0 + $1.credits }
            let points = gpaStore.courses.reduce(0.0) { $0 + ($1.credits * $1.grade.points4_0) }
            guard let needed = GPACalculator.requiredAverageInRemaining(
                currentPoints: points,
                currentCredits: credits,
                remainingCredits: remaining,
                targetAverage: target
            ) else { return nil }
            if needed > 4.0 {
                return "Need \(String(format: "%.2f", needed))/4.0 — above an A. Raise remaining credits or lower the target."
            }
            if needed <= 0 {
                return "You're already at or above \(String(format: "%.2f", target)) GPA."
            }
            return "Need \(String(format: "%.2f", needed))/4.0 average in the next \(remaining.cleanCredits) credits."
        }
    }

    // MARK: - Deadlines

    private var deadlinesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if deadlineStore.upcoming.isEmpty && deadlineStore.past.isEmpty {
                deadlinesEmptyCard
            } else {
                deadlinesListCard
            }
        }
    }

    private var deadlinesEmptyCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(coral.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(coral)
            }

            VStack(spacing: 6) {
                Text("No exams or assignments yet")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Add dates so Bunk Planner can nudge you — and warn you on Home when not to \(market.skipVerb).")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            Button {
                AnalyticsService.shared.log(.academicDeadlineAddTapped)
                resetDeadlineDefaults()
                showAddDeadline = true
            } label: {
                Text("Add first deadline")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule(style: .continuous).fill(coral))
            }
            .buttonStyle(PressableButtonStyle())

            Text("Reminders at 7 days, 3 days, 1 day before, and the morning of the due date.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(cardBackground)
    }

    private var deadlinesListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if deadlineStore.upcoming.isEmpty == false {
                Text("Upcoming · \(deadlineStore.upcoming.count)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            VStack(spacing: 0) {
                ForEach(deadlineStore.upcoming.prefix(8)) { item in
                    deadlineRow(item)
                    if item.id != deadlineStore.upcoming.prefix(8).last?.id {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }

            if deadlineStore.past.isEmpty == false {
                Text("Past")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
                ForEach(deadlineStore.past.prefix(3)) { item in
                    deadlineRow(item, dimmed: true)
                }
            }

            Text("Reminders at 7, 3, and 1 day before — plus the morning of.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(16)
        .background(cardBackground)
    }

    private func deadlineRow(_ item: AcademicDeadline, dimmed: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(countdownColor(item))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(dimmed ? 0.55 : 1))
                Text(item.courseName.isEmpty ? item.kind.title : "\(item.kind.title) · \(item.courseName)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                prepareEditDeadline(item)
                editingDeadline = item
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.countdownLabel)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(countdownColor(item))
                HStack(spacing: 10) {
                    Button {
                        prepareEditDeadline(item)
                        editingDeadline = item
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    Button(role: .destructive) {
                        deadlineStore.delete(id: item.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func courseDetailLabel(_ course: GPACourse) -> String {
        if market == .india, let grade = course.indiaGrade {
            return "\(course.credits.cleanCredits) credits · \(grade.rawValue) (\(grade.points10.cleanCredits) pts)"
        }
        if market == .unitedKingdom, let mark = course.markPercent {
            let yearBit = course.ukYear.map { " · Y\($0)" } ?? ""
            return "\(course.credits.cleanCredits) credits · \(String(format: "%.0f%%", mark))\(yearBit)"
        }
        return "\(course.credits.cleanCredits) credits · \(course.grade.rawValue)"
    }

    private func countdownColor(_ item: AcademicDeadline) -> Color {
        let days = item.daysRemaining
        if days < 0 { return .red.opacity(0.85) }
        if days <= 3 { return .orange }
        if days <= 7 { return Color(red: 1.0, green: 0.84, blue: 0.2) }
        return cyan
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }

    private func resetFormDefaults() {
        courseName = ""
        courseCredits = String(format: "%g", market.defaultCredits)
        courseGrade = .b
        indiaGrade = .a
        moduleMarkPercent = "65"
        ukYear = 2
    }

    private func resetDeadlineDefaults() {
        deadlineTitle = ""
        deadlineCourse = ""
        deadlineKind = .exam
        deadlineDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }

    private func prepareEditCourse(_ course: GPACourse) {
        courseName = course.name
        courseCredits = String(format: "%g", course.credits)
        courseGrade = course.grade
        indiaGrade = course.indiaGrade ?? .a
        if let mark = course.markPercent {
            moduleMarkPercent = String(format: "%g", mark)
        }
        ukYear = course.ukYear ?? 2
    }

    private func prepareEditDeadline(_ item: AcademicDeadline) {
        deadlineTitle = item.title
        deadlineCourse = item.courseName
        deadlineKind = item.kind
        deadlineDate = item.dueDate
    }

    // MARK: - Sheets

    private func courseEditorSheet(existing: GPACourse?) -> some View {
        NavigationStack {
            Form {
                switch market {
                case .india:
                    TextField("Subject name", text: $courseName)
                    TextField("Credits", text: $courseCredits)
                        .keyboardType(.decimalPad)
                    Picker("Grade", selection: $indiaGrade) {
                        ForEach(IndiaGrade.allCases) { grade in
                            Text("\(grade.rawValue) · \(grade.subtitle) (\(grade.points10.cleanCredits))")
                                .tag(grade)
                        }
                    }
                    Text("UGC-style 10-point scale. Approximate % ≈ CGPA × 9.5.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                case .unitedKingdom:
                    TextField("Module name", text: $courseName)
                    TextField("Mark %", text: $moduleMarkPercent)
                        .keyboardType(.decimalPad)
                    TextField("Credits", text: $courseCredits)
                        .keyboardType(.decimalPad)
                    Picker("Year", selection: $ukYear) {
                        Text("Year 1").tag(1)
                        Text("Year 2").tag(2)
                        Text("Year 3+").tag(3)
                    }
                    Text("With Year 2 and Year 3 modules, classification uses 33/67 year weighting. 70%+ First, 60–69 2:1, 50–59 2:2, 40–49 Third.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                case .unitedStates, .other:
                    TextField("Course name", text: $courseName)
                    TextField("Credits", text: $courseCredits)
                        .keyboardType(.decimalPad)
                    Picker("Grade", selection: $courseGrade) {
                        ForEach(LetterGrade.allCases) { grade in
                            Text("\(grade.rawValue) (\(String(format: "%.1f", grade.points4_0)))")
                                .tag(grade)
                        }
                    }
                }
            }
            .navigationTitle(courseSheetTitle(existing: existing))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddCourse = false
                        editingCourse = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCourse(existing: existing)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func courseSheetTitle(existing: GPACourse?) -> String {
        let verb = existing == nil ? "Add" : "Edit"
        switch market {
        case .india: return "\(verb) Subject"
        case .unitedKingdom: return "\(verb) Module"
        case .unitedStates, .other: return "\(verb) Course"
        }
    }

    private func saveCourse(existing: GPACourse?) {
        let credits = Double(courseCredits.replacingOccurrences(of: ",", with: ".")) ?? market.defaultCredits
        let name = courseName

        if let existing {
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? existing.name
                : name.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.credits = credits
            switch market {
            case .india:
                updated.indiaGrade = indiaGrade
                updated.markPercent = nil
            case .unitedKingdom:
                let mark = Double(moduleMarkPercent.replacingOccurrences(of: ",", with: ".")) ?? 65
                updated.markPercent = mark
                updated.ukYear = ukYear
                updated.indiaGrade = nil
                updated.grade = GPACalculator.letterForUKMark(mark)
            case .unitedStates, .other:
                updated.grade = courseGrade
                updated.markPercent = nil
                updated.indiaGrade = nil
            }
            if updated.termID == nil {
                updated.termID = gpaStore.activeTermID
            }
            gpaStore.update(updated)
            editingCourse = nil
        } else {
            switch market {
            case .india:
                gpaStore.addIndiaSubject(name: name, credits: credits, grade: indiaGrade)
            case .unitedKingdom:
                let mark = Double(moduleMarkPercent.replacingOccurrences(of: ",", with: ".")) ?? 65
                gpaStore.addUKModule(name: name, credits: credits, markPercent: mark, year: ukYear)
            case .unitedStates, .other:
                gpaStore.addCourse(name: name, credits: credits, grade: courseGrade)
            }
            showAddCourse = false
        }
        resetFormDefaults()
    }

    private func deadlineEditorSheet(existing: AcademicDeadline?) -> some View {
        NavigationStack {
            Form {
                TextField("Title", text: $deadlineTitle)
                TextField("\(market.courseNounPluralTitle.dropLast()) (optional)", text: $deadlineCourse)
                Picker("Type", selection: $deadlineKind) {
                    ForEach(AcademicDeadlineKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                DatePicker("Due date", selection: $deadlineDate, displayedComponents: .date)
                Text("You'll get reminders 7 days, 3 days, and 1 day before, plus the morning of.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(existing == nil ? "Add Deadline" : "Edit Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddDeadline = false
                        editingDeadline = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let title = deadlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard title.isEmpty == false else { return }
                        let course = deadlineCourse.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let existing {
                            var updated = existing
                            updated.title = title
                            updated.dueDate = deadlineDate
                            updated.kind = deadlineKind
                            updated.courseName = course
                            deadlineStore.update(updated)
                            editingDeadline = nil
                        } else {
                            deadlineStore.add(
                                AcademicDeadline(
                                    title: title,
                                    dueDate: deadlineDate,
                                    kind: deadlineKind,
                                    courseName: course
                                )
                            )
                            showAddDeadline = false
                        }
                        NotificationService.requestAuthorizationIfNeeded()
                        resetDeadlineDefaults()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private extension Double {
    var cleanCredits: String {
        rounded() == self ? String(Int(self)) : String(format: "%.1f", self)
    }
}
