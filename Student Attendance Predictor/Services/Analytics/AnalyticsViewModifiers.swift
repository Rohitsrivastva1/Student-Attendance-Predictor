//
//  AnalyticsViewModifiers.swift
//  Student Attendance Predictor
//
//  Ergonomic SwiftUI helpers for screen tracking. Apply `.analyticsScreen(_:)`
//  to a sheet/pushed view to log a screen view on appear and restore the
//  underlying screen on dismiss. Tabs are tracked directly via `setScreen`.
//

import SwiftUI

extension View {
    /// Tracks a presented/pushed screen and restores the previous screen on dismiss.
    func analyticsScreen(_ screen: AppScreen) -> some View {
        modifier(AnalyticsScreenModifier(screen: screen))
    }

    /// Maps SwiftUI's ScenePhase to the analytics service.
    func trackScenePhase(_ phase: ScenePhase) -> some View {
        onChange(of: phase) { _, newPhase in
            switch newPhase {
            case .active:
                AnalyticsService.shared.handleForeground()
                AdMobAppOpenService.shared.showAdIfAvailable()
            case .background:
                AnalyticsService.shared.handleBackground()
            default:
                break
            }
        }
    }
}

private struct AnalyticsScreenModifier: ViewModifier {
    let screen: AppScreen
    @State private var restoreTo: AppScreen?

    func body(content: Content) -> some View {
        content
            .onAppear {
                restoreTo = AnalyticsService.shared.currentScreen
                AnalyticsService.shared.setScreen(screen)
            }
            .onDisappear {
                if let restoreTo {
                    AnalyticsService.shared.setScreen(restoreTo)
                }
            }
    }
}
