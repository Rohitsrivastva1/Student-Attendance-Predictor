//
//  WidgetSnapshotStore.swift
//  Student Attendance Predictor
//
//  Writes glance metrics to an App Group for Home / Lock Screen widgets.
//

import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let appGroupID = "group.schoolabe.Student-Attendance-Predictor"

    private enum Keys {
        static let percentage = "widget.percentage"
        static let bunksLeft = "widget.bunksLeft"
        static let subjectName = "widget.subjectName"
        static let statusSafe = "widget.statusSafe"
        static let updatedAt = "widget.updatedAt"
        static let hasData = "widget.hasData"
    }

    private static var suite: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func publish(
        percentage: Double,
        bunksLeft: Int,
        subjectName: String,
        isSafe: Bool,
        hasData: Bool
    ) {
        guard let suite else { return }
        suite.set(percentage, forKey: Keys.percentage)
        suite.set(bunksLeft, forKey: Keys.bunksLeft)
        suite.set(subjectName, forKey: Keys.subjectName)
        suite.set(isSafe, forKey: Keys.statusSafe)
        suite.set(hasData, forKey: Keys.hasData)
        suite.set(Date().timeIntervalSince1970, forKey: Keys.updatedAt)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func publish(from subjects: [SubjectSummary], selectedID: UUID?) {
        let selected = subjects.first(where: { $0.id == selectedID }) ?? subjects.first
        guard let selected, selected.totalClasses > 0 else {
            publish(
                percentage: 0,
                bunksLeft: 0,
                subjectName: selected?.name ?? "Bunk Planner",
                isSafe: true,
                hasData: false
            )
            return
        }
        publish(
            percentage: selected.currentPercentage,
            bunksLeft: selected.status == .safe ? selected.bunkAllowed : 0,
            subjectName: selected.name,
            isSafe: selected.status == .safe,
            hasData: true
        )
    }

    // MARK: - Read (also used conceptually by the widget extension)

    static func readPercentage() -> Double {
        suite?.double(forKey: Keys.percentage) ?? 0
    }

    static func readBunksLeft() -> Int {
        suite?.integer(forKey: Keys.bunksLeft) ?? 0
    }

    static func readSubjectName() -> String {
        suite?.string(forKey: Keys.subjectName) ?? "Bunk Planner"
    }

    static func readIsSafe() -> Bool {
        suite?.object(forKey: Keys.statusSafe) as? Bool ?? true
    }

    static func readHasData() -> Bool {
        suite?.bool(forKey: Keys.hasData) ?? false
    }
}
