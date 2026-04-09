//
//  WidgetSnapshotStore.swift
//  Student Attendance Predictor
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetSnapshot: Codable {
    let subjectName: String
    let currentPercentage: Double
    let requiredPercentage: Double
    let updatedAt: Date
}

enum WidgetSnapshotStore {
    // Shared App Group used by app + widget extension.
    static let appGroupID = "group.com.schoolabe.attendancepredictor"
    private static let snapshotKey = "widget.latestSnapshot"
    private static let widgetReloadDebounce: TimeInterval = 0.35
    private static var pendingReloadWorkItem: DispatchWorkItem?

    static func save(_ snapshot: WidgetSnapshot) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(snapshot) else { return }

        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            sharedDefaults.set(data, forKey: snapshotKey)
        } else {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }

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
