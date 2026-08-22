//
//  HomePromoStore.swift
//  Student Attendance Predictor
//
//  Rotates weekly Home promo cards so Tools features surface on the attendance tab.
//

import Foundation

enum HomePromoKind: String, CaseIterable {
    case skipPlanner = "skip_planner"
    case focus
    case export
    case widget

    var icon: String {
        switch self {
        case .skipPlanner: return "calendar.badge.checkmark"
        case .focus: return "brain.head.profile"
        case .export: return "square.and.arrow.up.on.square"
        case .widget: return "platter.filled.top.iphone"
        }
    }

    func title(market: StudentMarket) -> String {
        let skip = market.skipVerb.capitalized
        switch self {
        case .skipPlanner: return "Plan your \(skip)s"
        case .focus: return "Focus after you mark"
        case .export: return "Export for parents"
        case .widget: return "Home Screen widget"
        }
    }

    func subtitle(market: StudentMarket) -> String {
        switch self {
        case .skipPlanner:
            return "Tap a day — see which subjects stay safe."
        case .focus:
            return "25-minute timer linked to your subject."
        case .export:
            return "PDF summary or CSV log — one tap."
        case .widget:
            return "Safe bunks and % at a glance."
        }
    }
}

enum HomePromoStore {
    static func promoForCurrentWeek(date: Date = Date()) -> HomePromoKind {
        let index = isoWeekNumber(date: date) % HomePromoKind.allCases.count
        return HomePromoKind.allCases[index]
    }

    private static func isoWeekNumber(date: Date) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar.component(.weekOfYear, from: date)
    }
}
