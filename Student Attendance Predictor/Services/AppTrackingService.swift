//
//  AppTrackingService.swift
//  Student Attendance Predictor
//
//  App Tracking Transparency (ATT) — must complete before any ad SDK initializes.
//

import Foundation
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Result of the system ATT prompt (or current status if already decided).
enum TrackingAuthorization: Sendable, Equatable {
    /// User allowed tracking; IDFA may be used for personalized ads.
    case authorized
    /// User denied tracking; use contextual (non‑personalized) ads only.
    case denied
    /// Tracking restricted by device policy (e.g. parental controls).
    case restricted
    /// Prompt not shown yet (transient until `requestTrackingPermission()` finishes).
    case notDetermined
}

@MainActor
enum AppTrackingService {
    private(set) static var authorization: TrackingAuthorization = .notDetermined

    /// Whether ad requests may use IDFA for personalization.
    static var allowsPersonalizedAds: Bool {
        authorization == .authorized
    }

    /// Requests ATT once the root UI is on-screen, then returns the resolved status.
    static func requestTrackingPermission(
        delay: TimeInterval = 0.75,
        completion: @escaping (TrackingAuthorization) -> Void
    ) {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            let current = ATTrackingManager.trackingAuthorizationStatus
            switch current {
            case .notDetermined:
                authorization = .notDetermined
                logStatus(.notDetermined)
                requestWhenApplicationIsActive(after: delay, completion: completion)
            case .authorized, .denied, .restricted:
                let resolvedStatus = map(current)
                authorization = resolvedStatus
                logStatus(resolvedStatus)
                completion(resolvedStatus)
            @unknown default:
                authorization = .denied
                logStatus(.denied)
                completion(.denied)
            }
            return
        }
        #endif

        // Pre-iOS 14: no ATT API; treat as authorized for ad configuration only.
        authorization = .authorized
        logStatus(.authorized)
        completion(.authorized)
    }

    #if canImport(AppTrackingTransparency)
    @available(iOS 14, *)
    private static func map(_ status: ATTrackingManager.AuthorizationStatus) -> TrackingAuthorization {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }
    #endif

    #if canImport(AppTrackingTransparency) && canImport(UIKit)
    @available(iOS 14, *)
    private static func requestWhenApplicationIsActive(
        after delay: TimeInterval,
        completion: @escaping (TrackingAuthorization) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard UIApplication.shared.applicationState == .active else {
                requestWhenApplicationIsActive(after: 0.25, completion: completion)
                return
            }

            ATTrackingManager.requestTrackingAuthorization { status in
                Task { @MainActor in
                    let resolvedStatus = map(status)
                    authorization = resolvedStatus
                    logStatus(resolvedStatus)
                    completion(resolvedStatus)
                }
            }
        }
    }
    #endif

    private static func logStatus(_ status: TrackingAuthorization) {
        switch status {
        case .authorized:
            print("[ATT] Status: authorized")
        case .denied:
            print("[ATT] Status: denied")
        case .restricted:
            print("[ATT] Status: restricted")
        case .notDetermined:
            print("[ATT] Status: notDetermined")
        }
    }
}
