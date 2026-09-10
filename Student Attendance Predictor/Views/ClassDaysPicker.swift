//
//  ClassDaysPicker.swift
//  Student Attendance Predictor
//
//  One-tap “which days is this class?” — enough for Today to hide off days.
//

import SwiftUI

enum ClassWeekday: Int, CaseIterable, Identifiable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    static let weekdays: [ClassWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    static let mondayToFriday: Set<Int> = Set([2, 3, 4, 5, 6])
    static let monWedFri: Set<Int> = Set([2, 4, 6])
}

struct ClassDaysPicker: View {
    @Binding var selectedWeekdays: Set<Int>
    var showsSunday: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                presetChip("Mon–Fri", days: ClassWeekday.mondayToFriday)
                presetChip("Mon Wed Fri", days: ClassWeekday.monWedFri)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(ClassWeekday.weekdays) { day in
                    dayChip(day)
                }
                if showsSunday {
                    dayChip(.sunday)
                }
            }
        }
    }

    private func presetChip(_ title: String, days: Set<Int>) -> some View {
        let isOn = selectedWeekdays == days
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selectedWeekdays = isOn ? [] : days
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isOn ? BrandColor.colorOnAccent : .white.opacity(0.88))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn ? BrandColor.colorAccentPrimary : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func dayChip(_ day: ClassWeekday) -> some View {
        let isOn = selectedWeekdays.contains(day.rawValue)
        return Button {
            var next = selectedWeekdays
            if isOn {
                next.remove(day.rawValue)
            } else {
                next.insert(day.rawValue)
            }
            withAnimation(.easeOut(duration: 0.15)) {
                selectedWeekdays = next
            }
        } label: {
            Text(day.shortLabel)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(isOn ? BrandColor.colorOnAccent : .white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isOn ? BrandColor.colorAccentPrimary : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isOn ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.shortLabel)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct ClassDaysSheet: View {
    @ObservedObject var subjectStore: SubjectStore
    let subjectID: UUID
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedWeekdays: Set<Int> = []
    @State private var editedName = ""
    @State private var showHourEditor = false
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        editedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        trimmedName.isEmpty ? "this class" : trimmedName
    }

    private var isPlaceholderName: Bool {
        let name = trimmedName
        guard name.hasPrefix("Subject ") else { return false }
        let suffix = name.dropFirst("Subject ".count)
        return suffix.isEmpty == false && suffix.allSatisfy(\.isNumber)
    }

    private var canSave: Bool {
        selectedWeekdays.isEmpty == false && trimmedName.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Which days is \(displayName)?")
                        .font(BrandType.display(26))
                        .foregroundStyle(.white)

                    Text("Name the paper, then tap the days you have it. We’ll only ask you to mark on those days.")
                        .font(BrandType.body(15))
                        .foregroundStyle(.white.opacity(0.68))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subject name")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        HStack(spacing: 10) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(BrandColor.colorAccentPrimary)
                            TextField("e.g. Maths", text: $editedName)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($nameFocused)
                                .submitLabel(.done)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(BrandColor.cardFill(cornerRadius: 16))

                        if isPlaceholderName {
                            Text("Give it a real name — Maths, DSA, History.")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BrandColor.colorPremium)
                        }
                    }

                    ClassDaysPicker(selectedWeekdays: $selectedWeekdays)
                        .padding(16)
                        .background(BrandColor.cardFill(cornerRadius: 20))

                    Button {
                        AnalyticsService.shared.log(.timetableEditorOpened)
                        showHourEditor = true
                    } label: {
                        HStack {
                            Label("Set lecture hours (optional)", systemImage: "clock")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(14)
                        .background(BrandColor.cardFill(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not now") {
                        dismiss()
                        onFinished?()
                    }
                    .foregroundStyle(.white.opacity(0.55))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(canSave ? BrandColor.colorAccentPrimary : .white.opacity(0.35))
                    .disabled(canSave == false)
                }
            }
            .onAppear {
                let current = subjectStore.subjects.first(where: { $0.id == subjectID })
                editedName = current?.name ?? ""
                selectedWeekdays = subjectStore.weeklySchedule(for: subjectID).scheduledWeekdays
                if isPlaceholderName {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        nameFocused = true
                    }
                }
            }
            .sheet(isPresented: $showHourEditor) {
                TimetableEditorSheet(subjectStore: subjectStore, subjectID: subjectID)
                    .preferredColorScheme(.dark)
                    .analyticsScreen(.timetableEditor)
            }
        }
        .preferredColorScheme(.dark)
        .analyticsScreen(.classDays)
    }

    private func save() {
        guard canSave else { return }
        subjectStore.renameSubject(id: subjectID, to: trimmedName)
        var schedule = subjectStore.weeklySchedule(for: subjectID)
        schedule.setClassDays(selectedWeekdays)
        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
        dismiss()
        onFinished?()
    }
}
