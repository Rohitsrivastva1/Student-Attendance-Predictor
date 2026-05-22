//
//  AdMobConfiguration.swift
//  Student Attendance Predictor
//

import Foundation

enum AdMobConfiguration {
    /// Bunk Planner: Attendance Track — production app ID.
    static let applicationID = "ca-app-pub-6782814088719675~7481844312"

    /// Native advanced (production).
    static let nativeAdUnitID = "ca-app-pub-6782814088719675/1693579987"

    #if DEBUG
    /// Google test units — use while developing to avoid invalid traffic.
    static let usesTestAds = true
    static let resolvedNativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"
    #else
    static let usesTestAds = false
    static let resolvedNativeAdUnitID = nativeAdUnitID
    #endif
}
