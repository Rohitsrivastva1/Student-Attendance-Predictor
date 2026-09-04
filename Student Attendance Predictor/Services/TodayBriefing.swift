//
//  TodayBriefing.swift
//  Student Attendance Predictor
//
//  Assembles today's timetable, free hours, and skip safety from existing data.
//

import Foundation

struct TodayClassSlot: Identifiable, Equatable {
    let subjectID: UUID
    let subjectName: String
    let hour: Int
    let staysSafeIfSkipped: Bool

    var id: String { "\(subjectID.uuidString)-\(hour)" }
    var period: CollegePeriod { CollegePeriod(startHour: hour) }
}

struct TodayBriefing: Equatable {
    let weekdayTitle: String
    let classCount: Int
    let busiestDayCount: Int
    let hasTimes: Bool
    let slots: [TodayClassSlot]
    let freeHours: [Int]
    let currentHour: Int?
    let dueLine: String?

    var isLighterThanUsual: Bool {
        busiestDayCount > 0 && classCount < busiestDayCount
    }

    var freeNow: CollegePeriod? {
        guard let currentHour, freeHours.contains(currentHour) else { return nil }
        return CollegePeriod(startHour: currentHour)
    }

    var nextClass: TodayClassSlot? {
        let hour = currentHour ?? -1
        return slots.first { $0.hour > hour }
    }

    var clockHour: Int {
        currentHour ?? Calendar.current.component(.hour, from: Date())
    }

    var isAfterCollege: Bool {
        clockHour > CollegePeriod.lastHour
    }

    static func build(
        subjects: [SubjectSummary],
        due: AcademicDeadline?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TodayBriefing {
        let skipResult = SkipPlanner.evaluate(date: now, subjects: subjects)
        let skipSafeByID = Dictionary(uniqueKeysWithValues: skipResult.impacts.map { ($0.id, $0.staysSafe) })
        let hasTimes = subjects.contains { $0.weeklySchedule.hasPeriodTimes(on: now, calendar: calendar) }

        var occupied = Set<Int>()
        var slots: [TodayClassSlot] = []
        for subject in subjects {
            let hours = subject.weeklySchedule.hours(on: now, calendar: calendar)
            for hour in hours {
                occupied.insert(hour)
                slots.append(
                    TodayClassSlot(
                        subjectID: subject.id,
                        subjectName: subject.name,
                        hour: hour,
                        staysSafeIfSkipped: skipSafeByID[subject.id] ?? (subject.status == .safe)
                    )
                )
            }
        }
        slots.sort { lhs, rhs in
            if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
            return lhs.subjectName.localizedCaseInsensitiveCompare(rhs.subjectName) == .orderedAscending
        }

        let classCount: Int
        if hasTimes {
            classCount = slots.count
        } else {
            classCount = subjects.reduce(0) { $0 + $1.weeklySchedule.classes(on: now) }
        }

        let busiest = (1...7).map { day in
            subjects.reduce(0) { $0 + $1.weeklySchedule.count(weekday: day) }
        }.max() ?? 0

        let freeHours = hasTimes
            ? CollegePeriod.gridHours.filter { occupied.contains($0) == false }
            : []

        let dueLine: String? = {
            guard let due else { return nil }
            let course = due.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
            if course.isEmpty {
                return "\(due.kind.title) · \(due.title) · \(due.countdownLabel)"
            }
            return "\(due.kind.title) · \(due.title) (\(course)) · \(due.countdownLabel)"
        }()

        return TodayBriefing(
            weekdayTitle: now.formatted(.dateTime.weekday(.wide)),
            classCount: classCount,
            busiestDayCount: busiest,
            hasTimes: hasTimes,
            slots: slots,
            freeHours: freeHours,
            currentHour: CollegePeriod.current(at: now, calendar: calendar)?.startHour,
            dueLine: dueLine
        )
    }
}
