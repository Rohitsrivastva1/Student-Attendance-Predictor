//
//  AttendanceLogView.swift
//  Student Attendance Predictor
//

import SwiftUI

// MARK: - Mark Today card (Home tab)

/// Daily habit center for the active subject. One-tap Yes / Missed / Holiday,
/// with a short celebration when a mark is saved.
struct MarkTodayCard: View {
    @ObservedObject var subjectStore: SubjectStore
    var onCelebrated: (() -> Void)? = nil

    @State private var manualScheduled = 1
    @State private var partialAttended = 0
    @State private var isLoggingAnyway = false
    @State private var showCelebration = false
    @State private var celebratePulse = false

    private let today = Date()

    private enum DayChoice { case attended, missed, holiday }

    private let attendedTint = Color(red: 0.2, green: 0.9, blue: 0.5)
    private let missedTint = Color.red
    private let accentTint = Color(red: 0.32, green: 0.84, blue: 1.0)

    private var subjectID: UUID? { subjectStore.selectedSubjectID }

    private var scheduledByTimetable: Int {
        guard let id = subjectID else { return 0 }
        return subjectStore.classesScheduledToday(for: id, on: today)
    }

    private var existingEntry: AttendanceLogEntry? {
        guard let id = subjectID else { return nil }
        return subjectStore.logEntry(subjectID: id, date: today)
    }

    private var effectiveScheduled: Int {
        scheduledByTimetable > 0 ? scheduledByTimetable : max(1, manualScheduled)
    }

    private var isDefaultHolidayToday: Bool {
        AttendanceCalendar.isWeeklyHoliday(today) && scheduledByTimetable == 0
    }

    private var subjectHasTimetable: Bool {
        guard
            let id = subjectID,
            let subject = subjectStore.subjects.first(where: { $0.id == id })
        else {
            return false
        }
        return subject.weeklySchedule.totalPerWeek > 0
    }

    private var useDirectLogging: Bool {
        subjectHasTimetable == false && isDefaultHolidayToday == false
    }

    private var hasLoggedClass: Bool {
        guard let entry = existingEntry else { return false }
        return entry.isHoliday == false && entry.scheduledClasses > 0
    }

    private var currentChoice: DayChoice? {
        guard let entry = existingEntry else { return nil }
        if entry.isHoliday { return .holiday }
        if entry.scheduledClasses <= 0 { return nil }
        return entry.attendedClasses <= 0 ? .missed : .attended
    }

    private var reloadKey: String {
        let entry = existingEntry
        return [
            subjectID?.uuidString ?? "none",
            String(scheduledByTimetable),
            String(entry?.attendedClasses ?? -1),
            String(entry?.scheduledClasses ?? -1),
            String(entry?.isHoliday ?? false)
        ].joined(separator: "-")
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                content
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
                                    : Color.white.opacity(0.12),
                                lineWidth: showCelebration ? 1.5 : 1
                            )
                    )
            )
            .scaleEffect(celebratePulse ? 1.02 : 1.0)

            if showCelebration {
                CelebrationBurst(isActive: showCelebration)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay(alignment: .top) {
            if showCelebration {
                CelebrationToast(
                    message: "Great!",
                    subtitle: "Today's attendance saved."
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, -8)
            }
        }
        .onAppear(perform: loadState)
        .onChange(of: reloadKey) { _, _ in loadState() }
    }

    @ViewBuilder
    private var content: some View {
        if scheduledByTimetable > 0 {
            scheduledDayContent
        } else if useDirectLogging {
            untrackedDayContent
        } else if isLoggingAnyway || hasLoggedClass {
            logAnywayContent
        } else {
            noClassContent
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Classes")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if existingEntry != nil {
                Label("Saved", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(attendedTint)
            }
        }
    }

    // MARK: - States

    private var scheduledDayContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(scheduledByTimetable == 1
                  ? "Did you attend?"
                  : "\(scheduledByTimetable) classes today — did you attend?")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            choiceRow()

            if effectiveScheduled > 1 && currentChoice == .attended {
                partialStepper
            }
        }
    }

    private var untrackedDayContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Did you attend?")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            choiceRow()
        }
    }

    private var noClassContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isDefaultHolidayToday
                 ? "Today is a holiday — it won't affect your attendance."
                 : "No classes scheduled today.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                AttendanceLogHaptics.tap()
                withAnimation(.easeInOut(duration: 0.2)) { isLoggingAnyway = true }
            } label: {
                Label("Log a class anyway", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(accentTint)
            }
            .buttonStyle(LogPressStyle())
        }
    }

    private var logAnywayContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Logging a class for today")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button(existingEntry == nil ? "Cancel" : "Remove") {
                    removeOrCancel()
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(missedTint.opacity(0.95))
                .buttonStyle(LogPressStyle())
            }

            countStepper(title: "Classes held: \(effectiveScheduled)", value: $manualScheduled, range: 1...12)

            choiceRow(showHoliday: false)

            if effectiveScheduled > 1 && currentChoice == .attended {
                partialStepper
            }
        }
    }

    // MARK: - Choice controls

    private func choiceRow(showHoliday: Bool = true) -> some View {
        HStack(spacing: 8) {
            choiceButton(.attended, title: "Yes", systemImage: "checkmark", tint: attendedTint)
            choiceButton(.missed, title: "Missed", systemImage: "xmark", tint: missedTint)
            if showHoliday {
                choiceButton(.holiday, title: "Holiday", systemImage: "sun.max", tint: accentTint)
            }
        }
    }

    private func choiceButton(_ choice: DayChoice, title: String, systemImage: String, tint: Color) -> some View {
        let isSelected = currentChoice == choice
        return Button {
            apply(choice)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? tint : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.clear : tint.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(LogPressStyle())
    }

    private var partialStepper: some View {
        Stepper {
            Text("Attended \(partialAttended) of \(effectiveScheduled)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        } onIncrement: {
            partialAttended = min(effectiveScheduled, partialAttended + 1)
            saveClass(attended: partialAttended)
        } onDecrement: {
            partialAttended = max(0, partialAttended - 1)
            saveClass(attended: partialAttended)
        }
        .tint(accentTint)
    }

    private func countStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .tint(accentTint)
    }

    // MARK: - Actions

    private func apply(_ choice: DayChoice) {
        guard let id = subjectID else { return }
        let wasNew = existingEntry == nil
        AttendanceLogHaptics.tap()
        switch choice {
        case .attended:
            partialAttended = effectiveScheduled
            subjectStore.markDay(
                subjectID: id,
                date: today,
                attendedCount: effectiveScheduled,
                scheduledCount: effectiveScheduled,
                isHoliday: false,
                source: "mark_today"
            )
        case .missed:
            partialAttended = 0
            subjectStore.markDay(
                subjectID: id,
                date: today,
                attendedCount: 0,
                scheduledCount: effectiveScheduled,
                isHoliday: false,
                source: "mark_today"
            )
        case .holiday:
            subjectStore.markDay(
                subjectID: id,
                date: today,
                attendedCount: 0,
                scheduledCount: 0,
                isHoliday: true,
                source: "mark_today"
            )
        }
        if wasNew {
            triggerCelebration()
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

    private func saveClass(attended: Int) {
        guard let id = subjectID else { return }
        subjectStore.markDay(
            subjectID: id,
            date: today,
            attendedCount: attended,
            scheduledCount: effectiveScheduled,
            isHoliday: false,
            source: "mark_today_partial"
        )
    }

    private func removeOrCancel() {
        AttendanceLogHaptics.tap()
        if let id = subjectID, existingEntry != nil {
            subjectStore.clearDay(subjectID: id, date: today, source: "mark_today")
        }
        withAnimation(.easeInOut(duration: 0.2)) { isLoggingAnyway = false }
    }

    private func loadState() {
        if let entry = existingEntry {
            manualScheduled = max(1, entry.scheduledClasses)
            partialAttended = min(max(0, entry.attendedClasses), max(1, entry.scheduledClasses))
            isLoggingAnyway = hasLoggedClass
        } else {
            manualScheduled = 1
            partialAttended = effectiveScheduled
            isLoggingAnyway = false
        }
    }
}

// MARK: - Log tab (month calendar)

struct AttendanceLogView: View {
    @ObservedObject var subjectStore: SubjectStore

    @State private var visibleMonth = Date()
    @State private var editingDay: Date?

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

        return Button {
            guard !isFuture else { return }
            AttendanceLogHaptics.tap()
            editingDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isFuture ? .white.opacity(0.25) : .white.opacity(0.9))
                Circle()
                    .fill(status.tint)
                    .frame(width: 7, height: 7)
                    .opacity(status == .noClass ? 0 : 1)
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
        .buttonStyle(LogPressStyle())
        .disabled(isFuture)
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
