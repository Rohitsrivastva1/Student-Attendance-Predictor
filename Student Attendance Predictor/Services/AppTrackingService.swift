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

/// Result of the system ATT prompt (or current status if already decided).
enum TrackingAuthorization: Sendable, Equatable {
    /// User allowed tracking; IDFA may be used for personalized ads.
    case authorized
    /// User denied tracking; use contextual (non‑personalized) ads only.
    case denied
    /// Tracking restricted by device policy (e.g. parental controls).
    case restricted
    /// Prompt not shown yet (transient until `requestAuthorizationIfNeeded()` finishes).
    case notDetermined
}

@MainActor
enum AppTrackingService {
    private(set) static var authorization: TrackingAuthorization = .notDetermined

    /// Whether ad requests may use IDFA for personalization.
    static var allowsPersonalizedAds: Bool {
        authorization == .authorized
    }

    /// Call once per launch, before UMP or `MobileAds.shared.start()`.
    static func requestAuthorizationIfNeeded() async {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14, *) {
            let current = ATTrackingManager.trackingAuthorizationStatus
            if current == .notDetermined {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    ATTrackingManager.requestTrackingAuthorization { status in
                        Task { @MainActor in
                            authorization = map(status)
                            #if DEBUG
                            print("[ATT] User responded: \(authorization)")
                            #endif
                            continuation.resume()
                        }
                    }
                }
            } else {
                authorization = map(current)
                #if DEBUG
                print("[ATT] Existing status: \(authorization)")
                #endif
            }
            return
        }
        #endif
        // Pre–iOS 14: no ATT API; treat as authorized for ad configuration only.
        authorization = .authorized
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
}
