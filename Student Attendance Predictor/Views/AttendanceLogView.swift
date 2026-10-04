//
//  AttendanceLogView.swift
//  Student Attendance Predictor
//

import SwiftUI

// MARK: - Mark Today card (Home tab)

/// Daily habit center — marks all subjects scheduled today in one flow
/// (falls back to every subject when the timetable has nothing for today).
/// One subject card at a time; swipe left/right between subjects. “Mark all Attend”
/// stays available so bulk days don’t require N swipes.
struct MarkTodayCard: View {
    @ObservedObject var subjectStore: SubjectStore
    var isHighlighted: Bool = false
    var onCelebrated: (() -> Void)? = nil
    /// Fires when every subject scheduled today has been marked (optional focus prompt).
    var onAllSubjectsMarkedToday: ((SubjectSummary?) -> Void)? = nil
    var onAddSubject: (() -> Void)? = nil
    var onSetClassDays: ((UUID) -> Void)? = nil

    @State private var showCelebration = false
    @State private var celebratePulse = false
    @State private var selectedSubjectID: UUID = UUID()
    @State private var isShowingProPaywall = false

    private let today = Date()

    fileprivate enum DayChoice { case attended, missed, holiday }

    private let attendedTint = BrandColor.colorAttend
    private let missedTint = BrandColor.colorMissed
    private let accentTint = BrandColor.colorNoClass

    private var subjectsToday: [SubjectSummary] {
        // Unmarked first so paging starts on what still needs a tap.
        subjectStore.subjectsForMarkToday(on: today).sorted { lhs, rhs in
            let leftMarked = subjectStore.logEntry(subjectID: lhs.id, date: today) != nil
            let rightMarked = subjectStore.logEntry(subjectID: rhs.id, date: today) != nil
            if leftMarked != rightMarked { return leftMarked == false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var markedCount: Int {
        subjectsToday.reduce(0) { count, subject in
            subjectStore.logEntry(subjectID: subject.id, date: today) == nil ? count : count + 1
        }
    }

    private var unmarkedSubjects: [SubjectSummary] {
        subjectsToday.filter { subjectStore.logEntry(subjectID: $0.id, date: today) == nil }
    }

    private var promptCopy: (title: String, subtitle: String) {
        let count = subjectsToday.count
        if count == 0 {
            if subjectStore.subjects.isEmpty {
                return ("Attend or Missed?", "Add a subject first — then mark today.")
            }
            if subjectStore.subjects.contains(where: { $0.weeklySchedule.totalPerWeek > 0 }) {
                return ("No class today", "Enjoy the off day. We’ll ask again on a lecture day.")
            }
            return ("Attend or Missed?", "Add a subject first — then mark today.")
        }
        if count == 1 {
            return ("Attend or Missed?", "No class if it was cancelled or a holiday.")
        }
        return (
            "Attend or Missed?",
            "Tap the next subject below when you’re done."
        )
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                header
                if subjectsToday.isEmpty {
                    emptyContent
                } else {
                    if unmarkedSubjects.isEmpty == false && unmarkedSubjects.count >= 3 {
                        markAllYesButton
                    }

                    subjectPager

                    if subjectsToday.count > 1 {
                        subjectChips
                    }
                }
            }
            .padding(14)
            .background(BrandColor.cardFill(cornerRadius: 24).overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        showCelebration
                            ? BrandColor.colorAttend.opacity(0.45)
                            : (isHighlighted ? accentTint.opacity(0.85) : BrandColor.colorBorder),
                        lineWidth: showCelebration || isHighlighted ? 2 : 1
                    )
            ))
            .shadow(
                color: isHighlighted ? accentTint.opacity(0.35) : .clear,
                radius: isHighlighted ? 16 : 0,
                y: 0
            )
            .scaleEffect(isHighlighted ? 1.015 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isHighlighted)

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
        .sheet(isPresented: $isShowingProPaywall) {
            ProPaywallView(source: "locked_subject")
                .preferredColorScheme(.dark)
        }
        .onAppear {
            ensureSelection()
            syncFocusedSubjectToStore()
        }
        .onChange(of: subjectsToday.map(\.id)) { _, _ in
            ensureSelection()
        }
        .onChange(of: selectedSubjectID) { _, _ in
            syncFocusedSubjectToStore()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(todayDateTitle)
                .font(BrandType.display(20))
                .foregroundStyle(.white)
            Spacer()
            if subjectsToday.isEmpty == false {
                Text("\(markedCount)/\(subjectsToday.count)")
                    .font(BrandType.title(13))
                    .foregroundStyle(markedCount == subjectsToday.count ? attendedTint : .white.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
            }
            if let onAddSubject {
                Button(action: onAddSubject) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BrandColor.colorOnAccent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(BrandColor.colorAccentPrimary))
                }
                .buttonStyle(LogPressStyle())
                .accessibilityLabel("Add subject")
            }
        }
    }

    private var todayDateTitle: String {
        let weekday = today.formatted(.dateTime.weekday(.wide))
        let dayMonth = today.formatted(.dateTime.day().month(.abbreviated))
        return "\(weekday), \(dayMonth)"
    }

    private var emptyContent: some View {
        VStack(spacing: 12) {
            BrandHeroImage(illustration: .emptyHome, size: 120)
            if subjectStore.subjects.isEmpty {
                Text("Add your first subject, then Attend or Missed.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                if let onAddSubject {
                    Button(action: onAddSubject) {
                        Text("Add subject")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(BrandColor.colorOnAccent.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(BrandColor.colorAccentPrimary)
                            )
                    }
                    .buttonStyle(LogPressStyle())
                }
            } else {
                Text("No lectures on the timetable today.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                if let subject = subjectStore.subjects.first(where: { $0.weeklySchedule.totalPerWeek == 0 }),
                   let onSetClassDays {
                    Button {
                        onSetClassDays(subject.id)
                    } label: {
                        Text("Set days for \(subject.name)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(BrandColor.colorOnAccent.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(BrandColor.colorPremium)
                            )
                    }
                    .buttonStyle(LogPressStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var markAllYesButton: some View {
        Button {
            markAllUnmarkedAttended()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(unmarkedSubjects.count == 1
                      ? "Mark remaining Attend"
                      : "Mark all \(unmarkedSubjects.count) Attend")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(BrandColor.colorOnAccent)
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
                    needsClassDays: subject.weeklySchedule.totalPerWeek == 0,
                    isLocked: subjectStore.isSubjectLocked(subject.id),
                    entry: subjectStore.logEntry(subjectID: subject.id, date: today),
                    attendedTint: attendedTint,
                    missedTint: missedTint,
                    accentTint: accentTint,
                    onChoice: { choice in
                        apply(choice, for: subject)
                    },
                    onUnlockPro: {
                        AnalyticsService.shared.log(.proCtaTapped(surface: "locked_subject", action: "go_pro"))
                        isShowingProPaywall = true
                    },
                    onSetClassDays: onSetClassDays.map { callback in
                        { callback(subject.id) }
                    }
                )
                .padding(.horizontal, 2)
                .tag(subject.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 108)
    }

    private var pagerSelection: Binding<UUID> {
        Binding(
            get: { selectedSubjectID },
            set: { newValue in
                guard newValue != selectedSubjectID else { return }
                selectedSubjectID = newValue
            }
        )
    }

    private var subjectChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subjectsToday) { subject in
                    let isCurrent = subject.id == selectedSubjectID
                    let isMarked = subjectStore.logEntry(subjectID: subject.id, date: today) != nil
                    let isLocked = subjectStore.isSubjectLocked(subject.id)
                    Button {
                        AttendanceLogHaptics.tap()
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedSubjectID = subject.id
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(isCurrent ? Color.black : BrandColor.colorPremium)
                            } else if isMarked {
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
                                .fill(isCurrent ? BrandColor.colorAccentPrimary : Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(LogPressStyle())
                }
            }
        }
    }

    private func ensureSelection() {
        let ids = subjectsToday.map(\.id)
        guard let first = ids.first else { return }
        if ids.contains(selectedSubjectID) { return }
        selectedSubjectID = unmarkedSubjects.first?.id ?? first
        syncFocusedSubjectToStore()
    }

    private func syncFocusedSubjectToStore() {
        guard let subject = subjectStore.subjects.first(where: { $0.id == selectedSubjectID }) else { return }
        guard subject.totalClasses > 0 else { return }
        subjectStore.selectSubject(id: subject.id)
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
        let targets = unmarkedSubjects.filter { subjectStore.isSubjectLocked($0.id) == false }
        guard targets.isEmpty == false else {
            if unmarkedSubjects.contains(where: { subjectStore.isSubjectLocked($0.id) }) {
                AnalyticsService.shared.logProCtaShownOnce(surface: "locked_subject")
                isShowingProPaywall = true
            }
            return
        }
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
        if subjectStore.isSubjectLocked(subject.id) {
            AnalyticsService.shared.logProCtaShownOnce(surface: "locked_subject")
            isShowingProPaywall = true
            return
        }
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
        if subjectStore.subjects.first(where: { $0.id == subject.id })?.totalClasses ?? 0 > 0 {
            subjectStore.selectSubject(id: subject.id)
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
        if unmarkedSubjects.isEmpty, subjectsToday.isEmpty == false {
            let lastMarked = subjectsToday.first { subjectStore.logEntry(subjectID: $0.id, date: today) != nil }
            onAllSubjectsMarkedToday?(lastMarked ?? subjectsToday.first)
        }
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
    var needsClassDays: Bool = false
    var isLocked: Bool = false
    let entry: AttendanceLogEntry?
    let attendedTint: Color
    let missedTint: Color
    let accentTint: Color
    let onChoice: (MarkTodayCard.DayChoice) -> Void
    var onUnlockPro: (() -> Void)? = nil
    var onSetClassDays: (() -> Void)? = nil

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
                        .font(BrandType.display(18))
                        .foregroundStyle(.white)
                    if isLocked {
                        Text("Pro ended — unlock to keep marking this paper")
                            .font(BrandType.body(12))
                            .foregroundStyle(BrandColor.colorPremium)
                    } else if needsClassDays, let onSetClassDays {
                        Button(action: onSetClassDays) {
                            Text("Set class days")
                                .font(BrandType.body(12))
                                .foregroundStyle(BrandColor.colorPremium)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(scheduledCount == 1
                              ? "1 class today"
                              : "\(scheduledCount) classes today")
                            .font(BrandType.body(12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if isLocked {
                    Button {
                        AnalyticsService.shared.log(.proCtaTapped(surface: "locked_subject", action: "go_pro"))
                        onUnlockPro?()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Go Pro to mark")
                                .font(BrandType.title(12))
                        }
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BrandColor.premiumGradient)
                        )
                    }
                    .buttonStyle(LogPressStyle())
                } else {
                    choiceButton(.attended, title: "Attend", systemImage: "checkmark", tint: attendedTint)
                    choiceButton(.missed, title: "Missed", systemImage: "xmark", tint: missedTint)
                    choiceButton(.holiday, title: "No class", systemImage: "sun.max.fill", tint: accentTint)
                }
            }
        }
    }

    private func choiceButton(_ choice: MarkTodayCard.DayChoice, title: String, systemImage: String, tint: Color) -> some View {
        let isSelected = current == choice
        let isDimmed = current != nil && isSelected == false
        let usesLightLabel = choice == .missed
        let labelColor = usesLightLabel ? Color.white : BrandColor.colorOnAccent
        return Button {
            onChoice(choice)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(BrandType.title(12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint)
            )
            .opacity(isDimmed ? 0.58 : 1)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(labelColor.opacity(0.9))
                        .padding(5)
                }
            }
            .shadow(color: BrandColor.colorElevation, radius: isSelected ? 6 : 3, y: 2)
            .animation(.easeOut(duration: 0.18), value: current)
        }
        .buttonStyle(LogPressStyle())
    }
}

// MARK: - Log tab (month calendar)

struct AttendanceLogView: View {
    @ObservedObject var subjectStore: SubjectStore

    @State private var visibleMonth = Date()
    @State private var editingDay: Date?
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
            if let id = subjectID, subjectStore.isSubjectLocked(id) {
                lockedSubjectBanner
            }
            monthHeader
            weekdayHeaderRow
            monthGrid
            monthSummary
            legend
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
        .sheet(isPresented: $isShowingProPaywall) {
            ProPaywallView(source: "locked_subject")
                .preferredColorScheme(.dark)
        }
    }

    private var lockedSubjectBanner: some View {
        Button {
            AnalyticsService.shared.log(.proCtaTapped(surface: "locked_subject", action: "go_pro"))
            isShowingProPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(BrandColor.colorPremium)
                Text("This paper is locked. The first \(ProPurchaseConfiguration.freeSubjectLimit) stay free — Go Pro to keep marking extras.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BrandColor.colorPremium.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            AnalyticsService.shared.logProCtaShownOnce(surface: "locked_subject")
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
                    Button {
                        subjectStore.selectSubject(subject)
                    } label: {
                        Label {
                            Text(subject.name)
                        } icon: {
                            Image(systemName: subjectStore.isSubjectLocked(subject.id) ? "lock.fill" : "book")
                        }
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

        return Group {
            if isFuture {
                futureDayLabel(day: day)
            } else {
                Button {
                    AttendanceLogHaptics.tap()
                    if let id = subjectID, subjectStore.isSubjectLocked(id) {
                        AnalyticsService.shared.logProCtaShownOnce(surface: "locked_subject")
                        isShowingProPaywall = true
                    } else {
                        editingDay = day
                    }
                } label: {
                    dayLabel(
                        day: day,
                        status: status,
                        isToday: isToday,
                        showDot: status != .noClass
                    )
                }
                .buttonStyle(LogPressStyle())
            }
        }
    }

    private func futureDayLabel(day: Date) -> some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.28))
            Circle()
                .fill(Color.clear)
                .frame(width: 7, height: 7)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .accessibilityHidden(true)
    }

    private func dayLabel(
        day: Date,
        status: DayMarkStatus,
        isToday: Bool,
        showDot: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Circle()
                .fill(status.tint)
                .frame(width: 7, height: 7)
                .opacity(showDot ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(status == .noClass ? Color.white.opacity(0.03) : status.tint.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isToday ? Color.white.opacity(0.6) : status.tint.opacity(status == .noClass ? 0 : 0.4),
                            lineWidth: isToday ? 1.5 : 1
                        )
                )
        )
    }

    private var monthSummary: some View {
        let entries = Array(monthEntries.values)
        let attended = entries.reduce(0) { $0 + $1.attendedContribution }
        let total = entries.reduce(0) { $0 + $1.totalContribution }
        let needMarking = daysNeedingMarkInVisibleMonth

        return HStack(spacing: 12) {
            summaryChip(title: "Marked", value: "\(attended)/\(total)")
            summaryChip(
                title: "Need marking",
                value: needMarking == 1 ? "1 day" : "\(needMarking) days"
            )
            Spacer()
        }
    }

    private var daysNeedingMarkInVisibleMonth: Int {
        let today = calendar.startOfDay(for: Date())
        return monthCells.compactMap { $0 }.reduce(0) { count, day in
            let normalized = calendar.startOfDay(for: day)
            guard normalized <= today else { return count }
            let scheduled = weeklySchedule.classes(on: day)
            let isDefaultHoliday = AttendanceCalendar.isWeeklyHoliday(day, calendar: calendar) && scheduled == 0
            let status = DayMarkStatus.resolve(
                entry: monthEntries[normalized],
                scheduledByTimetable: scheduled,
                isDefaultHoliday: isDefaultHoliday
            )
            return status == .unmarked ? count + 1 : count
        }
    }

    private var legend: some View {
        let items: [DayMarkStatus] = [.attendedAll, .partial, .missed, .holiday, .unmarked]
        return FlexibleLegend(items: items)
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
            let thisMonth = calendar.dateInterval(of: .month, for: Date())
        else {
            return false
        }
        return current.start < thisMonth.start
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
                    if subjectStore.isSubjectLocked(subjectID) {
                        Text("This subject is over the free limit. Go Pro to edit days.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle("Holiday / no class held", isOn: $isHoliday)

                        if !isHoliday {
                            Stepper("Classes that day: \(scheduled)", value: $scheduled, in: 0...12)
                                .onChange(of: scheduled) { _, newValue in
                                    attended = min(attended, newValue)
                                }
                            Stepper("Attended: \(attended) of \(scheduled)", value: $attended, in: 0...max(scheduled, 0))
                        }
                    }
                }

                if subjectStore.isSubjectLocked(subjectID) == false {
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
