//
//  WidgetSnapshotReader.swift
//  BunkPlannerWidgets
//
//  Reads App Group glance metrics written by the main app.
//

import Foundation

enum WidgetSnapshotReader {
    static let appGroupID = "group.schoolabe.Student-Attendance-Predictor"

    private enum Keys {
        static let percentage = "widget.percentage"
        static let bunksLeft = "widget.bunksLeft"
        static let subjectName = "widget.subjectName"
        static let statusSafe = "widget.statusSafe"
        static let hasData = "widget.hasData"
    }

    private static var suite: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var percentage: Double { suite?.double(forKey: Keys.percentage) ?? 0 }
    static var bunksLeft: Int { suite?.integer(forKey: Keys.bunksLeft) ?? 0 }
    static var subjectName: String { suite?.string(forKey: Keys.subjectName) ?? "Bunk Planner" }
    static var isSafe: Bool { suite?.object(forKey: Keys.statusSafe) as? Bool ?? true }
    static var hasData: Bool { suite?.bool(forKey: Keys.hasData) ?? false }
}
