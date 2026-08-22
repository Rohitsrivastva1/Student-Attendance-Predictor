//
//  AttendanceLogView.swift
//  Student Attendance Predictor
//

import SwiftUI

// MARK: - Mark Today card (Home tab)

/// Daily habit center — marks all subjects scheduled today in one flow
/// (falls back to every subject when the timetable has nothing for today).
/// One subject card at a time; swipe left/right between subjects. “Mark all Yes”
/// stays available so bulk days don’t require N swipes.
struct MarkTodayCard: View {
    @ObservedObject var subjectStore: SubjectStore
    var isHighlighted: Bool = false
    var onCelebrated: (() -> Void)? = nil
    var onAddSubject: (() -> Void)? = nil

    @State private var showCelebration = false
    @State private var celebratePulse = false
    @State private var selectedSubjectID: UUID = UUID()
    @State private var didDiscoverPaging = false
    @State private var nudgeChevron = false

    private let today = Date()
    private let didDiscoverPagingKey = "markToday.didDiscoverPaging"

    fileprivate enum DayChoice { case attended, missed, holiday }

    private let attendedTint = Color(red: 0.2, green: 0.9, blue: 0.5)
    private let missedTint = Color.red
    private let accentTint = Color(red: 0.32, green: 0.84, blue: 1.0)

    private var subjectsToday: [SubjectSummary] {
        // Unmarked first so paging starts on what still needs a tap.
        subjectStore.subjectsForMarkToday(on: today).sorted { lhs, rhs in
            let leftMarked = subjectStore.logEntry(subjectID: lhs.id, date: today) != nil
            let rightMarked = subjectStore.logEntry(subjectID: rhs.id, date: today) != nil
            if leftMarked != rightMarked { return leftMarked == false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var usingTimetableFilter: Bool {
        subjectStore.subjects.contains { subjectStore.classesScheduledToday(for: $0.id, on: today) > 0 }
    }

    private var markedCount: Int {
        subjectsToday.reduce(0) { count, subject in
            subjectStore.logEntry(subjectID: subject.id, date: today) == nil ? count : count + 1
        }
    }

    private var unmarkedSubjects: [SubjectSummary] {
        subjectsToday.filter { subjectStore.logEntry(subjectID: $0.id, date: today) == nil }
    }

    private var currentPageIndex: Int {
        subjectsToday.firstIndex(where: { $0.id == selectedSubjectID }) ?? 0
    }

    private var promptCopy: (title: String, subtitle: String) {
        let hour = Calendar.current.component(.hour, from: today)
        let count = subjectsToday.count
        let subjectWord = count == 1 ? "subject" : "subjects"
        if hour < 12 {
            return (
                "Morning check-in",
                count == 0
                    ? "Add a subject to start logging."
                    : count == 1
                        ? "Mark today’s class — one tap."
                        : "Swipe subjects · mark each — or Mark all Yes."
            )
        }
        if hour >= 17 {
            return (
                "Evening wrap-up",
                count == 0
                    ? "Add a subject to start logging."
                    : count == 1
                        ? "Log today’s class before you sleep."
                        : "Swipe to finish all \(count) \(subjectWord) before you sleep."
            )
        }
        return (
            "Today's Classes",
            count == 0
                ? "Add a subject to start logging."
                : usingTimetableFilter
                    ? "\(count) \(subjectWord) today — swipe to mark each."
                    : "No timetable for today — swipe and mark each."
        )
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                header
                if subjectsToday.isEmpty {
                    emptyContent
                } else {
                    if unmarkedSubjects.isEmpty == false && subjectsToday.count >= 2 {
                        markAllYesButton
                    }

                    subjectPager

                    if subjectsToday.count > 1 {
                        if didDiscoverPaging == false {
                            swipeHint
                        }
                        pageControls
                        subjectChips
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                showCelebration
                                    ? attendedTint.opacity(0.55)
                                    : isHighlighted
                                        ? accentTint.opacity(0.85)
                                        : Color.white.opacity(0.12),
                                lineWidth: showCelebration || isHighlighted ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isHighlighted && celebratePulse == false ? 1.015 : (celebratePulse ? 1.02 : 1.0))
            .animation(
                isHighlighted ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true) : .default,
                value: isHighlighted
            )

            if showCelebration {
                CelebrationBurst(isActive: showCelebration)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .top) {
            if showCelebration {
                CelebrationToast(
                    message: "Great!",
                    subtitle: markedCount >= subjectsToday.count && subjectsToday.isEmpty == false
                        ? "All subjects logged for today."
                        : "Today's attendance saved."
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, -8)
            }
        }
        .onAppear {
            didDiscoverPaging = UserDefaults.standard.bool(forKey: didDiscoverPagingKey)
            ensureSelection()
            startNudgeIfNeeded()
        }
        .onChange(of: isHighlighted) { _, on in
            if on { startNudgeIfNeeded() }
        }
        .onChange(of: subjectsToday.map(\.id)) { _, _ in
            ensureSelection()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(promptCopy.title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(promptCopy.subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text(today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            if subjectsToday.isEmpty == false {
                Text("\(markedCount)/\(subjectsToday.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(markedCount == subjectsToday.count ? attendedTint : .white.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your first subject to mark today's classes.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            if let onAddSubject {
                Button(action: onAddSubject) {
                    Text("Add subject")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accentTint)
                        )
                }
                .buttonStyle(LogPressStyle())
            }
        }
    }

    private var markAllYesButton: some View {
        Button {
            markAllUnmarkedAttended()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(unmarkedSubjects.count == 1
                      ? "Mark remaining Yes"
                      : "Mark all \(unmarkedSubjects.count) Yes")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(attendedTint)
            )
        }
        .buttonStyle(LogPressStyle())
        .accessibilityLabel("Mark all remaining subjects as attended")
    }

    private var subjectPager: some View {
        TabView(selection: pagerSelection) {
            ForEach(subjectsToday) { subject in
                MarkTodaySubjectRow(
                    subject: subject,
                    scheduledCount: max(1, subjectStore.classesScheduledToday(for: subject.id, on: today)),
                    entry: subjectStore.logEntry(subjectID: subject.id, date: today),
                    attendedTint: attendedTint,
                    missedTint: missedTint,
                    accentTint: accentTint,
                    onChoice: { choice in
                        apply(choice, for: subject)
                    }
                )
                .padding(.horizontal, 2)
                .tag(subject.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 148)
    }

    /// Marks paging as discovered when the user swipes the pager (not on programmatic jumps).
    private var pagerSelection: Binding<UUID> {
        Binding(
            get: { selectedSubjectID },
            set: { newValue in
                guard newValue != selectedSubjectID else { return }
                selectedSubjectID = newValue
                markPagingDiscovered()
            }
        )
    }

    private var swipeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 13, weight: .bold))
            Text("Swipe or tap arrows for the next subject")
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(accentTint)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accentTint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accentTint.opacity(0.35), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var pageControls: some View {
        HStack(spacing: 10) {
            Button {
                goToRelativePage(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(currentPageIndex > 0 ? Color.white : Color.white.opacity(0.25))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(currentPageIndex > 0 ? 0.12 : 0.05))
                    )
            }
            .buttonStyle(LogPressStyle())
            .disabled(currentPageIndex <= 0)
            .accessibilityLabel("Previous subject")

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(subjectsToday) { subject in
                        let isCurrent = subject.id == selectedSubjectID
                        let isMarked = subjectStore.logEntry(subjectID: subject.id, date: today) != nil
                        Capsule(style: .continuous)
                            .fill(
                                isCurrent
                                    ? accentTint
                                    : (isMarked ? attendedTint.opacity(0.55) : Color.white.opacity(0.22))
                            )
                            .frame(width: isCurrent ? 16 : 7, height: 7)
                    }
                }
                Text("\(min(currentPageIndex + 1, subjectsToday.count)) of \(subjectsToday.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Button {
                goToRelativePage(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        currentPageIndex < subjectsToday.count - 1 ? Color.white : Color.white.opacity(0.25)
                    )
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                currentPageIndex < subjectsToday.count - 1
                                    ? accentTint.opacity(nudgeChevron ? 0.45 : 0.22)
                                    : Color.white.opacity(0.05)
                            )
                    )
                    .scaleEffect(nudgeChevron && currentPageIndex < subjectsToday.count - 1 ? 1.08 : 1.0)
            }
            .buttonStyle(LogPressStyle())
            .disabled(currentPageIndex >= subjectsToday.count - 1)
            .accessibilityLabel("Next subject")
        }
    }

    private var subjectChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subjectsToday) { subject in
                    let isCurrent = subject.id == selectedSubjectID
                    let isMarked = subjectStore.logEntry(subjectID: subject.id, date: today) != nil
                    Button {
                        AttendanceLogHaptics.tap()
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedSubjectID = subject.id
                        }
                        markPagingDiscovered()
                    } label: {
                        HStack(spacing: 5) {
                            if isMarked {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(isCurrent ? Color.black : attendedTint)
                            }
                            Text(subject.name)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isCurrent ? Color.black : Color.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isCurrent ? accentTint : Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(LogPressStyle())
                }
            }
        }
    }

    private func goToRelativePage(_ delta: Int) {
        let ids = subjectsToday.map(\.id)
        guard let index = ids.firstIndex(of: selectedSubjectID) else { return }
        let next = index + delta
        guard ids.indices.contains(next) else { return }
        AttendanceLogHaptics.tap()
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedSubjectID = ids[next]
        }
        markPagingDiscovered()
    }

    private func markPagingDiscovered() {
        guard didDiscoverPaging == false else { return }
        didDiscoverPaging = true
        nudgeChevron = false
        UserDefaults.standard.set(true, forKey: didDiscoverPagingKey)
    }

    private func startNudgeIfNeeded() {
        guard didDiscoverPaging == false, subjectsToday.count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            nudgeChevron = true
        }
    }

    private func ensureSelection() {
        let ids = subjectsToday.map(\.id)
        guard let first = ids.first else { return }
        if ids.contains(selectedSubjectID) { return }
        selectedSubjectID = unmarkedSubjects.first?.id ?? first
    }

    private func advanceToNextUnmarked(after subjectID: UUID) {
        let ids = subjectsToday.map(\.id)
        guard let index = ids.firstIndex(of: subjectID) else { return }
        let rotated = Array(subjectsToday[(index + 1)...]) + Array(subjectsToday[..<index])
        if let next = rotated.first(where: { subjectStore.logEntry(subjectID: $0.id, date: today) == nil }) {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedSubjectID = next.id
            }
        }
    }

    private func markAllUnmarkedAttended() {
        let targets = unmarkedSubjects
        guard targets.isEmpty == false else { return }
        AttendanceLogHaptics.tap()
        for subject in targets {
            apply(.attended, for: subject, celebrate: false, advance: false)
        }
        triggerCelebration()
        ensureSelection()
    }

    private func apply(
        _ choice: DayChoice,
        for subject: SubjectSummary,
        celebrate: Bool = true,
        advance: Bool = true
    ) {
        let wasNew = subjectStore.logEntry(subjectID: subject.id, date: today) == nil
        let scheduled = max(1, subjectStore.classesScheduledToday(for: subject.id, on: today))
        if celebrate {
            AttendanceLogHaptics.tap()
        }
        switch choice {
        case .attended:
            subjectStore.markDay(
                subjectID: subject.id,
                date: today,
                attendedCount: scheduled,
                scheduledCount: scheduled,
                isHoliday: false,
                source: "mark_today_multi"
            )
        case .missed:
            subjectStore.markDay(
                subjectID: subject.id,
                date: today,
                attendedCount: 0,
                scheduledCount: scheduled,
                isHoliday: false,
                source: "mark_today_multi"
            )
        case .holiday:
            subjectStore.markDay(
                subjectID: subject.id,
                date: today,
                attendedCount: 0,
                scheduledCount: 0,
                isHoliday: true,
                source: "mark_today_multi"
            )
        }
        if celebrate && wasNew {
            triggerCelebration()
        }
        if advance && wasNew {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                advanceToNextUnmarked(after: subject.id)
            }
        }
    }

    private func triggerCelebration() {
        onCelebrated?()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showCelebration = true
            celebratePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.35)) {
                showCelebration = false
                celebratePulse = false
            }
        }
    }
}

private struct MarkTodaySubjectRow: View {
    let subject: SubjectSummary
    let scheduledCount: Int
    let entry: AttendanceLogEntry?
    let attendedTint: Color
    let missedTint: Color
    let accentTint: Color
    let onChoice: (MarkTodayCard.DayChoice) -> Void

    private var current: MarkTodayCard.DayChoice? {
        guard let entry else { return nil }
        if entry.isHoliday { return .holiday }
        if entry.scheduledClasses <= 0 { return nil }
        return entry.attendedClasses <= 0 ? .missed : .attended
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(scheduledCount == 1
                          ? "1 class today"
                          : "\(scheduledCount) classes today")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if entry != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(attendedTint)
                }
            }

            HStack(spacing: 8) {
                choiceButton(.attended, title: "Yes", systemImage: "checkmark", tint: attendedTint)
                choiceButton(.missed, title: "Missed", systemImage: "xmark", tint: missedTint)
                choiceButton(.holiday, title: "Holiday", systemImage: "sun.max", tint: accentTint)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func choiceButton(_ choice: MarkTodayCard.DayChoice, title: String, systemImage: String, tint: Color) -> some View {
        let isSelected = current == choice
        return Button {
            onChoice(choice)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tint : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.clear : tint.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(LogPressStyle())
    }
}

// MARK: - Log tab (month calendar)

struct AttendanceLogView: View {
    @ObservedObject var subjectStore: SubjectStore

    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @State private var visibleMonth = Date()
    @State private var editingDay: Date?
    @State private var skipPlannerDay: Date?
    @State private var isShowingProPaywall = false

    private let calendar = Calendar.current

    private var subjectID: UUID? { subjectStore.selectedSubjectID }

    private var weeklySchedule: WeeklySchedule {
        guard
            let id = subjectID,
            let subject = subjectStore.subjects.first(where: { $0.id == id })
        else {
            return .empty
        }
        return subject.weeklySchedule
    }

    private var monthEntries: [Date: AttendanceLogEntry] {
        guard let id = subjectID else { return [:] }
        let entries = subjectStore.logEntries(subjectID: id, month: visibleMonth)
        return Dictionary(
            entries.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            subjectSelector
            monthHeader
            weekdayHeaderRow
            monthGrid
            monthSummary
            legend
            skipPlannerHint
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .sheet(
            isPresented: Binding(
                get: { editingDay != nil },
                set: { if $0 == false { editingDay = nil } }
            )
        ) {
            if let day = editingDay, let id = subjectID {
                DayEditorSheet(
                    subjectStore: subjectStore,
                    subjectID: id,
                    date: day,
                    timetableScheduled: weeklySchedule.classes(on: day),
                    isDefaultHoliday: AttendanceCalendar.isWeeklyHoliday(day, calendar: calendar)
                        && weeklySchedule.classes(on: day) == 0
                )
                .preferredColorScheme(.dark)
                .analyticsScreen(.dayEditor)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { skipPlannerDay != nil },
                set: { if $0 == false { skipPlannerDay = nil } }
            )
        ) {
            if let day = skipPlannerDay {
                SkipPlannerSheet(
                    result: SkipPlanner.evaluate(
                        date: day,
                        subjects: subjectStore.selectedSubject.map { [$0] } ?? subjectStore.subjects
                    ),
                    subjectFilterName: subjectStore.selectedSubjectName
                )
            }
        }
        .sheet(isPresented: $isShowingProPaywall) {
            ProPaywallView(source: "skip_planner")
        }
    }

    private var subjectSelector: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ATTENDANCE LOG")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .tracking(1.0)
                Text(subjectStore.selectedSubjectName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Menu {
                ForEach(subjectStore.subjects) { subject in
                    Button(subject.name) {
                        subjectStore.selectSubject(subject)
                    }
                }
            } label: {
                Label("Switch", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(LogPressStyle())
        }
    }

    private var monthHeader: some View {
        HStack {
            navButton(systemImage: "chevron.left") { shiftMonth(by: -1) }
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            navButton(systemImage: "chevron.right") { shiftMonth(by: 1) }
                .opacity(canGoForward ? 1 : 0.3)
                .disabled(!canGoForward)
        }
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols.indices, id: \.self) { index in
                Text(orderedWeekdaySymbols[index])
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    private func dayCell(for day: Date) -> some View {
        let normalized = calendar.startOfDay(for: day)
        let entry = monthEntries[normalized]
        let scheduled = weeklySchedule.classes(on: day)
        let isDefaultHoliday = AttendanceCalendar.isWeeklyHoliday(day, calendar: calendar) && scheduled == 0
        let status = DayMarkStatus.resolve(
            entry: entry,
            scheduledByTimetable: scheduled,
            isDefaultHoliday: isDefaultHoliday
        )
        let isFuture = normalized > calendar.startOfDay(for: Date())
        let isToday = calendar.isDateInToday(day)
        let skipRisk: SkipDayRisk? = {
            guard isFuture, scheduled > 0, let subject = subjectStore.selectedSubject else { return nil }
            return SkipPlanner.evaluate(date: day, subjects: [subject]).riskLevel
        }()

        return Button {
            if isFuture {
                guard scheduled > 0 else { return }
                AttendanceLogHaptics.tap()
                if entitlements.isPro {
                    skipPlannerDay = day
                } else {
                    AnalyticsService.shared.log(.skipPlannerLocked)
                    isShowingProPaywall = true
                }
                return
            }
            AttendanceLogHaptics.tap()
            editingDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isFuture ? .white.opacity(scheduled > 0 ? 0.7 : 0.25) : .white.opacity(0.9))
                if isFuture {
                    futureMarker(scheduled: scheduled, risk: skipRisk)
                } else {
                    Circle()
                        .fill(status.tint)
                        .frame(width: 7, height: 7)
                        .opacity(status == .noClass ? 0 : 1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(status == .noClass && isFuture == false ? Color.white.opacity(0.03) : (isFuture ? Color.white.opacity(scheduled > 0 ? 0.06 : 0.03) : status.tint.opacity(0.14)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                isToday ? Color.white.opacity(0.6) : status.tint.opacity(status == .noClass ? 0 : 0.4),
                                lineWidth: isToday ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(LogPressStyle())
        .disabled(isFuture && scheduled == 0)
    }

    @ViewBuilder
    private func futureMarker(scheduled: Int, risk: SkipDayRisk?) -> some View {
        if scheduled <= 0 {
            Circle()
                .fill(Color.clear)
                .frame(width: 7, height: 7)
        } else if entitlements.isPro, let risk {
            Circle()
                .fill(skipTint(risk))
                .frame(width: 7, height: 7)
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.28).opacity(0.85))
                .frame(width: 7, height: 7)
        }
    }

    private func skipTint(_ risk: SkipDayRisk) -> Color {
        switch risk {
        case .safe: return Color(red: 0.2, green: 0.9, blue: 0.5)
        case .mixed: return Color.orange
        case .unsafe: return Color.red
        case .noClass: return Color.clear
        }
    }

    private var monthSummary: some View {
        let entries = Array(monthEntries.values)
        let attended = entries.reduce(0) { $0 + $1.attendedContribution }
        let total = entries.reduce(0) { $0 + $1.totalContribution }
        let percentage = total > 0 ? Double(attended) / Double(total) * 100 : 0

        return HStack(spacing: 12) {
            summaryChip(title: "Marked", value: "\(attended)/\(total)")
            summaryChip(
                title: "This month",
                value: total > 0 ? String(format: "%.0f%%", percentage) : "--"
            )
            Spacer()
        }
    }

    private var legend: some View {
        let items: [DayMarkStatus] = [.attendedAll, .partial, .missed, .holiday, .unmarked]
        return FlexibleLegend(items: items)
    }

    private var skipPlannerHint: some View {
        Text(entitlements.isPro
             ? "Tap a future class day to see if you can skip without dropping below target."
             : "Pro: tap a future class day to check if a skip stays safe.")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.45))
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(LogPressStyle())
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthCells: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: visibleMonth)
        guard
            let firstOfMonth = calendar.date(from: comps),
            let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<range.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        return cells
    }

    private var canGoForward: Bool {
        guard
            let current = calendar.dateInterval(of: .month, for: visibleMonth),
            let thisMonth = calendar.dateInterval(of: .month, for: Date()),
            let maxMonth = calendar.date(byAdding: .month, value: 1, to: thisMonth.start)
        else {
            return false
        }
        return current.start < maxMonth
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        if value > 0 && !canGoForward { return }
        AttendanceLogHaptics.tap()
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = newMonth
        }
    }
}

// MARK: - Day editor sheet

private struct DayEditorSheet: View {
    @ObservedObject var subjectStore: SubjectStore
    let subjectID: UUID
    let date: Date
    let timetableScheduled: Int
    var isDefaultHoliday: Bool = false

    @Environment(\.dismiss) private var dismiss

    @State private var scheduled = 0
    @State private var attended = 0
    @State private var isHoliday = false
    @State private var hasExistingEntry = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }

                if isDefaultHoliday {
                    Section {
                        Text("This day is a holiday by default and won't affect your attendance. Turn off \"Holiday\" only if a class was actually held.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Mark") {
                    Toggle("Holiday / no class held", isOn: $isHoliday)

                    if !isHoliday {
                        Stepper("Classes that day: \(scheduled)", value: $scheduled, in: 0...12)
                            .onChange(of: scheduled) { _, newValue in
                                attended = min(attended, newValue)
                            }
                        Stepper("Attended: \(attended) of \(scheduled)", value: $attended, in: 0...max(scheduled, 0))
                    }
                }

                Section {
                    Button("Save") {
                        subjectStore.markDay(
                            subjectID: subjectID,
                            date: date,
                            attendedCount: isHoliday ? 0 : attended,
                            scheduledCount: isHoliday ? 0 : scheduled,
                            isHoliday: isHoliday,
                            source: "day_editor"
                        )
                        dismiss()
                    }

                    if hasExistingEntry {
                        Button("Clear this day", role: .destructive) {
                            subjectStore.clearDay(subjectID: subjectID, date: date, source: "day_editor")
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear(perform: loadState)
        }
    }

    private func loadState() {
        if let entry = subjectStore.logEntry(subjectID: subjectID, date: date) {
            hasExistingEntry = true
            isHoliday = entry.isHoliday
            scheduled = entry.scheduledClasses
            attended = entry.attendedClasses
        } else {
            hasExistingEntry = false
            isHoliday = isDefaultHoliday
            scheduled = max(timetableScheduled, timetableScheduled == 0 ? 1 : 0)
            attended = scheduled
        }
    }
}

// MARK: - Shared helpers

private struct FlexibleLegend: View {
    let items: [DayMarkStatus]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items.indices, id: \.self) { index in
                HStack(spacing: 5) {
                    Circle()
                        .fill(items[index].tint)
                        .frame(width: 7, height: 7)
                    Text(items[index].legendTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
        }
    }
}

private struct LogPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

enum AttendanceLogHaptics {
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
