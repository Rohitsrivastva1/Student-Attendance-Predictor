//
//  OnboardingProfileView.swift
//  Student Attendance Predictor
//
//  Short profile setup — required at end of onboarding; editable in Settings.
//

import SwiftUI

struct OnboardingProfileView: View {
    enum Style {
        case onboarding
        case settings
    }

    @Binding var name: String
    @Binding var age: Int?
    @Binding var classOrDegree: String
    @Binding var institutionName: String
    var style: Style = .onboarding
    var onContinue: () -> Void
    var onCancel: (() -> Void)?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, classOrDegree, institution
    }

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let mint = Color(red: 0.2, green: 0.9, blue: 0.5)
    private let ages = Array(15...30)

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedClass: String {
        classOrDegree.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedInstitution: String {
        institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        trimmedName.isEmpty == false
            && trimmedClass.isEmpty == false
            && trimmedInstitution.isEmpty == false
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: 24) {
                    heroHeader

                    if trimmedName.isEmpty == false {
                        previewCard
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    VStack(spacing: 18) {
                        profileField(
                            title: "What should we call you?",
                            icon: "person.fill",
                            isValid: trimmedName.isEmpty == false
                        ) {
                            TextField("Your first name", text: $name)
                                .focused($focusedField, equals: .name)
                                .textContentType(.givenName)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .onSubmit { focusedField = .classOrDegree }
                        }

                        studyLevelSection

                        profileField(
                            title: "Where do you study?",
                            icon: "building.columns.fill",
                            isValid: trimmedInstitution.isEmpty == false
                        ) {
                            TextField("School or college name", text: $institutionName)
                                .focused($focusedField, equals: .institution)
                                .textContentType(.organizationName)
                                .submitLabel(.done)
                        }

                        ageSection
                    }

                    privacyNote
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }

            continueButton
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: trimmedName)
        .animation(.easeInOut(duration: 0.2), value: canContinue)
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            if style == .settings, let onCancel {
                Button("Cancel", action: onCancel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            if style == .onboarding {
                Text("Final step")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(cyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(cyan.opacity(0.15))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(cyan.opacity(0.35), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(minHeight: style == .settings ? 44 : 36)
    }

    private var heroHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [cyan.opacity(0.35), mint.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .blur(radius: 2)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [cyan.opacity(0.6), mint.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 88, height: 88)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [cyan, mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(style == .onboarding ? "Let's personalize\nBunk Planner" : "Your student profile")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Quick setup — then straight to tracking attendance.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var previewCard: some View {
        HStack(spacing: 12) {
            Text("👋")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("Hey, \(trimmedName)!")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(trimmedClass.isEmpty ? "Pick your class below" : trimmedClass)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cyan.opacity(0.18), mint.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cyan.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var studyLevelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldLabel(title: "Class or degree", icon: "book.fill", isValid: trimmedClass.isEmpty == false)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                ForEach(StudyLevelChip.allCases) { chip in
                    let selected = classOrDegree == chip.rawValue
                    Button {
                        classOrDegree = chip.rawValue
                        focusedField = .institution
                    } label: {
                        Text(chip.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? .black : .white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? cyan : Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(selected ? cyan : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            profileField(
                title: "Or type yours",
                icon: "pencil",
                isValid: trimmedClass.isEmpty == false,
                compactLabel: true
            ) {
                TextField("e.g. B.Tech 2nd year", text: $classOrDegree)
                    .focused($focusedField, equals: .classOrDegree)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .institution }
            }
        }
    }

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(title: "Age (optional)", icon: "calendar", isValid: true, optional: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ages, id: \.self) { value in
                        let selected = age == value
                        Button {
                            age = selected ? nil : value
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(selected ? .black : .white.opacity(0.85))
                                .frame(width: 48, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selected ? mint : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(mint.opacity(0.9))
            Text("Attendance marks stay on your device. We only save this profile and your subject names to improve Bunk Planner.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text(style == .onboarding ? "Start tracking" : "Save profile")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                if canContinue {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .foregroundStyle(canContinue ? .black : .white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        canContinue
                            ? LinearGradient(colors: [cyan, mint.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                    )
            )
        }
        .disabled(canContinue == false)
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    // MARK: - Field helpers

    private func profileField<P: View>(
        title: String,
        icon: String,
        isValid: Bool,
        compactLabel: Bool = false,
        @ViewBuilder content: () -> P
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(title: title, icon: icon, isValid: isValid, compact: compactLabel)
            content()
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(12)
                .background(fieldBackground(focused: focusedFieldMatches(title: title, icon: icon)))
        }
    }

    private func fieldLabel(title: String, icon: String, isValid: Bool, optional: Bool = false, compact: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: compact ? 10 : 11, weight: .bold))
                .foregroundStyle(cyan.opacity(0.85))
            Text(title)
                .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            if optional {
                Text("· optional")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
            }
            Spacer(minLength: 0)
            if isValid && optional == false {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(mint)
            }
        }
    }

    private func focusedFieldMatches(title: String, icon: String) -> Bool {
        switch (title, focusedField) {
        case ("What should we call you?", .name), ("Or type yours", .classOrDegree), ("Where do you study?", .institution):
            return true
        default:
            return false
        }
    }

    private func fieldBackground(focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(focused ? 0.12 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(focused ? cyan.opacity(0.45) : Color.white.opacity(0.12), lineWidth: focused ? 1.5 : 1)
            )
    }
}

struct StudentProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileStore = StudentProfileStore.shared

    @State private var name = ""
    @State private var age: Int?
    @State private var classOrDegree = ""
    @State private var institutionName = ""

    var subjectStore: SubjectStore?

    var body: some View {
        NavigationStack {
            OnboardingProfileView(
                name: $name,
                age: $age,
                classOrDegree: $classOrDegree,
                institutionName: $institutionName,
                style: .settings,
                onContinue: saveAndDismiss,
                onCancel: { dismiss() }
            )
            .navigationBarHidden(true)
            .onAppear {
                name = profileStore.profile.name
                age = profileStore.profile.age
                classOrDegree = profileStore.profile.classOrDegree
                institutionName = profileStore.profile.institutionName
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveAndDismiss() {
        let profile = StudentProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: age,
            classOrDegree: classOrDegree.trimmingCharacters(in: .whitespacesAndNewlines),
            institutionName: institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        profileStore.update(profile)
        AnalyticsService.shared.log(.studentProfileUpdated(source: "settings"))
        SchoolabeSyncService.shared.scheduleSync(subjectStore: subjectStore)
        dismiss()
    }
}
