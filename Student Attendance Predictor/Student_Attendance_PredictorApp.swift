//
//  Student_Attendance_PredictorApp.swift
//  Student Attendance Predictor
//
//  Created by Rohit Srivastava on 02/04/26.
//

import SwiftUI

@main
struct Student_Attendance_PredictorApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Capture launch time as early as possible.
        _ = AppLaunchClock.start

        // Configure analytics (Firebase if available) before anything is logged.
        AnalyticsBootstrap.configureFirebaseIfAvailable()
        AnalyticsService.shared.start()
        NotificationAnalyticsDelegate.shared.register()
        ProPurchaseService.shared.start()

        // Begin Core Data store load before the first view needs it.
        _ = PersistenceController.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .trackScenePhase(scenePhase)
        }
    }
}
