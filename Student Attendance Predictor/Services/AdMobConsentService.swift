//
//  AdMobConsentService.swift
//  Student Attendance Predictor
//
//  Google User Messaging Platform (UMP) — consent for personalized ads (GDPR / EEA).
//

import Foundation
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

@MainActor
enum AdMobConsentService {
    /// Whether ads may be requested after the latest consent info update (and form, if shown).
    static var canRequestAds: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.canRequestAds
        #else
        true
        #endif
    }

    /// Show “Ad privacy choices” in Settings when Google requires a privacy options entry point.
    static var isPrivacyOptionsRequired: Bool {
        #if canImport(UserMessagingPlatform)
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        false
        #endif
    }

    /// Request consent info on every launch, then present the GDPR/consent form when required.
    static func gatherConsentIfNeeded() async {
        #if canImport(UserMessagingPlatform)
        let parameters = makeRequestParameters()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            #if DEBUG
            print("[UMP] Consent form error: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    /// Lets users change ad personalization choices later (required entry point in some regions).
    static func presentPrivacyOptions() async throws {
        #if canImport(UserMessagingPlatform)
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        #endif
    }

    #if canImport(UserMessagingPlatform)
    private static func makeRequestParameters() -> RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        // Simulates EEA so the consent popup appears while developing (remove effect in Release).
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif
        return parameters
    }
    #endif
}
