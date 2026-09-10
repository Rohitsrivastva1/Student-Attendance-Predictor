//
//  OnboardingView.swift
//  Student Attendance Predictor
//
//  Three visual screens — the only jobs a new student needs.
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

    private var pages: [(image: BrandIllustration, title: String, body: String, accent: Color)] {
        [
            (
                .onboardKnow,
                market == .india ? "How many can I bunk?" : "How many can I skip?",
                "Bunk Planner does the 75% math. You just log class.",
                BrandColor.colorAccentPrimary
            ),
            (
                .onboardTap,
                "After class, tap once",
                "Pick the days you have each paper. Then Attend, Missed, or No class — that’s the habit.",
                BrandColor.colorAttend
            ),
            (
                .onboardAlert,
                "We’ll catch you before you drop",
                "If a subject gets risky, you get a ping — before detention, not after.",
                BrandColor.colorPremium
            )
        ]
    }

    private var isProfileStep: Bool { page >= pages.count }
    private var stepCount: Int { pages.count + 1 }

    var body: some View {
        ZStack {
            BrandColor.colorBackground
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
        .onAppear {
            AnalyticsService.shared.log(.funnelStep(step: "onboarding_intro"))
        }
        .onChange(of: page) { _, newPage in
            if newPage >= pages.count {
                AnalyticsService.shared.log(.funnelStep(step: "profile_form"))
                AnalyticsService.shared.setScreen(.onboardingProfile)
            }
        }
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
                        .fill(index == page ? pages[min(page, pages.count - 1)].accent : Color.white.opacity(0.22))
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
                Text(page < pages.count - 1 ? "Next" : "Add your name")
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

    private func pageContent(
        _ item: (image: BrandIllustration, title: String, body: String, accent: Color)
    ) -> some View {
        VStack(spacing: 22) {
            Spacer()
            BrandHeroImage(illustration: item.image, size: 248)
            VStack(spacing: 12) {
                Text(item.title)
                    .font(BrandType.display(30))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(item.body)
                    .font(BrandType.body(16))
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
        AnalyticsService.shared.log(.funnelStep(step: "profile_done"))
        finishIntro(via: "profile_continue")
        SchoolabeSyncService.shared.scheduleSync(subjectStore: nil)
    }

    private func finishIntro(via: String) {
        UserDefaults.standard.set(true, forKey: "onboarding.didComplete")
        AnalyticsService.shared.log(.onboardingCompleted(via: via))
        onFinished()
    }
}
