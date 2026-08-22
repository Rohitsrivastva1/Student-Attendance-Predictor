//
//  OnboardingView.swift
//  Student Attendance Predictor
//
//  Lightweight intro + required profile step — under ~30 seconds.
//

import SwiftUI

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var page = 0
    @State private var name = ""
    @State private var age: Int?
    @State private var classOrDegree = ""
    @State private var institutionName = ""

    private var market: StudentMarket { StudentMarketStore.current }

    private var pages: [(icon: String, title: String, body: String, accent: Color)] {
        [
            (
                "shield.checkerboard",
                market == .india ? "Know before you bunk" : "Know before you skip",
                "See exactly how many classes you can safely miss.",
                Color(red: 0.32, green: 0.84, blue: 1.0)
            ),
            (
                "hand.tap.fill",
                "Track in seconds",
                "Log today's attendance with one tap.",
                Color(red: 0.2, green: 0.9, blue: 0.5)
            ),
            (
                "square.grid.2x2.fill",
                toolsOnboardingTitle,
                toolsOnboardingBody,
                Color(red: 0.72, green: 0.55, blue: 1.0)
            ),
            (
                "bell.badge.fill",
                "Stay above your target",
                "Get alerts before your attendance becomes risky.",
                Color(red: 1.0, green: 0.78, blue: 0.28)
            )
        ]
    }

    private var isProfileStep: Bool { page >= pages.count }
    private var stepCount: Int { pages.count + 1 }

    private var toolsOnboardingTitle: String {
        switch market {
        case .india: return "Tools: CGPA & focus"
        case .unitedKingdom: return "Tools: marks & focus"
        case .unitedStates, .other: return "Tools: GPA & focus"
        }
    }

    private var toolsOnboardingBody: String {
        switch market {
        case .india:
            return "Open Tools for Focus Timer, 10-point CGPA, and exam reminders."
        case .unitedKingdom:
            return "Open Tools for Focus Timer, module marks, and exam reminders."
        case .unitedStates, .other:
            return "Open Tools for Focus Timer, 4.0 GPA, and exam reminders."
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.10),
                    Color(red: 0.07, green: 0.08, blue: 0.14),
                    Color(red: 0.04, green: 0.07, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if isProfileStep {
                OnboardingProfileView(
                    name: $name,
                    age: $age,
                    classOrDegree: $classOrDegree,
                    institutionName: $institutionName,
                    style: .onboarding,
                    onContinue: finishWithProfile
                )
            } else {
                introPages
            }
        }
        .preferredColorScheme(.dark)
        .analyticsScreen(.onboarding)
    }

    private var introPages: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") {
                    page = pages.count
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    pageContent(item)
                        .tag(index)
                }
            }
            #if canImport(UIKit)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif

            HStack(spacing: 8) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.white : Color.white.opacity(0.25))
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
            }
            .padding(.bottom, 20)

            Button {
                if page < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        page += 1
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        page = pages.count
                    }
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Set up profile")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule(style: .continuous)
                            .fill(pages[min(page, pages.count - 1)].accent)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private func pageContent(_ item: (icon: String, title: String, body: String, accent: Color)) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(item.accent.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .blur(radius: 8)
                Image(systemName: item.icon)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(item.accent)
            }

            VStack(spacing: 12) {
                Text(item.title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(item.body)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
            Spacer()
        }
    }

    private func finishWithProfile() {
        let profile = StudentProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: age,
            classOrDegree: classOrDegree.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionName: institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard profile.isCompleteEnoughToSync else { return }

        StudentProfileStore.shared.save(profile, skipped: false)
        AnalyticsService.shared.log(.studentProfileCompleted(skipped: false))
        finishIntro(via: "profile_continue")
        SchoolabeSyncService.shared.scheduleSync(subjectStore: nil)
    }

    private func finishIntro(via: String) {
        UserDefaults.standard.set(true, forKey: "onboarding.didComplete")
        AnalyticsService.shared.log(.onboardingCompleted(via: via))
        onFinished()
    }
}
