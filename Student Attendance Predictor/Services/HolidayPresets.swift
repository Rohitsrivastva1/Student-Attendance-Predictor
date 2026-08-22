//
//  HolidayPresets.swift
//  Student Attendance Predictor
//
//  One-tap holiday / break presets for forecast “College Holidays” count.
//

import Foundation

struct HolidayPreset: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let cancelledClasses: Int
    let markets: [StudentMarket]
}

enum HolidayPresets {
    static func options(for market: StudentMarket) -> [HolidayPreset] {
        all.filter { $0.markets.contains(market) }
    }

    private static let all: [HolidayPreset] = [
        HolidayPreset(
            id: "diwali_week",
            title: "Diwali week",
            subtitle: "~1 week off",
            cancelledClasses: 5,
            markets: [.india]
        ),
        HolidayPreset(
            id: "winter_break_in",
            title: "Winter break",
            subtitle: "~2 weeks",
            cancelledClasses: 10,
            markets: [.india]
        ),
        HolidayPreset(
            id: "summer_break_in",
            title: "Summer break",
            subtitle: "Long vacation",
            cancelledClasses: 20,
            markets: [.india]
        ),
        HolidayPreset(
            id: "thanksgiving",
            title: "Thanksgiving",
            subtitle: "Short break",
            cancelledClasses: 3,
            markets: [.unitedStates]
        ),
        HolidayPreset(
            id: "winter_break_us",
            title: "Winter break",
            subtitle: "~2 weeks",
            cancelledClasses: 10,
            markets: [.unitedStates, .other]
        ),
        HolidayPreset(
            id: "spring_break",
            title: "Spring break",
            subtitle: "~1 week",
            cancelledClasses: 5,
            markets: [.unitedStates, .other]
        ),
        HolidayPreset(
            id: "easter_uk",
            title: "Easter break",
            subtitle: "~1 week",
            cancelledClasses: 5,
            markets: [.unitedKingdom]
        ),
        HolidayPreset(
            id: "christmas_uk",
            title: "Christmas break",
            subtitle: "~2 weeks",
            cancelledClasses: 10,
            markets: [.unitedKingdom]
        ),
        HolidayPreset(
            id: "reading_week",
            title: "Reading week",
            subtitle: "No lectures",
            cancelledClasses: 4,
            markets: [.unitedKingdom, .unitedStates, .other]
        )
    ]
}
