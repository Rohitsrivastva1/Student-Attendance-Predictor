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
            return Color(red: 0.2, green: 0.9, blue: 0.5)
        case .partial:
            return Color.orange
        case .missed:
            return Color.red
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
        switch calendar.component(.weekday, from: date) {
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
}
