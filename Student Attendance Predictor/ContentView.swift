//
//  ContentView.swift
//  Student Attendance Predictor
//
//  Created by Rohit Srivastava on 02/04/26.
//

import SwiftUI

struct ContentView: View {
    @State private var subjectStore: SubjectStore?

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.1)
                .ignoresSafeArea()

            if let subjectStore {
                HomeView(viewModel: subjectStore.calculator, subjectStore: subjectStore)
                    .transition(.opacity)
            } else {
                ProgressView("Loading…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tint(.white)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .task(id: subjectStore == nil) {
            guard subjectStore == nil else { return }
            await Task.yield()
            await PersistenceController.shared.waitForStoreIfNeeded()
            let store = SubjectStore()
            store.performDeferredLaunchTasks()
            subjectStore = store
        }
    }
}

#Preview {
    ContentView()
}
