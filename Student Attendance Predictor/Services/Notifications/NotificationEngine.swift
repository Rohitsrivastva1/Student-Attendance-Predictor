//
//  NotificationEngine.swift
//  Student Attendance Predictor
//
//  Decides *what kind* of notification to send. Templates decide *how to say it*.
//  Categories are gated by real attendance thresholds so copy never contradicts the numbers.
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
            if context.hasRealBunkBuffer {
                return .bunkAvailable
            }
            return nil

        case .evening:
            if context.hasLoggedToday {
                return context.streakDays >= 2 ? .streak : nil
            }
            if context.hasData == false {
                return witty && NotificationPersonalityConfig.enableHumor ? .funny : .classReminder
            }
            // Below the line — supportive only. Never savage / bunk-available / “you can skip.”
            if context.attendancePercentage < context.requiredPercentage {
                return .lowAttendance
            }
            if context.isCloseToMinimum || context.safeBunks <= 1 {
                return .attendanceWarning
            }
            if context.hasRealBunkBuffer {
                if shouldOfferSavage(context: context, witty: witty) {
                    return .savage
                }
                var options: [PersonalityNotificationCategory] = [.bunkAvailable]
                if witty && NotificationPersonalityConfig.enableHumor {
                    options.append(.funny)
                }
                if witty,
                   NotificationPersonalityConfig.enableCuriosity,
                   context.attendanceMovedRecently {
                    options.append(.curiosity)
                }
                return pick(options)
            }
            if witty && NotificationPersonalityConfig.enableHumor {
                return .funny
            }
            return .classReminder

        case .morning:
            guard context.classesToday > 0 else { return nil }
            guard context.hasLoggedToday == false else { return nil }
            guard context.isWeeklyHoliday == false else { return nil }
            return .classReminder

        case .monday:
            if context.hasData == false {
                return witty ? .funny : .classReminder
            }
            if context.attendancePercentage < context.requiredPercentage {
                return .lowAttendance
            }
            if context.hasRealBunkBuffer {
                return .bunkAvailable
            }
            if context.isCloseToMinimum {
                return .bunkNotAvailable
            }
            return witty && NotificationPersonalityConfig.enableHumor ? .funny : .curiosity

        case .friday:
            if context.hasData == false { return .funny }
            if context.attendancePercentage < context.requiredPercentage {
                return .lowAttendance
            }
            if context.hasRealBunkBuffer {
                if shouldOfferSavage(context: context, witty: witty) {
                    return .savage
                }
                return .bunkAvailable
            }
            if context.isCloseToMinimum {
                return .bunkNotAvailable
            }
            return .funny
        }
    }

    /// Savage is opt-in and only when the student has real spare bunks (not stressed / below line).
    private static func shouldOfferSavage(context: NotificationContext, witty: Bool) -> Bool {
        guard witty, NotificationPersonalityConfig.enableSavageMode else { return false }
        guard context.hasRealBunkBuffer else { return false }
        guard context.attendancePercentage >= context.requiredPercentage else { return false }
        return Int.random(in: 0...3) == 0
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
            if context.attendancePercentage < context.requiredPercentage {
                candidates = [.lowAttendance]
            } else if context.isCloseToMinimum {
                candidates = [.attendanceWarning, .funny]
            } else if context.hasRealBunkBuffer {
                candidates = [.bunkAvailable, .funny, .classReminder]
            } else {
                candidates = [.funny, .classReminder]
            }
        case .morning:
            candidates = [.classReminder]
        case .monday, .friday:
            candidates = [.funny, .curiosity, .bunkAvailable].filter { cat in
                if cat == .bunkAvailable { return context.hasRealBunkBuffer }
                return true
            }
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
        var pool = NotificationTemplates.pool(for: category).filter { template in
            if template.requiresRealBunkBuffer, context.hasRealBunkBuffer == false {
                return false
            }
            if template.requiresAttendanceMove, context.attendanceMovedRecently == false {
                return false
            }
            return true
        }
        if pool.isEmpty {
            pool = NotificationTemplates.pool(for: category).filter {
                $0.requiresAttendanceMove == false && $0.requiresRealBunkBuffer == false
            }
        }
        let recent = NotificationCooldownStore.recentlyUsedTemplateIDs()
        let fresh = pool.filter { recent.contains($0.id) == false }
        return (fresh.isEmpty ? pool : fresh).randomElement()
            ?? NotificationTemplates.plain(slot: slot, context: context)
    }
}
