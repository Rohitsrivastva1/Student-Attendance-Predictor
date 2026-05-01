//
//  ContentView.swift
//  Student Attendance Predictor
//
//  Created by Rohit Srivastava on 02/04/26.
//

import SwiftUI

// MARK: - v0.2 Release Notes (Pending Configuration)
// TODO: Release "What-If Simulator" experience.
// TODO: Release "Calculation" module improvements.
// TODO: Release "Upgrade to Pro" flow (currently not configured).

struct ContentView: View {
    @StateObject private var subjectStore: SubjectStore

    init() {
        _subjectStore = StateObject(
            wrappedValue: SubjectStore(
                onUpgradeRequested: {
                    NotificationCenter.default.post(name: .showProUpsellRequested, object: nil)
                }
            )
        )
    }

    var body: some View {
        HomeView(viewModel: subjectStore.calculator, subjectStore: subjectStore)
            // v0.2 (hidden for this release): Upgrade to Pro hook UI
            // .onReceive(NotificationCenter.default.publisher(for: .showProUpsellRequested)) { _ in
            //     isShowingProUpsell = true
            // }
            // .alert("Pro Upgrade Hook", isPresented: $isShowingProUpsell) {
            //     Button("Later", role: .cancel) {}
            //     Button("Unlock Pro") {
            //         subjectStore.setProUnlocked(true)
            //     }
            // } message: {
            //     Text("This is the feature-flagged upgrade hook point. Wire this action to StoreKit/RevenueCat paywall.")
            // }
            .onAppear {
                // Release override: keep Pro gating disabled while upsell is hidden.
                subjectStore.setProGatingEnabled(false)
            }
    }
}

private extension Notification.Name {
    static let showProUpsellRequested = Notification.Name("showProUpsellRequested")
}

#Preview {
    ContentView()
}
