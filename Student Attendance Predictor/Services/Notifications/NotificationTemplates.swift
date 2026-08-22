//
//  NotificationTemplates.swift
//  Student Attendance Predictor
//
//  Copy only. The engine decides *whether* to notify and *which category*.
//  Original Bunk Planner voice — college, short, slightly sarcastic.
//

import Foundation

struct NotificationTemplate: Equatable, Identifiable {
    let id: String
    let category: PersonalityNotificationCategory
    let variant: String
    let title: String
    let body: String
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
                    title: "Did you attend today?",
                    body: "Tap to log today's attendance in one tap."
                )
            }
            if context.isSafe {
                if context.safeBunks > 0 {
                    return NotificationTemplate(
                        id: "plain_evening_safe",
                        category: .bunkAvailable,
                        variant: "plain",
                        title: "{subject_name} is at {attendance_percentage}",
                        body: "{safe_bunks} {skip_noun} left. Tap to log today."
                    )
                }
                return NotificationTemplate(
                    id: "plain_evening_line",
                    category: .attendanceWarning,
                    variant: "plain",
                    title: "{subject_name} is at {attendance_percentage}",
                    body: "You're on the line. Log today in one tap."
                )
            }
            return NotificationTemplate(
                id: "plain_evening_risk",
                category: .lowAttendance,
                variant: "plain",
                title: "{subject_name} is at {attendance_percentage}",
                body: "Attend {recovery_needed} more classes to recover. Log today."
            )
        case .morning:
            return NotificationTemplate(
                id: "plain_morning",
                category: .classReminder,
                variant: "plain",
                title: "Classes today",
                body: "{classes_today} on the timetable. Open Log to mark them."
            )
        case .monday:
            return NotificationTemplate(
                id: "plain_monday",
                category: .curiosity,
                variant: "plain",
                title: "New week, keep {subject_name} on track",
                body: "You're at {attendance_percentage}. Log classes as you go."
            )
        case .friday:
            if context.safeBunks > 0 {
                return NotificationTemplate(
                    id: "plain_friday_safe",
                    category: .bunkAvailable,
                    variant: "plain",
                    title: "Weekend check-in",
                    body: "{subject_name} is at {attendance_percentage} — {safe_bunks} {skip_noun} left."
                )
            }
            return NotificationTemplate(
                id: "plain_friday_risk",
                category: .bunkNotAvailable,
                variant: "plain",
                title: "Weekend check-in",
                body: "{subject_name} is at {attendance_percentage}. Think twice before you {skip_verb}."
            )
        case .immediate:
            if context.isSafe == false {
                return NotificationTemplate(
                    id: "plain_immediate_risk",
                    category: .lowAttendance,
                    variant: "plain",
                    title: "{subject_name}: attendance alert",
                    body: "You're at {attendance_percentage}. Attend the next {recovery_needed} classes."
                )
            }
            if context.safeBunks <= 1 {
                return NotificationTemplate(
                    id: "plain_immediate_line",
                    category: .attendanceWarning,
                    variant: "plain",
                    title: "{subject_name}: low buffer",
                    body: "You're at {attendance_percentage} with {safe_bunks} {skip_noun} left."
                )
            }
            return NotificationTemplate(
                id: "plain_immediate_ok",
                category: .bunkAvailable,
                variant: "plain",
                title: "{subject_name} update",
                body: "{safe_bunks} {skip_noun} left at {attendance_percentage}."
            )
        }
    }

    // MARK: - Funny

    private static let funny: [NotificationTemplate] = [
        .init(id: "funny_01", category: .funny, variant: "a",
              title: "Attendance called.",
              body: "It brought a clipboard. {subject_name} is at {attendance_percentage}."),
        .init(id: "funny_02", category: .funny, variant: "b",
              title: "Another lecture.",
              body: "College really thinks showing up is a whole personality."),
        .init(id: "funny_03", category: .funny, variant: "a",
              title: "Present-ish.",
              body: "Your body can go. {subject_name} is counting on it."),
        .init(id: "funny_04", category: .funny, variant: "b",
              title: "Roll number loading…",
              body: "Your attendance plotline continues at {attendance_percentage}."),
        .init(id: "funny_05", category: .funny, variant: "a",
              title: "Campus pinged.",
              body: "{classes_today} classes today. The register still believes in you."),
        .init(id: "funny_06", category: .funny, variant: "b",
              title: "Main-character class.",
              body: "Or extra sleep. {subject_name} is at {attendance_percentage} either way.")
    ]

    // MARK: - Curiosity

    private static let curiosity: [NotificationTemplate] = [
        .init(id: "cur_01", category: .curiosity, variant: "a",
              title: "We ran the numbers.",
              body: "{subject_name} is at {attendance_percentage}. The {skip_noun} math might surprise you."),
        .init(id: "cur_02", category: .curiosity, variant: "b",
              title: "Quick plot check.",
              body: "Your attendance moved. Worth a five-second look."),
        .init(id: "cur_03", category: .curiosity, variant: "a",
              title: "Before you {skip_verb}…",
              body: "{subject_name} is sitting at {attendance_percentage}. Peek at the buffer."),
        .init(id: "cur_04", category: .curiosity, variant: "b",
              title: "Tiny update.",
              body: "Something changed in your {skip_noun} budget."),
        .init(id: "cur_05", category: .curiosity, variant: "a",
              title: "Do the math later?",
              body: "Or see your {skip_noun} in ten seconds. You're at {attendance_percentage}."),
        .init(id: "cur_06", category: .curiosity, variant: "b",
              title: "Interesting…",
              body: "{subject_name} isn't where it was yesterday. Open and confirm.")
    ]

    // MARK: - Savage (teasing, never insulting)

    private static let savage: [NotificationTemplate] = [
        .init(id: "sav_01", category: .savage, variant: "a",
              title: "Bold calendar.",
              body: "{subject_name} is at {attendance_percentage}. The register has questions."),
        .init(id: "sav_02", category: .savage, variant: "b",
              title: "{required_percentage} called.",
              body: "It would like a word about your recent seating choices."),
        .init(id: "sav_03", category: .savage, variant: "a",
              title: "One more {skip_verb}?",
              body: "Your attendance manager is already sweating."),
        .init(id: "sav_04", category: .savage, variant: "b",
              title: "Interesting strategy.",
              body: "Missing class like it's extra credit. It isn't."),
        .init(id: "sav_05", category: .savage, variant: "a",
              title: "The register remembers.",
              body: "{subject_name} hasn't forgotten the empty chair.")
    ]

    // MARK: - Bunk available (only when calculation says bunks > 0)

    private static let bunkAvailable: [NotificationTemplate] = [
        .init(id: "bunk_av_01", category: .bunkAvailable, variant: "a",
              title: "Buffer unlocked.",
              body: "You've got {safe_bunks} {skip_noun} in the bank. 👀"),
        .init(id: "bunk_av_02", category: .bunkAvailable, variant: "b",
              title: "You have options.",
              body: "{subject_name} is at {attendance_percentage} with room to breathe."),
        .init(id: "bunk_av_03", category: .bunkAvailable, variant: "a",
              title: "Strategic absence?",
              body: "The numbers say {safe_bunks} {skip_noun} wouldn't sink you."),
        .init(id: "bunk_av_04", category: .bunkAvailable, variant: "b",
              title: "Breathing room.",
              body: "{safe_bunks} {skip_noun} left before {subject_name} gets spicy."),
        .init(id: "bunk_av_05", category: .bunkAvailable, variant: "a",
              title: "Green light-ish.",
              body: "Attendance can survive a little rebellion. {safe_bunks} left."),
        .init(id: "bunk_av_06", category: .bunkAvailable, variant: "b",
              title: "{skip_verb_title} budget: {safe_bunks}",
              body: "{subject_name} is at {attendance_percentage}. Spend them like an adult.")
    ]

    // MARK: - Bunk not available

    private static let bunkNotAvailable: [NotificationTemplate] = [
        .init(id: "bunk_no_01", category: .bunkNotAvailable, variant: "a",
              title: "Maybe don't.",
              body: "{subject_name} is at {attendance_percentage}. Thin ice energy."),
        .init(id: "bunk_no_02", category: .bunkNotAvailable, variant: "b",
              title: "{skip_verb_title} denied.",
              body: "Your attendance just filed a polite complaint."),
        .init(id: "bunk_no_03", category: .bunkNotAvailable, variant: "a",
              title: "Not today.",
              body: "That {skip_verb} could dent {subject_name} for real."),
        .init(id: "bunk_no_04", category: .bunkNotAvailable, variant: "b",
              title: "Hold up.",
              body: "You're at {attendance_percentage}. {required_percentage} is a rule, not a vibe."),
        .init(id: "bunk_no_05", category: .bunkNotAvailable, variant: "a",
              title: "Sit this one out.",
              body: "Zero spare {skip_noun}. Today's class is the play.")
    ]

    // MARK: - Low attendance (below required)

    private static let lowAttendance: [NotificationTemplate] = [
        .init(id: "low_01", category: .lowAttendance, variant: "a",
              title: "We need to talk.",
              body: "You're at {attendance_percentage}. {required_percentage} isn't going to chase itself."),
        .init(id: "low_02", category: .lowAttendance, variant: "b",
              title: "Red zone.",
              body: "{subject_name} needs {recovery_needed} classes back. Today counts."),
        .init(id: "low_03", category: .lowAttendance, variant: "a",
              title: "Tiny problem.",
              body: "Attendance is below {required_percentage}. Future-you is already annoyed."),
        .init(id: "low_04", category: .lowAttendance, variant: "b",
              title: "This is not a drill.",
              body: "{subject_name} is at {attendance_percentage}. Show up like you mean it."),
        .init(id: "low_05", category: .lowAttendance, variant: "a",
              title: "Damage control.",
              body: "Need {recovery_needed} attended classes. Start with the next one."),
        .init(id: "low_06", category: .lowAttendance, variant: "b",
              title: "Attendance emergency.",
              body: "You're at {attendance_percentage}. The next class is the cheapest fix.")
    ]

    // MARK: - Close to the line

    private static let attendanceWarning: [NotificationTemplate] = [
        .init(id: "warn_01", category: .attendanceWarning, variant: "a",
              title: "On the line.",
              body: "{subject_name} is at {attendance_percentage}. One {skip_verb} changes the story."),
        .init(id: "warn_02", category: .attendanceWarning, variant: "b",
              title: "Close-call energy.",
              body: "You're barely over {required_percentage}. Don't test it today."),
        .init(id: "warn_03", category: .attendanceWarning, variant: "a",
              title: "Margin: tiny.",
              body: "{safe_bunks} {skip_noun} left. Treat them like gold."),
        .init(id: "warn_04", category: .attendanceWarning, variant: "b",
              title: "Almost spicy.",
              body: "{subject_name} is hugging {required_percentage}. Maybe attend.")
    ]

    // MARK: - Class reminder (no fake clock times — timetable has counts, not hours)

    private static let classReminder: [NotificationTemplate] = [
        .init(id: "class_01", category: .classReminder, variant: "a",
              title: "The register awaits.",
              body: "{classes_today} classes today. Your bed is a gifted liar."),
        .init(id: "class_02", category: .classReminder, variant: "b",
              title: "Campus loading…",
              body: "You've got {classes_today} on the timetable. Attendance still exists."),
        .init(id: "class_03", category: .classReminder, variant: "a",
              title: "Morning briefing.",
              body: "{classes_today} classes. The clipboard era continues."),
        .init(id: "class_04", category: .classReminder, variant: "b",
              title: "Show-up o'clock.",
              body: "{subject_name} is on today's list. Make it count."),
        .init(id: "class_05", category: .classReminder, variant: "a",
              title: "Timetable says hi.",
              body: "{classes_today} classes today. Pick the main-character arc.")
    ]

    // MARK: - Streak / positive

    private static let streak: [NotificationTemplate] = [
        .init(id: "str_01", category: .streak, variant: "a",
              title: "Look who's consistent.",
              body: "{streak_days}-day streak. We barely recognize this version of you."),
        .init(id: "str_02", category: .streak, variant: "b",
              title: "Character development.",
              body: "You've been showing up. {subject_name} is at {attendance_percentage}."),
        .init(id: "str_03", category: .streak, variant: "a",
              title: "Plot twist.",
              body: "You're becoming the student who actually logs class."),
        .init(id: "str_04", category: .streak, variant: "b",
              title: "Streak intact.",
              body: "{streak_days} days in a row. Don't let tomorrow break it."),
        .init(id: "str_05", category: .streak, variant: "a",
              title: "Main-character arc.",
              body: "Attendance looking sharp at {attendance_percentage}. Keep going.")
    ]
}
