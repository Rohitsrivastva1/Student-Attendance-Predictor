//
//  DebugToolsView.swift
//  Student Attendance Predictor
//
//  QA helpers — compiled in DEBUG builds only.
//

import SwiftUI

#if DEBUG
struct DebugToolsView: View {
    @ObservedObject var subjectStore: SubjectStore
    @ObservedObject private var entitlements = AdEntitlementsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var didResetMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Fill 30-day screenshot data") {
                        subjectStore.fillScreenshotDemoMonth()
                        showReset("Loaded Data Structures, Mathematics, Physics with ~30 days. Close Settings, then screenshot Today, Plan, Log, and Subjects.")
                    }
                    Text("Replaces current papers. Saturday is a class day so Today looks filled. Review prompt is snoozed for a week so it won’t cover shots.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Screenshots")
                }

                Section {
                    Toggle(isOn: proBinding) {
                        Label("Premium (Pro)", systemImage: "crown.fill")
                    }
                    Text("Unlocks skip planner, forecast, PDF/CSV export, unlimited subjects, Focus pro durations, and hides ads — no StoreKit purchase.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Entitlements")
                }

                Section {
                    Button("Reset guided setup") {
                        GuidedSetupStore.shared.resetForDebug()
                        showReset("Guided setup reset — reopen Home.")
                    }
                    Button("Reset widget install prompt") {
                        WidgetPromptCoordinator.shared.resetForDebug()
                        showReset("Widget prompt reset.")
                    }
                    Button("Reset onboarding flag") {
                        UserDefaults.standard.set(false, forKey: "onboarding.didComplete")
                        showReset("Onboarding flag cleared — relaunch to see intro.")
                    }
                    Button("Reset first-mark flag") {
                        UserDefaults.standard.set(false, forKey: "analytics.didLogFirstMark")
                        showReset("First-mark flag cleared.")
                    }
                    Button("Reset multi-feature week") {
                        MultiFeatureEngagementStore.resetForDebug()
                        showReset("Multi-feature week tracking reset.")
                    }
                } header: {
                    Text("Reset prompts & coach marks")
                } footer: {
                    Text("Use before re-testing P5 flows (guided setup, widget prompt, multi-feature WAU).")
                }

                if let didResetMessage {
                    Section {
                        Text(didResetMessage)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    LabeledContent("Pro status") {
                        Text(entitlements.isPro ? "Active" : "Free")
                            .foregroundStyle(entitlements.isPro ? .green : .secondary)
                    }
                    LabeledContent("Banners hidden") {
                        Text(entitlements.areBannersHidden ? "Yes" : "No")
                    }
                    LabeledContent("Forecast unlocked") {
                        Text(entitlements.isForecastUnlocked ? "Yes" : "No")
                    }
                } header: {
                    Text("Current state")
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var proBinding: Binding<Bool> {
        Binding(
            get: { entitlements.isPro },
            set: { entitlements.setProUnlocked($0) }
        )
    }

    private func showReset(_ message: String) {
        didResetMessage = message
    }
}
#endif
