//
//  NotificationEngine.swift
//  Student Attendance Predictor
//
//  Decides *what kind* of notification to send. Templates decide *how to say it*.
//

import Foundation

enum NotificationEngine {
    static func payload(
        for slot: NotificationSlot,
        context: NotificationContext,
        now: Date = Date()
    ) -> PersonalityNotificationPayload? {
        guard let category = category(for: slot, context: context) else { return nil }

        if NotificationCooldownStore.canSend(category: category, slot: slot, now: now) == false {
            if category.priority == .high {
                // Humor must never replace a warning. Cooldown already covered this category.
                return nil
            }
            if slot == .evening || slot == .monday || slot == .friday || slot == .morning,
               let fallback = fallbackCategory(for: slot, context: context, avoiding: category, now: now) {
                return render(category: fallback, slot: slot, context: context)
            }
            return nil
        }

        return render(category: category, slot: slot, context: context)
    }

    static func category(
        for slot: NotificationSlot,
        context: NotificationContext
    ) -> PersonalityNotificationCategory? {
        let witty = NotificationPersonalityConfig.enableWittyCopy

        switch slot {
        case .immediate:
            guard context.hasData else { return nil }
            if context.attendancePercentage < context.requiredPercentage {
                return .lowAttendance
            }
            if context.isCloseToMinimum {
                return .attendanceWarning
            }
            if context.safeBunks > 0, context.safeBunks <= 4 {
                return .bunkAvailable
            }
            return nil

        case .evening:
            if context.hasLoggedToday {
                return context.streakDays >= 2 ? .streak : nil
            }
            if context.hasData == false {
                return witty && NotificationPersonalityConfig.enableCuriosity ? .curiosity : .classReminder
            }
            if context.attendancePercentage < context.requiredPercentage {
                return .lowAttendance
            }
            if context.isCloseToMinimum {
                return savageIfAllowed(default: .bunkNotAvailable, witty: witty)
            }
            if context.trend == .declining, context.safeBunks <= 3 {
                return savageIfAllowed(default: .attendanceWarning, witty: witty)
            }
            if context.safeBunks > 0 {
                return pick([.bunkAvailable, witty && NotificationPersonalityConfig.enableCuriosity ? .curiosity : .bunkAvailable])
            }
            if witty && NotificationPersonalityConfig.enableHumor {
                return pick([.funny, .curiosity])
            }
            return .curiosity

        case .morning:
            guard context.classesToday > 0 else { return nil }
            guard context.hasLoggedToday == false else { return nil }
            guard context.isWeeklyHoliday == false else { return nil }
            return .classReminder

        case .monday:
            if context.hasData == false {
                return witty ? .curiosity : .classReminder
            }
            if context.attendancePercentage < context.requiredPercentage {
                return .lowAttendance
            }
            if context.safeBunks > 0 {
                return .bunkAvailable
            }
            if context.isCloseToMinimum {
                return .bunkNotAvailable
            }
            return witty && NotificationPersonalityConfig.enableHumor ? .funny : .curiosity

        case .friday:
            if context.hasData == false { return .curiosity }
            if context.attendancePercentage < context.requiredPercentage {
                return .lowAttendance
            }
            if context.safeBunks > 0 { return .bunkAvailable }
            return savageIfAllowed(default: .bunkNotAvailable, witty: witty)
        }
    }

    private static func savageIfAllowed(
        default fallback: PersonalityNotificationCategory,
        witty: Bool
    ) -> PersonalityNotificationCategory {
        guard witty, NotificationPersonalityConfig.enableSavageMode else { return fallback }
        return Int.random(in: 0...1) == 0 ? .savage : fallback
    }

    private static func fallbackCategory(
        for slot: NotificationSlot,
        context: NotificationContext,
        avoiding blocked: PersonalityNotificationCategory,
        now: Date
    ) -> PersonalityNotificationCategory? {
        let candidates: [PersonalityNotificationCategory]
        switch slot {
        case .evening:
            candidates = [.curiosity, .funny, .classReminder]
        case .morning:
            candidates = [.classReminder]
        case .monday, .friday:
            candidates = [.curiosity, .funny]
        case .immediate:
            return nil
        }
        return candidates.first {
            $0 != blocked && NotificationCooldownStore.canSend(category: $0, slot: slot, now: now)
        }
    }

    private static func pick(_ categories: [PersonalityNotificationCategory]) -> PersonalityNotificationCategory {
        let unique = Array(Set(categories))
        return unique.randomElement() ?? categories[0]
    }

    private static func render(
        category: PersonalityNotificationCategory,
        slot: NotificationSlot,
        context: NotificationContext
    ) -> PersonalityNotificationPayload {
        let template: NotificationTemplate
        if NotificationPersonalityConfig.enableWittyCopy == false {
            template = NotificationTemplates.plain(slot: slot, context: context)
        } else {
            template = selectTemplate(category: category, slot: slot, context: context)
        }

        let keepEmoji = NotificationPersonalityConfig.enableWittyCopy
            && Double.random(in: 0..<1) < NotificationPersonalityConfig.emojiProbability
        let rendered = NotificationCopyRenderer.renderedCopy(
            title: template.title,
            body: template.body,
            context: context
        )
        let title = NotificationCopyRenderer.maybeStripEmoji(rendered.title, keep: keepEmoji)
        let body = NotificationCopyRenderer.maybeStripEmoji(rendered.body, keep: keepEmoji)

        return PersonalityNotificationPayload(
            category: template.category,
            templateID: template.id,
            variant: template.variant,
            title: title,
            body: body,
            route: template.category.route,
            priority: template.category.priority,
            slot: slot
        )
    }

    private static func selectTemplate(
        category: PersonalityNotificationCategory,
        slot: NotificationSlot,
        context: NotificationContext
    ) -> NotificationTemplate {
        let pool = NotificationTemplates.pool(for: category)
        let recent = NotificationCooldownStore.recentlyUsedTemplateIDs()
        let fresh = pool.filter { recent.contains($0.id) == false }
        let chosen = (fresh.isEmpty ? pool : fresh).randomElement()
            ?? NotificationTemplates.plain(slot: slot, context: context)
        return chosen
    }
}
