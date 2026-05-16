//
//  Student_Attendance_PredictorApp.swift
//  Student Attendance Predictor
//
//  Created by Rohit Srivastava on 02/04/26.
//

import SwiftUI

@main
struct Student_Attendance_PredictorApp: App {
    @StateObject private var storeKit = StoreKitManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeKit)
        }
    }
}
