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
        let riskCopy = NotificationPersonalization.apply(
            title: "\(subjectName) at \(String(format: "%.0f", currentPercentage))% — danger zone",
            body: "Tap to plan which lectures you can still skip safely."
        )
        content.title = riskCopy.title
        content.body = riskCopy.body
        content.sound = .default
        content.userInfo = [
            "type": "risk",
            "deep_link": NotificationRoute.skipPlanner.rawValue
        ]

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
        let bufferBody = bunkAllowed > 0
            ? "Only \(bunkAllowed) safe skip\(bunkAllowed == 1 ? "" : "s") left under the line — tap to plan."
            : "At \(String(format: "%.0f", currentPercentage))%. Thin buffer. Tap the recovery path."
        let bufferCopy = NotificationPersonalization.apply(
            title: "\(subjectName): thin buffer · \(String(format: "%.0f", currentPercentage))%",
            body: bufferBody
        )
        content.title = bufferCopy.title
        content.body = bufferCopy.body
        content.sound = .default
        content.userInfo = [
            "type": "low_buffer",
            "deep_link": NotificationRoute.skipPlanner.rawValue
        ]

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
        // Cap in-app immediates — they inflate notif_scheduled and almost never open.
        let defaults = UserDefaults.standard
        let dayKey = NotificationCooldownStore.dayKey(Date())
        let capKey = "notif.immediateDay.\(dayKey)"
        guard defaults.integer(forKey: capKey) < 1 else { return }
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
        defaults.set(1, forKey: capKey)
        AnalyticsService.shared.log(.notificationScheduled(type: "personality_immediate"))
    }

    static func reschedulePersonalityReminders(context: NotificationContext) {
        let center = UNUserNotificationCenter.current()
        let notificationsEnabled = UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool ?? true

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

            guard notificationsEnabled else { return }

            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }

                DispatchQueue.main.async {
                    NotificationCooldownStore.clearReserved()
                    let now = Date()
                    let calendar = Calendar.current
                    _ = scheduleUpcomingEvenings(context: context, now: now, calendar: calendar)
                    _ = scheduleUpcomingMornings(context: context, now: now, calendar: calendar)
                    _ = scheduleNextWeekday(
                        weekday: 2,
                        hour: NotificationPersonalityConfig.mondayHour,
                        slot: .monday,
                        prefix: "personality-monday-",
                        context: context,
                        now: now,
                        calendar: calendar
                    )
                    _ = scheduleNextWeekday(
                        weekday: 6,
                        hour: NotificationPersonalityConfig.fridayHour,
                        slot: .friday,
                        prefix: "personality-friday-",
                        context: context,
                        now: now,
                        calendar: calendar
                    )
                    _ = scheduleWeeklyDigest(context: context, now: now, calendar: calendar)
                }
            }
        }
    }

    /// Day-2 + day-3 local nudges if they installed but never used Mark Today.
    static func scheduleDayTwoMarkNudgeIfNeeded() {
        scheduleEarlyRetentionMarkNudgesIfNeeded()
    }

    /// Install+2 and install+3 evening “mark today” loop — cancel on first mark.
    static func scheduleEarlyRetentionMarkNudgesIfNeeded() {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool ?? true
        let day2ID = "retention-day2-mark"
        let day3ID = "retention-day3-mark"
        let center = UNUserNotificationCenter.current()

        guard notificationsEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [day2ID, day3ID])
            return
        }
        guard AnalyticsService.shared.hasMarkedAtLeastOnce == false else {
            center.removePendingNotificationRequests(withIdentifiers: [day2ID, day3ID])
            return
        }

        let defaults = UserDefaults.standard
        guard let installDate = defaults.object(forKey: "analytics.installDate") as? Date else { return }

        let calendar = Calendar.current
        let now = Date()

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

            for dayOffset in [2, 3] {
                let identifier = dayOffset == 2 ? day2ID : day3ID
                let type = dayOffset == 2 ? "day2_mark" : "day3_mark"
                let loggedKey = "notif.retentionLogged.\(type)"

                guard let fireDay = calendar.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: calendar.startOfDay(for: installDate)
                ) else { continue }

                var fireComponents = calendar.dateComponents([.year, .month, .day], from: fireDay)
                fireComponents.hour = NotificationPersonalityConfig.eveningHour
                fireComponents.minute = 0
                guard let fireDate = calendar.date(from: fireComponents), fireDate > now else {
                    center.removePendingNotificationRequests(withIdentifiers: [identifier])
                    continue
                }

                center.getPendingNotificationRequests { pending in
                    let alreadyPending = pending.contains { $0.identifier == identifier }
                    center.removePendingNotificationRequests(withIdentifiers: [identifier])

                    let content = UNMutableNotificationContent()
                    let copy = NotificationPersonalization.apply(
                        title: dayOffset == 2
                            ? "Day 2: log your first classes"
                            : "Day 3: still haven’t marked?",
                        body: dayOffset == 2
                            ? "Tap Attend or Missed on Home — builds the week before shortage season."
                            : "One tap keeps your % honest. Future-you skips the apology essay."
                    )
                    content.title = copy.title
                    content.body = copy.body
                    content.sound = .default
                    content.userInfo = [
                        "type": type,
                        "deep_link": NotificationRoute.markToday.rawValue
                    ]

                    let trigger = UNCalendarNotificationTrigger(
                        dateMatching: calendar.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: fireDate
                        ),
                        repeats: false
                    )
                    center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))

                    if alreadyPending == false, defaults.bool(forKey: loggedKey) == false {
                        defaults.set(true, forKey: loggedKey)
                        NotificationEngagementStore.recordScheduled()
                        AnalyticsService.shared.log(.notificationScheduled(type: type))
                    }
                }
            }
        }
    }

    static func cancelDayTwoMarkNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                "retention-day2-mark",
                "retention-day3-mark"
            ])
    }

    /// Same-day nudge when the user has data but hasn't marked today (8 PM local).
    static func scheduleEveningMarkNudgeIfNeeded(
        hasMarkedToday: Bool,
        hasSubjects: Bool,
        pendingMarkCount: Int
    ) {
        let center = UNUserNotificationCenter.current()
        let identifier = "retention-evening-mark"
        let notificationsEnabled = UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool ?? true
        guard notificationsEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        guard hasSubjects else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        guard hasMarkedToday == false else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }
        // Still nudge on off-timetable days — empty Mark Today was killing the habit ping.
        guard NotificationEngagementStore.canSendHabitNotification() else { return }

        let calendar = Calendar.current
        let now = Date()
        var fireComponents = calendar.dateComponents([.year, .month, .day], from: now)
        fireComponents.hour = NotificationPersonalityConfig.eveningHour
        fireComponents.minute = 0
        guard let tonight = calendar.date(from: fireComponents) else { return }

        let fireDate: Date
        if tonight > now {
            fireDate = tonight
        } else if calendar.isDateInToday(now) {
            // Missed the 8 PM slot — nudge in 20 minutes while they're still around.
            fireDate = now.addingTimeInterval(20 * 60)
        } else {
            return
        }

        let dayKey = NotificationCooldownStore.dayKey(fireDate, calendar: calendar)
        let loggedKey = "notif.eveningLogged.\(dayKey)"

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

            center.getPendingNotificationRequests { pending in
                let alreadyPending = pending.contains { $0.identifier == identifier }
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
                // One evening habit ping — drop the personality twin for the same night.
                center.removePendingNotificationRequests(
                    withIdentifiers: ["personality-evening-\(dayKey)"]
                )

                let pendingCount = max(0, pendingMarkCount)
                let subjectWord = pendingCount == 1 ? "subject" : "subjects"
                let eveningVariants: [(String, String)]
                if pendingCount > 1 {
                    eveningVariants = [
                        ("\(pendingCount) \(subjectWord) still unmarked", "Tap Attend or Missed before tomorrow’s shortage panic."),
                        ("Evening roll call: \(pendingCount) left", "Log them in 5 seconds — Home → Mark Today."),
                        ("\(pendingCount) classes need a tap", "Fill the gap before mid-sems ask questions.")
                    ]
                } else if pendingCount == 1 {
                    eveningVariants = [
                        ("Mark today’s class", "Tap Attend or Missed before it becomes a mystery."),
                        ("Did you go today?", "One tap on Home. Takes 5 seconds."),
                        ("Log today’s attendance", "Your % stays honest only if you mark it.")
                    ]
                } else {
                    eveningVariants = [
                        ("Log today’s attendance", "No lecture on the timetable? Still mark holiday / off day."),
                        ("Keep the streak honest", "Open Home and tap Attend, Missed, or No class."),
                        ("Quick check-in", "Takes 5 seconds — then you’re done for tonight.")
                    ]
                }
                let pick = eveningVariants[abs(dayKey.hashValue) % eveningVariants.count]
                let eveningCopy = NotificationPersonalization.apply(title: pick.0, body: pick.1)
                let content = UNMutableNotificationContent()
                content.title = eveningCopy.title
                content.body = eveningCopy.body
                content.sound = .default
                content.userInfo = [
                    "type": "evening_mark",
                    "deep_link": NotificationRoute.markToday.rawValue
                ]

                let trigger: UNNotificationTrigger
                if fireDate == tonight, tonight > now {
                    trigger = UNCalendarNotificationTrigger(
                        dateMatching: calendar.dateComponents(
                            [.year, .month, .day, .hour, .minute],
                            from: fireDate
                        ),
                        repeats: false
                    )
                } else {
                    trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: max(60, fireDate.timeIntervalSince(now)),
                        repeats: false
                    )
                }
                center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))

                // Log once per fire day — rebuilds were flooding notif_scheduled.
                if alreadyPending == false, UserDefaults.standard.bool(forKey: loggedKey) == false {
                    UserDefaults.standard.set(true, forKey: loggedKey)
                    NotificationEngagementStore.recordScheduled()
                    AnalyticsService.shared.log(.notificationScheduled(type: "evening_mark"))
                }
            }
        }
    }

    static func cancelEveningMarkNudge() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["retention-evening-mark"])
    }

    static func scheduleHolidayWeekHint() {
        let center = UNUserNotificationCenter.current()
        let identifier = "attendance-holiday-hint"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Holiday week won’t hurt your %"
        content.body = "Mark holidays in Today’s Classes so they don’t count toward shortage."
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
        let recoveryCopy = NotificationPersonalization.apply(
            title: "\(subjectName): need \(recoveryNeeded) attended",
            body: recoveryNeeded == 1
                ? "One class climbs you back. Show up, then log it."
                : "\(recoveryNeeded) classes to climb back. Start with the next one."
        )
        content.title = recoveryCopy.title
        content.body = recoveryCopy.body
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
            let focusCopy = NotificationPersonalization.apply(
                title: "Focus session complete",
                body: "Nice work — take a \(max(1, breakMinutes))-minute break."
            )
            content.title = focusCopy.title
            content.body = focusCopy.body
        } else {
            let breakCopy = NotificationPersonalization.apply(
                title: "Break's over",
                body: "Ready for another focus block?"
            )
            content.title = breakCopy.title
            content.body = breakCopy.body
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

    /// Evening-before (8 PM) and due-morning (9 AM) reminders for the homework list.
    static func rescheduleStudyTaskReminders(tasks: [StudyTask]) {
        let center = UNUserNotificationCenter.current()
        let prefix = "study-task-"
        let notificationsEnabled = UserDefaults.standard.object(forKey: "feature.notificationsEnabled") as? Bool ?? true

        center.getPendingNotificationRequests { pending in
            let stale = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            if stale.isEmpty == false {
                center.removePendingNotificationRequests(withIdentifiers: stale)
            }
            guard notificationsEnabled else { return }

            let calendar = Calendar.current
            let now = Date()

            for task in tasks {
                guard let due = task.dueDate else { continue }
                let dueDay = calendar.startOfDay(for: due)

                if let evening = calendar.date(byAdding: .day, value: -1, to: dueDay) {
                    var eveningParts = calendar.dateComponents([.year, .month, .day], from: evening)
                    eveningParts.hour = 20
                    eveningParts.minute = 0
                    if let fire = calendar.date(from: eveningParts), fire > now {
                        let content = UNMutableNotificationContent()
                        content.title = "\(task.kind.title) tomorrow"
                        content.body = "\(task.title)\(task.subjectName.isEmpty ? "" : " · \(task.subjectName)")"
                        content.sound = .default
                        content.userInfo = [
                            "type": "study_task",
                            "task_id": task.id.uuidString,
                            "deep_link": NotificationRoute.home.rawValue
                        ]
                        let trigger = UNCalendarNotificationTrigger(dateMatching: eveningParts, repeats: false)
                        center.add(
                            UNNotificationRequest(
                                identifier: "\(prefix)\(task.id.uuidString)-eve",
                                content: content,
                                trigger: trigger
                            )
                        )
                        AnalyticsService.shared.log(.notificationScheduled(type: "study_task"))
                    }
                }

                var morningParts = calendar.dateComponents([.year, .month, .day], from: dueDay)
                morningParts.hour = 9
                morningParts.minute = 0
                if let fire = calendar.date(from: morningParts), fire > now {
                    let content = UNMutableNotificationContent()
                    content.title = "\(task.kind.title) today"
                    content.body = "\(task.title)\(task.subjectName.isEmpty ? "" : " · \(task.subjectName)")"
                    content.sound = .default
                    content.userInfo = [
                        "type": "study_task",
                        "task_id": task.id.uuidString,
                        "deep_link": NotificationRoute.home.rawValue
                    ]
                    let trigger = UNCalendarNotificationTrigger(dateMatching: morningParts, repeats: false)
                    center.add(
                        UNNotificationRequest(
                            identifier: "\(prefix)\(task.id.uuidString)-am",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }
        }
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
                        content.title = "\(deadline.kind.title) today · don’t miss class"
                        content.body = "\(deadline.title)\(courseBit). Be ready — and log attendance."
                    case 1:
                        content.title = "\(deadline.kind.title) tomorrow"
                        content.body = "\(deadline.title)\(courseBit). One day left — plan around the timetable."
                    default:
                        content.title = "\(deadline.kind.title) in \(daysBefore) days"
                        content.body = "\(deadline.title)\(courseBit). Don’t \(skipVerb) into shortage season."
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
            || ((UserDefaults.standard.object(forKey: "ads.inviteTrialUntil") as? Date) ?? .distantPast) > Date()
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
        let attended = max(0, context.weeklyAttended)
        let missed = max(0, context.weeklyMissed)
        let digestTitle: String
        let digestBody: String
        if context.atRiskSubjects > 0 {
            let riskLabel = context.atRiskSubjects == 1 ? "1 subject" : "\(context.atRiskSubjects) subjects"
            digestTitle = "Week check: \(riskLabel) at risk"
            digestBody = "Attended \(attended) · missed \(missed). Open Insights before shortage season gets loud."
        } else {
            digestTitle = "Week check: \(attended) attended · \(missed) missed"
            digestBody = "You’re clear of the danger zone. Keep logging — mid-sems don’t wait."
        }
        let digestCopy = NotificationPersonalization.apply(
            title: digestTitle,
            body: digestBody,
            firstName: context.firstName
        )
        content.title = digestCopy.title
        content.body = digestCopy.body
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
        NotificationEngagementStore.recordScheduled()
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
