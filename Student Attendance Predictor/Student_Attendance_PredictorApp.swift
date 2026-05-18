//
//  Student_Attendance_PredictorApp.swift
//  Student Attendance Predictor
//
//  Created by Rohit Srivastava on 02/04/26.
//

import SwiftUI

@main
struct Student_Attendance_PredictorApp: App {
    init() {
        // Begin Core Data store load before the first view needs it.
        _ = PersistenceController.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
