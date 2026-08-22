//
//  NotificationService.swift
//  Student Attendance Predictor
//

import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                AnalyticsService.shared.log(.notificationPermissionResult(granted: granted))
            }
        }
    }

    static func scheduleRiskAlert(
        subjectName: String,
        currentPercentage: Double,
        recoveryNeeded: Int
    ) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-risk-\(subjectName.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard recoveryNeeded > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subjectName): Attendance Alert"
        content.body = "Your attendance is \(String(format: "%.1f", currentPercentage))% — attend next \(recoveryNeeded) classes."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "risk"))
    }

    static func scheduleLowBufferAlert(
        subjectName: String,
        currentPercentage: Double,
        bunkAllowed: Int
    ) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-buffer-\(subjectName.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard bunkAllowed <= 2 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subjectName): Low Attendance Buffer"
        content.body = bunkAllowed > 0
            ? "You can safely skip \(bunkAllowed) class\(bunkAllowed == 1 ? "" : "es") next week — stay mindful."
            : "Current attendance is \(String(format: "%.1f", currentPercentage))%. You can miss only \(max(0, bunkAllowed)) more classes safely."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "low_buffer"))
    }

    /// Evening / weekly habit reminders — personality copy, next few occurrences.
    static func registerPersonalityCategory() {
        let category = UNNotificationCategory(
            identifier: NotificationPersonalityConfig.categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func scheduleImmediatePersonalityAlert(context: NotificationContext) {
        guard let payload = NotificationEngine.payload(for: .immediate, context: context) else { return }
        let identifier = "personality-immediate"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        addPersonalityRequest(
            identifier: identifier,
            payload: payload,
            trigger: trigger,
            fireDate: Date().addingTimeInterval(3),
            reserved: false,
            context: context
        )
        AnalyticsService.shared.log(.notificationScheduled(type: "personality_immediate"))
    }

    static func reschedulePersonalityReminders(context: NotificationContext) {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()

        center.getPendingNotificationRequests { pending in
            let stale = pending
                .map(\.identifier)
                .filter { identifier in
                    identifier.hasPrefix("personality-evening-")
                        || identifier.hasPrefix("personality-morning-")
                        || identifier.hasPrefix("personality-monday-")
                        || identifier.hasPrefix("personality-friday-")
                        || identifier == "attendance-class-reminder-daily"
                        || identifier == "attendance-monday-kickoff"
                        || identifier == "attendance-friday-buffer"
                        || identifier == "pro-weekly-digest"
                }
            if stale.isEmpty == false {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }

            NotificationCooldownStore.clearReserved(now: now, calendar: calendar)

            let evenings = scheduleUpcomingEvenings(context: context, now: now, calendar: calendar)
            let mornings = scheduleUpcomingMornings(context: context, now: now, calendar: calendar)
            let monday = scheduleNextWeekday(
                weekday: 2,
                hour: NotificationPersonalityConfig.mondayHour,
                slot: .monday,
                prefix: "personality-monday-",
                context: context,
                now: now,
                calendar: calendar
            )
            let friday = scheduleNextWeekday(
                weekday: 6,
                hour: NotificationPersonalityConfig.fridayHour,
                slot: .friday,
                prefix: "personality-friday-",
                context: context,
                now: now,
                calendar: calendar
            )
            let digest = scheduleWeeklyDigest(context: context, now: now, calendar: calendar)
            if evenings + mornings + monday + friday + digest > 0 {
                AnalyticsService.shared.log(.notificationScheduled(type: "personality"))
            }
        }
    }

    /// Day-2 local nudge if the user installed but never used Mark Today.
    static func scheduleDayTwoMarkNudgeIfNeeded() {
        let center = UNUserNotificationCenter.current()
        let identifier = "retention-day2-mark"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let notificationsEnabled = UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool ?? true
        guard notificationsEnabled else { return }
        guard AnalyticsService.shared.hasMarkedAtLeastOnce == false else { return }

        let defaults = UserDefaults.standard
        guard let installDate = defaults.object(forKey: "analytics.installDate") as? Date else { return }

        let calendar = Calendar.current
        let days = AnalyticsService.shared.daysSinceInstall
        guard days >= 1, days <= 4 else { return }

        var fireComponents = calendar.dateComponents([.year, .month, .day], from: installDate)
        fireComponents.day = (fireComponents.day ?? 0) + 2
        fireComponents.hour = NotificationPersonalityConfig.eveningHour
        fireComponents.minute = 0

        guard let fireDate = calendar.date(from: fireComponents), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Haven't logged today yet?"
        content.body = "Open Bunk Planner and mark today's class in one tap."
        content.sound = .default
        content.userInfo = [
            "type": "day2_mark",
            "deep_link": NotificationRoute.markToday.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "day2_mark"))
    }

    static func cancelDayTwoMarkNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["retention-day2-mark"])
    }

    static func scheduleHolidayWeekHint() {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-holiday-hint"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Holiday week won't affect your attendance"
        content.body = "Mark holidays in Today's Classes so they don't count against you."
        content.sound = .default

        // Soft nudge ~36h after scheduling (used opportunistically).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 36, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "holiday_hint"))
    }

    static func scheduleRecoveryDeadlineAlert(subjectName: String, recoveryNeeded: Int) {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-deadline-\(subjectName.lowercased())"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard recoveryNeeded > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(subjectName): Recovery Deadline"
        content.body = "Plan a recovery streak. You still need \(recoveryNeeded) attended classes to get back on track."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 8, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "recovery_deadline"))
    }

    static func scheduleFocusTimerEnd(afterSeconds: Int, phase: String, breakMinutes: Int = 5) {
        let center = UNUserNotificationCenter.current()
        let identifier = "focus-timer-segment-end"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let seconds = max(1, afterSeconds)
        let content = UNMutableNotificationContent()
        if phase == "focus" {
            content.title = "Focus session complete"
            content.body = "Nice work — take a \(max(1, breakMinutes))-minute break."
        } else {
            content.title = "Break's over"
            content.body = "Ready for another focus block?"
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "focus_timer"))
    }

    static func cancelFocusTimerNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["focus-timer-segment-end"])
    }

    /// Clears and re-schedules local reminders for exams/assignments at T-7, T-3, T-1, and due-day morning.
    static func rescheduleDeadlineReminders(deadlines: [AcademicDeadline]) {
        let center = UNUserNotificationCenter.current()
        let prefix = "academic-deadline-"
        let skipVerb = "miss" // Neutral copy; avoids MainActor market lookup in notification callback.
        let notificationsEnabled = UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool ?? true

        center.getPendingNotificationRequests { pending in
            let stale = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            if stale.isEmpty == false {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }

            guard notificationsEnabled else { return }

            let offsets = [7, 3, 1, 0]
            let calendar = Calendar.current
            let now = Date()

            for deadline in deadlines where deadline.daysRemaining >= 0 {
                for daysBefore in offsets {
                    guard let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: deadline.dueDate)) else {
                        continue
                    }
                    var components = calendar.dateComponents([.year, .month, .day], from: fireDay)
                    components.hour = 9
                    components.minute = 0

                    guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

                    let content = UNMutableNotificationContent()
                    let courseBit = deadline.courseName.isEmpty ? "" : " · \(deadline.courseName)"
                    switch daysBefore {
                    case 0:
                        content.title = "\(deadline.kind.title) today"
                        content.body = "\(deadline.title)\(courseBit). Don't \(skipVerb) class — be ready."
                    case 1:
                        content.title = "\(deadline.kind.title) tomorrow"
                        content.body = "\(deadline.title)\(courseBit). One day left."
                    default:
                        content.title = "\(deadline.kind.title) in \(daysBefore) days"
                        content.body = "\(deadline.title)\(courseBit). Plan your attendance around it."
                    }
                    content.sound = .default
                    content.userInfo = ["type": "academic_deadline", "deadline_id": deadline.id.uuidString]

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let identifier = "\(prefix)\(deadline.id.uuidString)-\(daysBefore)"
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                    center.add(request)
                    AnalyticsService.shared.log(.notificationScheduled(type: "academic_deadline"))
                }
            }
        }
    }

    @discardableResult
    private static func scheduleWeeklyDigest(
        context: NotificationContext,
        now: Date,
        calendar: Calendar
    ) -> Int {
        let isPro = UserDefaults.standard.bool(forKey: "iap.isPro")
        let notificationsEnabled = UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool ?? true
        guard isPro, notificationsEnabled, context.hasData else { return 0 }

        var components = DateComponents()
        components.weekday = 1
        components.hour = NotificationPersonalityConfig.weeklyDigestHour
        components.minute = 0
        guard let fireDate = calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        ) else { return 0 }

        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let content = UNMutableNotificationContent()
        content.title = "Your week in attendance"
        let attended = max(0, context.weeklyAttended)
        let missed = max(0, context.weeklyMissed)
        if context.atRiskSubjects > 0 {
            content.body = "Attended \(attended) · missed \(missed). \(context.atRiskSubjects) subject\(context.atRiskSubjects == 1 ? "" : "s") still need recovery."
        } else {
            content.body = "Attended \(attended) · missed \(missed). You're in a good place — keep the streak."
        }
        content.sound = .default
        content.userInfo = [
            "type": "weekly_digest",
            "deep_link": NotificationRoute.insights.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: "pro-weekly-digest",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
        AnalyticsService.shared.log(.notificationScheduled(type: "weekly_digest"))
        return 1
    }

    @discardableResult
    private static func scheduleUpcomingEvenings(
        context: NotificationContext,
        now: Date,
        calendar: Calendar
    ) -> Int {
        var daysAdded = 0
        var offset = 0
        while daysAdded < NotificationPersonalityConfig.upcomingEveningCount, offset < 10 {
            defer { offset += 1 }
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else {
                continue
            }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = NotificationPersonalityConfig.eveningHour
            components.minute = 0
            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            if offset == 0, context.hasLoggedToday {
                continue
            }
            guard let payload = NotificationEngine.payload(for: .evening, context: context) else { continue }

            let key = NotificationCooldownStore.dayKey(day, calendar: calendar)
            addPersonalityRequest(
                identifier: "personality-evening-\(key)",
                payload: payload,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
                fireDate: fireDate,
                reserved: true,
                context: context
            )
            daysAdded += 1
        }
        return daysAdded
    }

    @discardableResult
    private static func scheduleUpcomingMornings(
        context: NotificationContext,
        now: Date,
        calendar: Calendar
    ) -> Int {
        var daysAdded = 0
        var offset = 0
        while daysAdded < NotificationPersonalityConfig.upcomingMorningCount, offset < 12 {
            defer { offset += 1 }
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) else {
                continue
            }
            if AttendanceCalendar.isWeeklyHoliday(day, calendar: calendar) { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = NotificationPersonalityConfig.morningHour
            components.minute = 0
            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            var slotContext = context
            slotContext.isWeekend = calendar.isDateInWeekend(day)
            slotContext.isWeeklyHoliday = AttendanceCalendar.isWeeklyHoliday(day, calendar: calendar)
            slotContext.classesToday = context.classes(on: day, calendar: calendar)
            slotContext.hasLoggedToday = offset == 0 && context.hasLoggedToday
            guard slotContext.classesToday > 0 else { continue }
            guard let payload = NotificationEngine.payload(for: .morning, context: slotContext) else { continue }

            let key = NotificationCooldownStore.dayKey(day, calendar: calendar)
            addPersonalityRequest(
                identifier: "personality-morning-\(key)",
                payload: payload,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
                fireDate: fireDate,
                reserved: true,
                context: slotContext
            )
            daysAdded += 1
        }
        return daysAdded
    }

    @discardableResult
    private static func scheduleNextWeekday(
        weekday: Int,
        hour: Int,
        slot: NotificationSlot,
        prefix: String,
        context: NotificationContext,
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard let fireDate = nextDate(weekday: weekday, hour: hour, now: now, calendar: calendar) else { return 0 }
        guard let payload = NotificationEngine.payload(for: slot, context: context) else { return 0 }
        let key = NotificationCooldownStore.dayKey(fireDate, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        addPersonalityRequest(
            identifier: "\(prefix)\(key)",
            payload: payload,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false),
            fireDate: fireDate,
            reserved: true,
            context: context
        )
        return 1
    }

    private static func nextDate(weekday: Int, hour: Int, now: Date, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        )
    }

    private static func addPersonalityRequest(
        identifier: String,
        payload: PersonalityNotificationPayload,
        trigger: UNNotificationTrigger,
        fireDate: Date,
        reserved: Bool,
        context: NotificationContext
    ) {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.categoryIdentifier = NotificationPersonalityConfig.categoryIdentifier
        content.threadIdentifier = "bunk-planner-attendance"
        var info = payload.userInfo
        info["attendance_pct"] = context.roundedPercent
        info["safe_bunks"] = context.safeBunks
        content.userInfo = info

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        NotificationCooldownStore.record(payload: payload, on: fireDate, reserved: reserved)
        // Reserved habit slots are rebuilt often — log only immediate sends.
        guard reserved == false else { return }
        AnalyticsService.shared.log(
            .personalityNotificationScheduled(
                category: payload.category.rawValue,
                templateID: payload.templateID,
                variant: payload.variant,
                slot: payload.slot.rawValue,
                attendancePct: context.roundedPercent,
                safeBunks: context.safeBunks
            )
        )
    }
}
