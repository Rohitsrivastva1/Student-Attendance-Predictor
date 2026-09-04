//
//  TodayBriefingCard.swift
//  Student Attendance Predictor
//
//  Home: one glance row. Hour chips and skip list live in a sheet.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TodayBriefingCard: View {
    @ObservedObject var subjectStore: SubjectStore
    @ObservedObject var deadlineStore: DeadlineStore
    let isPro: Bool
    var onBunkToday: () -> Void
    var onOpenDeadlines: () -> Void

    @State private var showDaySheet = false

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)

    private var skipVerb: String { StudentMarketStore.current.skipVerb }
    private var briefing: TodayBriefing {
        TodayBriefing.build(
            subjects: subjectStore.subjects,
            due: deadlineStore.upcomingWithin(days: 7).first
        )
    }

    var body: some View {
        Button {
            showDaySheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: glanceIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(cyan)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(glanceTitle)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(glanceSubtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(briefing.hasTimes ? classCountLabel : "Set")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(cyan)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDaySheet) {
            TodayHoursSheet(
                subjectStore: subjectStore,
                deadlineStore: deadlineStore,
                isPro: isPro,
                skipVerb: skipVerb,
                onBunkToday: {
                    showDaySheet = false
                    onBunkToday()
                },
                onOpenDeadlines: {
                    showDaySheet = false
                    onOpenDeadlines()
                }
            )
            .preferredColorScheme(.dark)
        }
        .onAppear {
            AnalyticsService.shared.log(
                .todayBriefingShown(hasTimes: briefing.hasTimes, classCount: briefing.classCount)
            )
        }
    }

    private var glanceIcon: String {
        if briefing.freeNow != nil { return "cup.and.saucer.fill" }
        if briefing.hasTimes { return "clock.fill" }
        return "clock"
    }

    private var glanceTitle: String {
        if let free = briefing.freeNow {
            return "Free now · \(free.rangeLabel)"
        }
        if briefing.isAfterCollege, briefing.hasTimes {
            return "Done for today"
        }
        if let current = briefing.slots.first(where: { $0.hour == briefing.currentHour }) {
            return "Now · \(current.subjectName)"
        }
        if let next = briefing.nextClass {
            return "Next · \(next.subjectName) \(next.period.rangeLabel)"
        }
        return "Today · \(briefing.weekdayTitle)"
    }

    private var glanceSubtitle: String {
        if briefing.hasTimes == false {
            return "Tap to set hours — free periods appear after"
        }
        if let next = briefing.nextClass, briefing.freeNow != nil || briefing.currentHour != nil {
            return "Next \(next.subjectName) · \(next.period.rangeLabel)"
        }
        if briefing.isLighterThanUsual {
            return "\(classCountLabel) · lighter than usual"
        }
        return classCountLabel
    }

    private var classCountLabel: String {
        if briefing.classCount == 0 { return "No classes" }
        if briefing.classCount == 1 { return "1 class" }
        return "\(briefing.classCount) classes"
    }
}

private struct TodayHoursSheet: View {
    @ObservedObject var subjectStore: SubjectStore
    @ObservedObject var deadlineStore: DeadlineStore
    let isPro: Bool
    let skipVerb: String
    var onBunkToday: () -> Void
    var onOpenDeadlines: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)

    private var live: TodayBriefing {
        TodayBriefing.build(
            subjects: subjectStore.subjects,
            due: deadlineStore.upcomingWithin(days: 7).first
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusBlock
                    if live.hasTimes {
                        slotList
                    }
                    hoursEditor
                    Button(action: onBunkToday) {
                        Text(isPro ? "Can I \(skipVerb) today?" : "Can I \(skipVerb) today? · Pro")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(cyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(cyan.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    if let due = live.dueLine {
                        Button(action: onOpenDeadlines) {
                            Text(due)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.1).ignoresSafeArea())
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var statusBlock: some View {
        if let free = live.freeNow {
            Text("Free now · \(free.rangeLabel)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(cyan)
        } else if live.hasTimes == false {
            Text("Tap the hours you have class. The rest are free.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        if let next = live.nextClass {
            Text("Next · \(next.subjectName) \(next.period.rangeLabel)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var slotList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(live.slots) { slot in
                HStack {
                    Text(slot.period.rangeLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 52, alignment: .leading)
                    Text(slot.subjectName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(slot.staysSafeIfSkipped ? "OK to \(skipVerb)" : "Attend")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(slot.staysSafeIfSkipped ? green : Color.orange)
                }
            }
        }
    }

    private var hoursEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hours")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
            ForEach(subjectStore.subjects) { subject in
                VStack(alignment: .leading, spacing: 8) {
                    Text(subject.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    PeriodChipGrid(selectedHours: Set(subject.weeklySchedule.hours(on: Date()))) { hour in
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        subjectStore.togglePeriod(hour, for: subject.id)
                        AnalyticsService.shared.log(.periodHourToggled)
                    }
                }
            }
        }
    }
}
