//
//  AttendanceLog.swift
//  Student Attendance Predictor
//

import SwiftUI

/// A single day's attendance mark for a subject. Used by both the "Mark Today"
/// card and the calendar Log tab. Marks are applied additively to the subject's
/// running total/attended counters.
struct AttendanceLogEntry: Codable, Equatable, Identifiable {
    let id: UUID
    var subjectID: UUID
    /// Normalized to the start of the day in the current calendar.
    var date: Date
    var scheduledClasses: Int
    var attendedClasses: Int
    var isHoliday: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        subjectID: UUID,
        date: Date,
        scheduledClasses: Int,
        attendedClasses: Int,
        isHoliday: Bool,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.subjectID = subjectID
        self.date = date
        self.scheduledClasses = scheduledClasses
        self.attendedClasses = attendedClasses
        self.isHoliday = isHoliday
        self.updatedAt = updatedAt
    }

    /// Net contribution of this entry to the subject's total classes counter.
    var totalContribution: Int {
        isHoliday ? 0 : max(0, scheduledClasses)
    }

    /// Net contribution of this entry to the subject's attended classes counter.
    var attendedContribution: Int {
        isHoliday ? 0 : min(max(0, attendedClasses), max(0, scheduledClasses))
    }
}

/// Visual status of a calendar day for a given subject.
enum DayMarkStatus {
    /// Attended every scheduled class.
    case attendedAll
    /// Attended some but not all scheduled classes.
    case partial
    /// Missed every scheduled class.
    case missed
    /// Explicitly marked as a holiday / cancelled.
    case holiday
    /// Has scheduled classes but hasn't been marked yet.
    case unmarked
    /// No classes scheduled on this weekday.
    case noClass

    var tint: Color {
        switch self {
        case .attendedAll:
            return BrandColor.colorAttend
        case .partial:
            return BrandColor.colorStreakBadge
        case .missed:
            return BrandColor.colorMissed
        case .holiday:
            return Color.white.opacity(0.35)
        case .unmarked:
            return Color.white.opacity(0.18)
        case .noClass:
            return Color.clear
        }
    }

    var legendTitle: String {
        switch self {
        case .attendedAll: return "Attended"
        case .partial: return "Partial"
        case .missed: return "Missed"
        case .holiday: return "Holiday"
        case .unmarked: return "Pending"
        case .noClass: return "No class"
        }
    }

    /// Derives the day's status from an optional saved entry and the number of
    /// classes scheduled on that weekday by the timetable.
    ///
    /// When there is no saved entry and no timetable classes, `isDefaultHoliday`
    /// (e.g. Sundays) renders the day as a holiday rather than a blank "no class".
    /// A logged day always reflects what was logged, so logging a class on a
    /// default-holiday day still counts toward attendance.
    static func resolve(
        entry: AttendanceLogEntry?,
        scheduledByTimetable: Int,
        isDefaultHoliday: Bool = false
    ) -> DayMarkStatus {
        if let entry {
            if entry.isHoliday {
                return .holiday
            }
            let total = max(0, entry.scheduledClasses)
            let attended = min(max(0, entry.attendedClasses), total)
            if total == 0 {
                return .noClass
            }
            if attended >= total {
                return .attendedAll
            }
            if attended <= 0 {
                return .missed
            }
            return .partial
        }
        if scheduledByTimetable > 0 {
            return .unmarked
        }
        return isDefaultHoliday ? .holiday : .noClass
    }
}

/// Calendar-level conventions shared by the attendance log UIs.
enum AttendanceCalendar {
    /// Days that are treated as a weekly holiday by default (currently Sunday).
    /// `Calendar.weekday` is 1=Sunday.
    static func isWeeklyHoliday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: date) == 1
    }
}

extension WeeklySchedule {
    /// Number of classes scheduled on the weekday of the given date.
    /// `Calendar.weekday` is 1=Sunday ... 7=Saturday.
    func classes(on date: Date, calendar: Calendar = .current) -> Int {
        count(weekday: calendar.component(.weekday, from: date))
    }

    func hours(on date: Date, calendar: Calendar = .current) -> [Int] {
        hours(weekday: calendar.component(.weekday, from: date))
    }

    func hasPeriodTimes(on date: Date, calendar: Calendar = .current) -> Bool {
        hours(on: date, calendar: calendar).isEmpty == false
    }

    func count(weekday: Int) -> Int {
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return 0
        }
    }

    func hours(weekday: Int) -> [Int] {
        switch weekday {
        case 1: return sundayHours
        case 2: return mondayHours
        case 3: return tuesdayHours
        case 4: return wednesdayHours
        case 5: return thursdayHours
        case 6: return fridayHours
        case 7: return saturdayHours
        default: return []
        }
    }

    /// One tap: hour on, hour off. Count follows the chips for that day.
    mutating func toggleHour(_ hour: Int, weekday: Int) {
        guard CollegePeriod.gridHours.contains(hour) else { return }
        var next = Set(hours(weekday: weekday))
        if next.contains(hour) {
            next.remove(hour)
        } else {
            next.insert(hour)
        }
        setHours(Array(next).sorted(), weekday: weekday)
        setCount(next.count, weekday: weekday)
    }

    mutating func toggleHour(_ hour: Int, on date: Date, calendar: Calendar = .current) {
        toggleHour(hour, weekday: calendar.component(.weekday, from: date))
    }

    /// Calendar weekdays (1 = Sunday … 7 = Saturday) that have at least one class.
    var scheduledWeekdays: Set<Int> {
        Set((1...7).filter { count(weekday: $0) > 0 })
    }

    /// Student-friendly setup: tap days, default 1 lecture each. Keeps existing hour chips.
    mutating func setClassDays(_ weekdays: Set<Int>, classesPerDay: Int = 1) {
        let lectures = max(1, classesPerDay)
        for weekday in 1...7 {
            if weekdays.contains(weekday) {
                if hours(weekday: weekday).isEmpty && count(weekday: weekday) == 0 {
                    setCount(lectures, weekday: weekday)
                }
            } else {
                setHours([], weekday: weekday)
                setCount(0, weekday: weekday)
            }
        }
    }

    private mutating func setHours(_ hours: [Int], weekday: Int) {
        switch weekday {
        case 1: sundayHours = hours
        case 2: mondayHours = hours
        case 3: tuesdayHours = hours
        case 4: wednesdayHours = hours
        case 5: thursdayHours = hours
        case 6: fridayHours = hours
        case 7: saturdayHours = hours
        default: break
        }
    }

    private mutating func setCount(_ count: Int, weekday: Int) {
        switch weekday {
        case 1: sunday = count
        case 2: monday = count
        case 3: tuesday = count
        case 4: wednesday = count
        case 5: thursday = count
        case 6: friday = count
        case 7: saturday = count
        default: break
        }
    }
}
