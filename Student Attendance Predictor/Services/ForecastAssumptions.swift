//
//  ForecastAssumptions.swift
//  Student Attendance Predictor
//
//  Persisted holiday / planned-bunk / fallback classes-per-week used by
//  Insights forecast and Home “classes left” so both stay in sync.
//

import Foundation

enum ForecastAssumptions {
    private enum Keys {
        static let holidays = "forecast.holidayClassCount"
        static let plannedBunks = "forecast.plannedBunks"
        static let fallbackClassesPerWeek = "forecast.fallbackClassesPerWeek"
    }

    private static let defaults = UserDefaults.standard

    static var holidayClassCount: Int {
        get { min(max(defaults.object(forKey: Keys.holidays) as? Int ?? 0, 0), 80) }
        set { defaults.set(min(max(newValue, 0), 80), forKey: Keys.holidays) }
    }

    static var plannedBunks: Int {
        get { min(max(defaults.object(forKey: Keys.plannedBunks) as? Int ?? 0, 0), 80) }
        set { defaults.set(min(max(newValue, 0), 80), forKey: Keys.plannedBunks) }
    }

    static var fallbackClassesPerWeek: Int {
        get { min(max(defaults.object(forKey: Keys.fallbackClassesPerWeek) as? Int ?? 5, 0), 40) }
        set { defaults.set(min(max(newValue, 0), 40), forKey: Keys.fallbackClassesPerWeek) }
    }
}
