//
//  SharedDataWriter.swift
//  Student Attendance Predictor
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum SharedDataWriter {
    static let groupID = "group.com.schoolabe.attendancepredictor"
    private static let widgetReloadDebounce: TimeInterval = 0.35
    private static var pendingReloadWorkItem: DispatchWorkItem?

    private enum Keys {
        static let subjectID = "widget_subjectID"
        static let subjectName = "widget_subjectName"
        static let attendedClasses = "widget_attendedClasses"
        static let totalClasses = "widget_totalClasses"
        static let requiredPercentage = "widget_requiredPercentage"
        static let lastUpdated = "widget_lastUpdated"
        static let allSubjects = "widget_allSubjects"
    }

    struct SharedSubjectSnapshot: Codable {
        let id: String
        let name: String
        let attendedClasses: Int
        let totalClasses: Int
        let requiredPercentage: Double
    }

    static func write(
        subjectID: UUID,
        subjectName: String,
        attendedClasses: Int,
        totalClasses: Int,
        requiredPercentage: Double
    ) {
        guard let sharedDefaults = UserDefaults(suiteName: groupID) else { return }

        sharedDefaults.set(subjectID.uuidString, forKey: Keys.subjectID)
        sharedDefaults.set(subjectName, forKey: Keys.subjectName)
        sharedDefaults.set(attendedClasses, forKey: Keys.attendedClasses)
        sharedDefaults.set(totalClasses, forKey: Keys.totalClasses)
        sharedDefaults.set(requiredPercentage, forKey: Keys.requiredPercentage)
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)

        scheduleWidgetRefresh()
    }

    static var lastSubjectID: UUID? {
        guard
            let sharedDefaults = UserDefaults(suiteName: groupID),
            let raw = sharedDefaults.string(forKey: Keys.subjectID)
        else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    static func writeAllSubjects(_ subjects: [SharedSubjectSnapshot]) {
        guard let sharedDefaults = UserDefaults(suiteName: groupID) else { return }
        guard let data = try? JSONEncoder().encode(subjects) else { return }

        sharedDefaults.set(data, forKey: Keys.allSubjects)
        scheduleWidgetRefresh()
    }

    private static func scheduleWidgetRefresh() {
        #if canImport(WidgetKit)
        pendingReloadWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            WidgetCenter.shared.reloadAllTimelines()
        }
        pendingReloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + widgetReloadDebounce, execute: workItem)
        #endif
    }
}
