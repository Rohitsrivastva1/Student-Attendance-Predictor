//
//  NotificationTemplates.swift
//  Student Attendance Predictor
//
//  Copy only. Engine decides whether/which category.
//  Rule: title + first body clause carry subject, %, or action (collapsed Android view).
//

import Foundation

struct NotificationTemplate: Equatable, Identifiable {
    let id: String
    let category: PersonalityNotificationCategory
    let variant: String
    let title: String
    let body: String
    /// If true, only pick when attendance actually moved (curiosity “changed” lines).
    var requiresAttendanceMove: Bool = false
    /// If true, only pick when safeBunks ≥ 2.
    var requiresRealBunkBuffer: Bool = false
}

enum NotificationTemplates {
    static func pool(for category: PersonalityNotificationCategory) -> [NotificationTemplate] {
        switch category {
        case .funny: return funny
        case .curiosity: return curiosity
        case .savage: return savage
        case .bunkAvailable: return bunkAvailable
        case .bunkNotAvailable: return bunkNotAvailable
        case .lowAttendance: return lowAttendance
        case .attendanceWarning: return attendanceWarning
        case .classReminder: return classReminder
        case .streak: return streak
        }
    }

    static func plain(slot: NotificationSlot, context: NotificationContext) -> NotificationTemplate {
        switch slot {
        case .evening:
            if context.hasData == false {
                return NotificationTemplate(
                    id: "plain_evening_empty",
                    category: .classReminder,
                    variant: "plain",
                    title: "Mark today’s class",
                    body: "Tap Attend or Missed — takes 5 seconds."
                )
            }
            if context.isSafe {
                if context.hasRealBunkBuffer {
                    return NotificationTemplate(
                        id: "plain_evening_safe",
                        category: .bunkAvailable,
                        variant: "plain",
                        title: "{subject_name} at {attendance_percentage}",
                        body: "{safe_bunks_label} left under {required_percentage}. Log today."
                    )
                }
                return NotificationTemplate(
                    id: "plain_evening_line",
                    category: .attendanceWarning,
                    variant: "plain",
                    title: "{subject_name} at {attendance_percentage}",
                    body: "Near the {required_percentage} line. Log today in one tap."
                )
            }
            return NotificationTemplate(
                id: "plain_evening_risk",
                category: .lowAttendance,
                variant: "plain",
                title: "{subject_name} at {attendance_percentage}",
                body: "Need {recovery_needed_label} attended. Log today, then show up."
            )
        case .morning:
            return NotificationTemplate(
                id: "plain_morning",
                category: .classReminder,
                variant: "plain",
                title: "{classes_today_label} today",
                body: "Show up first — mark Attend or Missed later."
            )
        case .monday:
            return NotificationTemplate(
                id: "plain_monday",
                category: .curiosity,
                variant: "plain",
                title: "{subject_name} · {attendance_percentage}",
                body: "New week. Log as you go — don’t guess the {required_percentage} line."
            )
        case .friday:
            if context.hasRealBunkBuffer {
                return NotificationTemplate(
                    id: "plain_friday_safe",
                    category: .bunkAvailable,
                    variant: "plain",
                    title: "{subject_name}: {safe_bunks_label} left",
                    body: "{attendance_percentage} under {required_percentage}. Don’t burn the buffer this weekend."
                )
            }
            return NotificationTemplate(
                id: "plain_friday_risk",
                category: .bunkNotAvailable,
                variant: "plain",
                title: "{subject_name} at {attendance_percentage}",
                body: "Thin margin to {required_percentage}. Think twice before you {skip_verb}."
            )
        case .immediate:
            if context.isSafe == false {
                return NotificationTemplate(
                    id: "plain_immediate_risk",
                    category: .lowAttendance,
                    variant: "plain",
                    title: "{subject_name} at {attendance_percentage}",
                    body: "Attend the next {recovery_needed_label} to climb back."
                )
            }
            if context.isCloseToMinimum {
                return NotificationTemplate(
                    id: "plain_immediate_line",
                    category: .attendanceWarning,
                    variant: "plain",
                    title: "{subject_name}: thin buffer",
                    body: "{attendance_percentage} · {safe_bunks_label} left to {required_percentage}."
                )
            }
            return NotificationTemplate(
                id: "plain_immediate_ok",
                category: .bunkAvailable,
                variant: "plain",
                title: "{subject_name}: {safe_bunks_label} safe",
                body: "{attendance_percentage}. Open Skip Planner before you {skip_verb}."
            )
        }
    }

    // MARK: - Funny (info / action in title)

    private static let funny: [NotificationTemplate] = [
        .init(id: "funny_01", category: .funny, variant: "a",
              title: "{subject_name} at {attendance_percentage}",
              body: "The register still wants a tap. Mark Attend or Missed."),
        .init(id: "funny_02", category: .funny, variant: "b",
              title: "Mark {subject_name} before you forget",
              body: "College wants receipts. One tap. Takes 5 seconds."),
        .init(id: "funny_03", category: .funny, variant: "a",
              title: "{subject_name}: present… ish?",
              body: "You’re at {attendance_percentage}. Log the truth before the alibi gets creative."),
        .init(id: "funny_04", category: .funny, variant: "b",
              title: "Log today’s class — {attendance_percentage}",
              body: "{subject_name} is still on the books. Tap Attend or Missed."),
        .init(id: "funny_05", category: .funny, variant: "a",
              title: "{classes_today_label} today — mark them",
              body: "Your chair can wait. The shortage list won’t."),
        .init(id: "funny_06", category: .funny, variant: "b",
              title: "Class still exists. Unfortunately.",
              body: "Mark {subject_name} before it becomes a mystery. {attendance_percentage}."),
        .init(id: "funny_07", category: .funny, variant: "a",
              title: "{subject_name} needs a tap",
              body: "Save the group chat from another “did you go?” thread."),
        .init(id: "funny_08", category: .funny, variant: "b",
              title: "Back-bench check: {attendance_percentage}",
              body: "Prof’s counting heads. Log {subject_name} either way."),
        .init(id: "funny_09", category: .funny, variant: "a",
              title: "{subject_name} · still {attendance_percentage}",
              body: "Shocking: class happened. Mark Attend or Missed."),
        .init(id: "funny_10", category: .funny, variant: "b",
              title: "5-second mark for {subject_name}",
              body: "{classes_today_label} on the timetable. Don’t leave it hanging.")
    ]

    // MARK: - Curiosity (move lines gated)

    private static let curiosity: [NotificationTemplate] = [
        .init(id: "cur_move_01", category: .curiosity, variant: "a",
              title: "{subject_name} moved overnight",
              body: "{attendance_percentage} now. See what changed.",
              requiresAttendanceMove: true),
        .init(id: "cur_move_02", category: .curiosity, variant: "b",
              title: "{subject_name} isn’t where it was",
              body: "Now {attendance_percentage}. Open and confirm the buffer.",
              requiresAttendanceMove: true),
        .init(id: "cur_move_03", category: .curiosity, variant: "a",
              title: "Your {skip_noun} budget just changed",
              body: "{subject_name} at {attendance_percentage}. Peek before you {skip_verb}.",
              requiresAttendanceMove: true, requiresRealBunkBuffer: true),
        .init(id: "cur_01", category: .curiosity, variant: "a",
              title: "{subject_name} at {attendance_percentage}",
              body: "Under the {required_percentage} rule — check safe {skip_noun} before you guess."),
        .init(id: "cur_02", category: .curiosity, variant: "b",
              title: "Before you {skip_verb} {subject_name}…",
              body: "You’re at {attendance_percentage}. Open the buffer first."),
        .init(id: "cur_03", category: .curiosity, variant: "a",
              title: "{subject_name}: mid-sem reality check",
              body: "{attendance_percentage} vs {required_percentage}. Ten seconds to see the math."),
        .init(id: "cur_04", category: .curiosity, variant: "b",
              title: "Rumor: you can still {skip_verb}",
              body: "Fact check: {subject_name} has {safe_bunks_label} left at {attendance_percentage}.",
              requiresRealBunkBuffer: true),
        .init(id: "cur_05", category: .curiosity, variant: "a",
              title: "Shortage check · {attendance_percentage}",
              body: "{subject_name}. Open before the back bench becomes a lifestyle.")
    ]

    // MARK: - Savage (opt-in; only with real buffer — engine enforces)

    private static let savage: [NotificationTemplate] = [
        .init(id: "sav_01", category: .savage, variant: "a",
              title: "{subject_name} at {attendance_percentage} — bold week",
              body: "You’ve got {safe_bunks_label} left. The register still takes notes.",
              requiresRealBunkBuffer: true),
        .init(id: "sav_02", category: .savage, variant: "b",
              title: "{required_percentage} called about {subject_name}",
              body: "{attendance_percentage} with {safe_bunks_label} spare. Don’t spend them all Friday.",
              requiresRealBunkBuffer: true),
        .init(id: "sav_03", category: .savage, variant: "a",
              title: "One more {skip_verb} on {subject_name}?",
              body: "You’re fine for now ({attendance_percentage}) — {safe_bunks_label} left. Still log today.",
              requiresRealBunkBuffer: true),
        .init(id: "sav_04", category: .savage, variant: "b",
              title: "{subject_name}: interesting strategy",
              body: "Treating class like optional. You’re at {attendance_percentage} — mark the day.",
              requiresRealBunkBuffer: true),
        .init(id: "sav_05", category: .savage, variant: "a",
              title: "Empty chair energy · {attendance_percentage}",
              body: "{subject_name} notices. Log Attend or Missed before shortage season.",
              requiresRealBunkBuffer: true)
    ]

    // MARK: - Bunk available (engine: safeBunks ≥ 2)

    private static let bunkAvailable: [NotificationTemplate] = [
        .init(id: "bunk_av_01", category: .bunkAvailable, variant: "a",
              title: "{subject_name}: {safe_bunks_label} safe",
              body: "{attendance_percentage} under {required_percentage}. Spend them like an adult.",
              requiresRealBunkBuffer: true),
        .init(id: "bunk_av_02", category: .bunkAvailable, variant: "b",
              title: "Buffer unlocked · {safe_bunks_label}",
              body: "{subject_name} at {attendance_percentage}. Open Skip Planner before you {skip_verb}.",
              requiresRealBunkBuffer: true),
        .init(id: "bunk_av_03", category: .bunkAvailable, variant: "a",
              title: "{subject_name} can spare {safe_bunks_label}",
              body: "Math says you won’t sink. Still log today.",
              requiresRealBunkBuffer: true),
        .init(id: "bunk_av_04", category: .bunkAvailable, variant: "b",
              title: "{safe_bunks_label} left on {subject_name}",
              body: "{attendance_percentage}. Don’t yeet the whole buffer this weekend.",
              requiresRealBunkBuffer: true),
        .init(id: "bunk_av_05", category: .bunkAvailable, variant: "a",
              title: "Green light on {subject_name}",
              body: "{attendance_percentage} · {safe_bunks_label} before the {required_percentage} shortage hit.",
              requiresRealBunkBuffer: true)
    ]

    // MARK: - Bunk not available

    private static let bunkNotAvailable: [NotificationTemplate] = [
        .init(id: "bunk_no_01", category: .bunkNotAvailable, variant: "a",
              title: "{subject_name} at {attendance_percentage} — maybe don’t",
              body: "Thin ice to {required_percentage}. Today’s class is the play."),
        .init(id: "bunk_no_02", category: .bunkNotAvailable, variant: "b",
              title: "{skip_verb_title} denied · {attendance_percentage}",
              body: "{subject_name} has no spare {skip_noun}. Show up and log it."),
        .init(id: "bunk_no_03", category: .bunkNotAvailable, variant: "a",
              title: "Not today for {subject_name}",
              body: "That {skip_verb} could dent {attendance_percentage}. Mark Attend."),
        .init(id: "bunk_no_04", category: .bunkNotAvailable, variant: "b",
              title: "Hold up — {attendance_percentage}",
              body: "{required_percentage} is a rule, not a vibe. Sit this {skip_verb} out."),
        .init(id: "bunk_no_05", category: .bunkNotAvailable, variant: "a",
              title: "{subject_name}: zero spare {skip_noun}",
              body: "Near the shortage line. Log today and attend.")
    ]

    // MARK: - Low attendance

    private static let lowAttendance: [NotificationTemplate] = [
        .init(id: "low_01", category: .lowAttendance, variant: "a",
              title: "{subject_name} at {attendance_percentage}",
              body: "Below {required_percentage}. Need {recovery_needed_label} attended — start today."),
        .init(id: "low_02", category: .lowAttendance, variant: "b",
              title: "Red zone · {subject_name}",
              body: "{attendance_percentage}. Climb back with the next {recovery_needed_label}."),
        .init(id: "low_03", category: .lowAttendance, variant: "a",
              title: "{name_comma}{subject_name} needs a talk",
              body: "{attendance_percentage} vs {required_percentage}. Show up like mid-sems matter."),
        .init(id: "low_04", category: .lowAttendance, variant: "b",
              title: "Shortage alert · {attendance_percentage}",
              body: "{subject_name} needs {recovery_needed_label} back. Cheapest fix = next lecture."),
        .init(id: "low_05", category: .lowAttendance, variant: "a",
              title: "Damage control · {subject_name}",
              body: "Need {recovery_needed_label} attended. Log today, then go."),
        .init(id: "low_06", category: .lowAttendance, variant: "b",
              title: "{subject_name} below {required_percentage}",
              body: "You’re at {attendance_percentage}. Open the recovery plan.")
    ]

    // MARK: - Attendance warning

    private static let attendanceWarning: [NotificationTemplate] = [
        .init(id: "warn_01", category: .attendanceWarning, variant: "a",
              title: "{subject_name} on the line · {attendance_percentage}",
              body: "One {skip_verb} changes the story vs {required_percentage}."),
        .init(id: "warn_02", category: .attendanceWarning, variant: "b",
              title: "Barely over {required_percentage}",
              body: "{subject_name} at {attendance_percentage}. Don’t test it today."),
        .init(id: "warn_03", category: .attendanceWarning, variant: "a",
              title: "Tiny margin · {safe_bunks_label}",
              body: "{subject_name} at {attendance_percentage}. Treat the buffer carefully."),
        .init(id: "warn_04", category: .attendanceWarning, variant: "b",
              title: "{subject_name} hugging {required_percentage}",
              body: "{attendance_percentage}. Maybe attend — then log it."),
        .init(id: "warn_05", category: .attendanceWarning, variant: "a",
              title: "Thin buffer on {subject_name}",
              body: "{attendance_percentage} · {safe_bunks_label} left. Log today and don’t push it.")
    ]

    // MARK: - Class reminder

    private static let classReminder: [NotificationTemplate] = [
        .init(id: "class_01", category: .classReminder, variant: "a",
              title: "{classes_today_label} today",
              body: "Your bed is lying. Show up — mark Attend or Missed later."),
        .init(id: "class_02", category: .classReminder, variant: "b",
              title: "Campus day · {classes_today_label}",
              body: "Attendance didn’t take a gap year. Get to class."),
        .init(id: "class_03", category: .classReminder, variant: "a",
              title: "{subject_name} is on today’s list",
              body: "{classes_today_label} total. Soft presence > hard shortage."),
        .init(id: "class_04", category: .classReminder, variant: "b",
              title: "Show-up o’clock · {classes_today_label}",
              body: "Back bench optional. Being marked present isn’t."),
        .init(id: "class_05", category: .classReminder, variant: "a",
              title: "Timetable: {classes_today_label}",
              body: "Snooze isn’t a personality. Mid-sems arrive either way."),
        .init(id: "class_06", category: .classReminder, variant: "b",
              title: "Alarm vs class — {classes_today_label}",
              body: "Class should win. Mark later on Home.")
    ]

    // MARK: - Streak

    private static let streak: [NotificationTemplate] = [
        .init(id: "str_01", category: .streak, variant: "a",
              title: "{streak_days_label} logged in a row",
              body: "{name_comma}consistent. {subject_name} at {attendance_percentage}."),
        .init(id: "str_02", category: .streak, variant: "b",
              title: "Streak: {streak_days_label}",
              body: "You’ve been showing up. Don’t ghost tomorrow."),
        .init(id: "str_03", category: .streak, variant: "a",
              title: "Habit locked · {streak_days_label}",
              body: "{subject_name} at {attendance_percentage}. Keep the bit going."),
        .init(id: "str_04", category: .streak, variant: "b",
              title: "Attendance streak intact",
              body: "{streak_days_label}. Tomorrow is watching — mark on time."),
        .init(id: "str_05", category: .streak, variant: "a",
              title: "{subject_name} looking solid · {attendance_percentage}",
              body: "{streak_days_label} streak. Encore tomorrow.")
    ]
}
