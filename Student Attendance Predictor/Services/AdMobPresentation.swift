//
//  AdMobPresentation.swift
//  Student Attendance Predictor
//
//  Shared helpers for full-screen ad presentation: root VC resolution,
//  cross-format presentation locks, and UI-settle retries.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum AdMobFullScreenGate {
    private(set) static var isOccupied = false

    @discardableResult
    static func tryAcquire() -> Bool {
        guard isOccupied == false else { return false }
        isOccupied = true
        return true
    }

    static func release() {
        isOccupied = false
    }
}

#if canImport(UIKit)
@MainActor
enum AdMobPresentation {
    /// Resolves a view controller suitable for `present(from:)`, retrying while SwiftUI settles.
    static func waitForRoot(
        maxAttempts: Int = 10,
        delayNanoseconds: UInt64 = 120_000_000
    ) async -> UIViewController? {
        for attempt in 1...maxAttempts {
            if let root = presentationRootViewController {
                return root
            }
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
        }
        return nil
    }

    /// Best root for full-screen ads — prefers the foreground-active scene's key window.
    static var presentationRootViewController: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.activationState == .foregroundInactive })
            ?? scenes.first

        guard let scene = activeScene else { return nil }
        let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first(where: { !$0.isHidden })
        guard let root = window?.rootViewController else { return nil }

        let top = topMostViewController(from: root)
        guard top.view.window != nil else { return nil }
        if top.isBeingDismissed || top.isMovingFromParent { return nil }
        return top
    }

    private static func topMostViewController(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController,
           presented.isBeingDismissed == false {
            return topMostViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topMostViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMostViewController(from: selected)
        }
        return controller
    }
}
#endif
