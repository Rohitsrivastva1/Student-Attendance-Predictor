//
//  FirstRunSetupView.swift
//  Student Attendance Predictor
//
//  First session: name a paper → pick days → mark today if they had class.
//  Not dismissible — this is the habit, not a banner they can X away.
//

import SwiftUI

struct FirstRunSetupView: View {
    @ObservedObject var subjectStore: SubjectStore
    var onFinished: () -> Void

    @State private var step = 0
    @State private var subjectName = ""
    @State private var selectedWeekdays: Set<Int> = ClassWeekday.mondayToFriday
    @State private var createdSubjectID: UUID?
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var createdSubject: SubjectSummary? {
        guard let createdSubjectID else { return nil }
        return subjectStore.subjects.first(where: { $0.id == createdSubjectID })
    }

    private var todayIsClassDay: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return selectedWeekdays.contains(weekday)
    }

    var body: some View {
        ZStack {
            BrandColor.colorBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    if step > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                step -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        .accessibilityLabel("Back")
                    } else {
                        Color.clear.frame(width: 36, height: 36)
                    }

                    Spacer()
                    stepDots
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Group {
                    switch step {
                    case 0: nameStep
                    case 1: daysStep
                    default: markStep
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: step)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .analyticsScreen(.firstRunSetup)
        .onAppear {
            logFirstRunStep()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                nameFocused = true
            }
        }
        .onChange(of: step) { _, _ in
            logFirstRunStep()
        }
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index == step ? BrandColor.colorAccentPrimary : Color.white.opacity(0.22))
                    .frame(width: index == step ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of 3")
    }

    private var nameStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    BrandHeroImage(illustration: .emptySubjects, size: 160)
                    VStack(spacing: 10) {
                        Text("Add one subject")
                            .font(BrandType.display(28))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Maths, DSA, History — whatever you have this semester. You can add more later.")
                            .font(BrandType.body(16))
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                    }

                    TextField("e.g. Maths", text: $subjectName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .focused($nameFocused)
                        .submitLabel(.continue)
                        .onSubmit { continueFromName() }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 18)
                        .background(BrandColor.cardFill(cornerRadius: 18))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }

            primaryButton("Continue", enabled: trimmedName.isEmpty == false, action: continueFromName)
        }
    }

    private var daysStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BrandHeroImage(illustration: .onboardKnow, size: 140)
                        .frame(maxWidth: .infinity)

                    Text("Which days is \(createdSubject?.name ?? trimmedName)?")
                        .font(BrandType.display(26))
                        .foregroundStyle(.white)

                    Text("Today will only ask you to mark on these days — so you don’t log a class you didn’t have.")
                        .font(BrandType.body(15))
                        .foregroundStyle(.white.opacity(0.68))

                    ClassDaysPicker(selectedWeekdays: $selectedWeekdays)
                        .padding(16)
                        .background(BrandColor.cardFill(cornerRadius: 20))
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            primaryButton("Save days", enabled: selectedWeekdays.isEmpty == false, action: continueFromDays)
        }
    }

    private var markStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    BrandHeroImage(illustration: .onboardTap, size: 160)

                    if todayIsClassDay {
                        VStack(spacing: 10) {
                            Text("Did you go to \(createdSubject?.name ?? "class") today?")
                                .font(BrandType.display(26))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            Text("That’s the whole habit. After every class, one tap.")
                                .font(BrandType.body(15))
                                .foregroundStyle(.white.opacity(0.68))
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 10) {
                            markButton(
                                title: "Attend",
                                subtitle: "I was in class",
                                tint: BrandColor.colorAttend,
                                systemImage: "checkmark"
                            ) {
                                markToday(attended: true, holiday: false)
                            }
                            markButton(
                                title: "Missed",
                                subtitle: "I skipped or was absent",
                                tint: BrandColor.colorMissed,
                                systemImage: "xmark",
                                lightLabel: true
                            ) {
                                markToday(attended: false, holiday: false)
                            }
                            markButton(
                                title: "No class",
                                subtitle: "Cancelled or a holiday",
                                tint: BrandColor.colorNoClass,
                                systemImage: "sun.max.fill"
                            ) {
                                markToday(attended: false, holiday: true)
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            Text("You’re set")
                                .font(BrandType.display(28))
                                .foregroundStyle(.white)
                            Text("No lecture today for \(createdSubject?.name ?? "this subject"). After class, open Bunk Planner and tap Attend or Missed — takes two seconds.")
                                .font(BrandType.body(16))
                                .foregroundStyle(.white.opacity(0.68))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            if todayIsClassDay == false {
                primaryButton("Go to Today", enabled: true, action: finishWithoutMark)
            }
        }
    }

    private func markButton(
        title: String,
        subtitle: String,
        tint: Color,
        systemImage: String,
        lightLabel: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.18)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(lightLabel ? Color.white : BrandColor.colorOnAccent)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint)
            )
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(BrandColor.colorOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(enabled ? BrandColor.colorAccentPrimary : Color.white.opacity(0.18))
                )
        }
        .disabled(enabled == false)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .padding(.top, 8)
    }

    private func continueFromName() {
        guard trimmedName.isEmpty == false else { return }
        if let existing = createdSubjectID,
           subjectStore.subjects.contains(where: { $0.id == existing }) {
            subjectStore.renameSubject(id: existing, to: trimmedName)
        } else if subjectStore.addSubject(named: trimmedName) {
            createdSubjectID = subjectStore.selectedSubjectID
        } else {
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            step = 1
        }
    }

    private func continueFromDays() {
        guard selectedWeekdays.isEmpty == false, let id = createdSubjectID else { return }
        var schedule = subjectStore.weeklySchedule(for: id)
        schedule.setClassDays(selectedWeekdays)
        subjectStore.updateWeeklySchedule(for: id, schedule: schedule)
        withAnimation(.easeInOut(duration: 0.25)) {
            step = 2
        }
    }

    private func markToday(attended: Bool, holiday: Bool) {
        guard let id = createdSubjectID else { return }
        let scheduled = holiday ? 0 : max(1, subjectStore.classesScheduledToday(for: id, on: Date()))
        subjectStore.markDay(
            subjectID: id,
            date: Date(),
            attendedCount: holiday ? 0 : (attended ? scheduled : 0),
            scheduledCount: scheduled,
            isHoliday: holiday,
            source: "first_run"
        )
        GuidedSetupStore.shared.complete()
        NotificationService.requestAuthorizationIfNeeded()
        AnalyticsService.shared.log(.firstRunFinished(via: holiday ? "holiday" : (attended ? "attended" : "missed")))
        AnalyticsService.shared.log(.funnelStep(step: "first_session_done"))
        onFinished()
    }

    private func finishWithoutMark() {
        NotificationService.requestAuthorizationIfNeeded()
        AnalyticsService.shared.log(.firstRunFinished(via: "skipped"))
        AnalyticsService.shared.log(.funnelStep(step: "first_session_done"))
        onFinished()
    }

    private func logFirstRunStep() {
        let name: String
        switch step {
        case 0: name = "name"
        case 1: name = "days"
        default: name = "mark"
        }
        AnalyticsService.shared.log(.firstRunStepShown(step: name))
        let funnel: String
        switch name {
        case "name": funnel = "first_subject"
        case "days": funnel = "first_days"
        default: funnel = "first_mark"
        }
        AnalyticsService.shared.log(.funnelStep(step: funnel))
    }
}
