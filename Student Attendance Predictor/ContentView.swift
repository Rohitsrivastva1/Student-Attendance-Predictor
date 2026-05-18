//
//  ContentView.swift
//  Student Attendance Predictor
//
//  Created by Rohit Srivastava on 02/04/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var storeKit: StoreKitManager
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
            .onAppear {
                subjectStore.setProGatingEnabled(true)
                syncProAccessFromStoreKit()
            }
            .onChange(of: storeKit.purchasedProductIDs) { _, _ in
                syncProAccessFromStoreKit()
            }
    }

    private func syncProAccessFromStoreKit() {
        subjectStore.setProUnlocked(storeKit.hasProAccess)
    }
}

private extension Notification.Name {
    static let showProUpsellRequested = Notification.Name("showProUpsellRequested")
}

#Preview {
    ContentView()
        .environmentObject(StoreKitManager.shared)
}
