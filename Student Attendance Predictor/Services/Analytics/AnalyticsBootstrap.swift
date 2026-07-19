//
//  AnalyticsBootstrap.swift
//  Student Attendance Predictor
//
//  Safely configures Firebase at launch. FirebaseApp.configure() crashes if no
//  GoogleService-Info.plist is bundled, so we only configure when the file is
//  actually present. This keeps the app launchable in every configuration:
//  - no Firebase package, no plist  -> nothing happens
//  - package added, plist missing   -> skipped (logged in DEBUG)
//  - package added, plist present   -> Firebase configured, analytics live
//

import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum AnalyticsBootstrap {
    static func configureFirebaseIfAvailable() {
        #if canImport(FirebaseCore)
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            #if DEBUG
            print("[Analytics] Firebase SDK present but GoogleService-Info.plist is missing — skipping configure().")
            #endif
            return
        }
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        #endif
    }
}
