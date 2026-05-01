//
//  HomeView.swift
//  Student Attendance Predictor
//

import SwiftUI
#if canImport(StoreKit)
import StoreKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var viewModel: AttendanceViewModel
    @ObservedObject var subjectStore: SubjectStore
    @State private var selectedTab: HomeTab = .home
    @State private var selectedScenario: ScenarioAction = .current
    @State private var isShowingSettings = false
    @State private var isShowingSubjects = false
    @State private var editingTimetableSubjectID: UUID?
    @State private var overviewEditingSubjectID: UUID?
    @State private var overviewEditingName = ""
    @State private var isAnimating = false
    @State private var shareItems: [Any] = []
    @State private var isShowingShareSheet = false
    @State private var isBreakdownExpanded = false
    @State private var customAttendCount = 0
    @State private var customMissCount = 0
    @State private var forecastWeeks = 1
    @State private var forecastHolidayClasses = 0
    @State private var forecastExpectedAbsences = 0
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    /// Light tail padding inside tab scroll views (iPhone FAB clearance uses `safeAreaInset`, not this value).
    private var tabScrollBottomPadding: CGFloat { 24 }

    @ViewBuilder
    private var bottomChrome: some View {
        VStack(spacing: 0) {
            if let result = viewModel.result {
                floatingActionBanner(for: result)
                    .padding(.horizontal, isRegularWidth ? 28 : 20)
                    .padding(.top, 6)
                    .padding(.bottom, isRegularWidth ? 6 : 8)
            }
        }
    }

    /// iPhone: floating “Attend … next” strip inside scroll `safeAreaInset` so content never sits under it.
    @ViewBuilder
    private var phoneFloatingResultStrip: some View {
        if let result = viewModel.result {
            VStack(spacing: 0) {
                floatingActionBanner(for: result)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.05, green: 0.06, blue: 0.1))
        }
    }

    @ViewBuilder
    private func phoneScrollWithFABInset<Content: View>(@ViewBuilder scroll: () -> Content) -> some View {
        if isRegularWidth {
            scroll()
        } else if viewModel.result != nil {
            scroll().safeAreaInset(edge: .bottom, spacing: 0) {
                phoneFloatingResultStrip
            }
        } else {
            scroll()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated Dark Premium Background
                animatedBackground
                mainNavigationContent
            }
            .preferredColorScheme(.dark)
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        triggerLightHaptic()
                        isShowingSubjects = true
                    } label: {
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(.white)
                    }

                    Button {
                        triggerLightHaptic()
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .onChange(of: viewModel.totalClassesInput) { _, _ in
                selectedScenario = .current
            }
            .onChange(of: viewModel.attendedClassesInput) { _, _ in
                selectedScenario = .current
            }
            .onChange(of: viewModel.requiredPercentageInput) { _, _ in
                selectedScenario = .current
            }
            .onAppear {
                isAnimating = true
            }
            .onChange(of: viewModel.reviewRequestToken) { _, _ in
                requestAppReview()
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ActivityView(activityItems: shareItems)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsSheetView(viewModel: viewModel)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $isShowingSubjects) {
                SubjectListView(subjectStore: subjectStore)
                    .preferredColorScheme(.dark)
            }
            .sheet(
                isPresented: Binding(
                    get: { editingTimetableSubjectID != nil },
                    set: { isPresented in
                        if isPresented == false {
                            editingTimetableSubjectID = nil
                        }
                    }
                )
            ) {
                if let subjectID = editingTimetableSubjectID {
                    TimetableEditorSheet(subjectStore: subjectStore, subjectID: subjectID)
                        .preferredColorScheme(.dark)
                }
            }
            .applyImpactFeedback(trigger: viewModel.attendedClassesInput)
            .applyImpactFeedback(trigger: viewModel.totalClassesInput)
        }
    }
    
    @ViewBuilder
    private var mainNavigationContent: some View {
        if isRegularWidth {
            ipadTabContainer
        } else {
            phoneTabContainer
        }
    }
    
    private var phoneTabContainer: some View {
        TabView(selection: $selectedTab) {
            homeTabContent
                .tag(HomeTab.home)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            insightsTabContent
                .tag(HomeTab.insights)
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }

            overviewTabContent
                .tag(HomeTab.overview)
                .tabItem {
                    Label("Overview", systemImage: "books.vertical.fill")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var ipadTabContainer: some View {
        HStack(alignment: .top, spacing: 16) {
            ipadSidebarRail
            VStack(spacing: 0) {
                selectedTabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.05, green: 0.06, blue: 0.1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var ipadSidebarRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sections")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(1.0)
            
            ForEach(HomeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 18)
                        Text(tab.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.black : Color.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTab == tab ? Color.white : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(selectedTab == tab ? 0.0 : 0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 180, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .home:
            homeTabContent
        case .insights:
            insightsTabContent
        case .overview:
            overviewTabContent
        }
    }

    private var homeTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    activeSubjectSelectorCard
                    homeHeroSection
                    inputSection
                    homeSupportingSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, tabScrollBottomPadding)
                .frame(maxWidth: isRegularWidth ? 920 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var insightsTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                VStack(spacing: 24) {
                    trendGraphCard
                    subjectForecastCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, tabScrollBottomPadding)
                .frame(maxWidth: isRegularWidth ? 920 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var overviewTabContent: some View {
        phoneScrollWithFABInset {
            ScrollView {
                VStack(spacing: 24) {
                    facultyDashboardCard
                    overviewSubjectManagerCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .padding(.bottom, tabScrollBottomPadding)
                .frame(maxWidth: isRegularWidth ? 920 : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private var animatedBackground: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.1).ignoresSafeArea()
            
            // Floating orbs
            Circle()
                .fill(Color(red: 0.1, green: 0.5, blue: 0.9).opacity(0.15))
                .blur(radius: 60)
                .frame(width: 300, height: 300)
                .offset(y: -150)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 15.0).repeatForever(autoreverses: false), value: isAnimating)
            
            Circle()
                .fill(Color(red: 0.8, green: 0.2, blue: 0.6).opacity(0.12))
                .blur(radius: 80)
                .frame(width: 400, height: 400)
                .offset(y: 150)
                .rotationEffect(.degrees(isAnimating ? -360 : 0))
                .animation(.linear(duration: 20.0).repeatForever(autoreverses: false), value: isAnimating)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bunk Planner")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .white.opacity(0.28), radius: 10, x: 0, y: 0)

            HStack(spacing: 8) {
                Text("Attendance Track")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.32, green: 0.84, blue: 1.0))
                    .textCase(.uppercase)
                    .tracking(1.1)

                Text("LIVE")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.03, green: 0.09, blue: 0.18))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.62, green: 0.98, blue: 1.0), Color(red: 0.32, green: 0.88, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                            )
                            .shadow(color: Color(red: 0.52, green: 0.96, blue: 1.0).opacity(0.78), radius: 10, x: 0, y: 0)
                            .shadow(color: Color(red: 0.35, green: 0.9, blue: 1.0).opacity(0.52), radius: 16, x: 0, y: 0)
                    )
            }

            Text("Don't guess your attendance — predict it.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 170, height: 1)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeSubjectSelectorCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE SUBJECT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .tracking(1.0)
                Text(subjectStore.selectedSubjectName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Menu {
                ForEach(subjectStore.subjects) { subject in
                    Button(subject.name) {
                        subjectStore.selectSubject(subject)
                    }
                }
            } label: {
                Label("Switch", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            inputField(title: "TOTAL CLASSES HOSTED", text: $viewModel.totalClassesInput, keyboardType: .numberPad)
            inputField(title: "CLASSES ATTENDED", text: $viewModel.attendedClassesInput, keyboardType: .numberPad)
            inputField(title: "REQUIRED MINIMUM (%)", text: $viewModel.requiredPercentageInput, keyboardType: .decimalPad)
            requiredPresetsRow
            clearInputsButton

            validationBanner
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
        )
    }

    private var requiredPresetsRow: some View {
        HStack(spacing: 10) {
            Text("Quick presets")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.trailing, 4)

            ForEach([75, 80, 85], id: \.self) { preset in
                let isSelected = Int(viewModel.requiredPercentage.rounded()) == preset

                Button {
                    triggerLightHaptic()
                    viewModel.applyRequiredPercentagePreset(Double(preset))
                } label: {
                    Text("\(preset)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.white : Color.white.opacity(0.12))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }

            Spacer()
        }
    }

    private var clearInputsButton: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                triggerLightHaptic()
                viewModel.resetInputs()
                selectedScenario = .current
            } label: {
                Label("Clear all", systemImage: "trash")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.red.opacity(0.2))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var homeHeroSection: some View {
        Group {
            if let result = displayResult {
                heroCard(for: result)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedScenario)
            } else {
                placeholderSection
            }
        }
    }

    private var homeSupportingSection: some View {
        Group {
            if let result = displayResult {
                VStack(spacing: 24) {
                    riskAlertsCard(for: result)
                    scenarioSection(baseResult: viewModel.result, displayedResult: result)
                    nextClassImpactCard
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedScenario)
            }
        }
    }

    private var overviewSubjectManagerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SUBJECT MANAGER")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .tracking(1.1)
                Spacer()
                Button {
                    triggerLightHaptic()
                    _ = subjectStore.addSubject()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .buttonStyle(PressableButtonStyle())
            }

            if subjectStore.subjects.isEmpty {
                Text("No subjects yet.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                ForEach(subjectStore.subjects) { subject in
                    VStack(alignment: .leading, spacing: 10) {
                        if overviewEditingSubjectID == subject.id {
                            TextField("Subject name", text: $overviewEditingName)
                                .textInputAutocapitalization(.words)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.28))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                        } else {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subject.name)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Attendance \(String(format: "%.1f%%", subject.currentPercentage))")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                if subject.id == subjectStore.selectedSubjectID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Button("Use") {
                                triggerLightHaptic()
                                subjectStore.selectSubject(subject)
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .buttonStyle(PressableButtonStyle())

                            if overviewEditingSubjectID == subject.id {
                                Button("Save") {
                                    triggerLightHaptic()
                                    subjectStore.renameSubject(id: subject.id, to: overviewEditingName)
                                    overviewEditingSubjectID = nil
                                    overviewEditingName = ""
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .buttonStyle(PressableButtonStyle())
                                .disabled(overviewEditingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("Cancel") {
                                    triggerLightHaptic()
                                    overviewEditingSubjectID = nil
                                    overviewEditingName = ""
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .buttonStyle(PressableButtonStyle())
                            } else {
                                Button("Rename") {
                                    triggerLightHaptic()
                                    overviewEditingSubjectID = subject.id
                                    overviewEditingName = subject.name
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .buttonStyle(PressableButtonStyle())
                            }

                            Button("Timetable") {
                                triggerLightHaptic()
                                editingTimetableSubjectID = subject.id
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .buttonStyle(PressableButtonStyle())

                            Button(role: .destructive) {
                                triggerLightHaptic()
                                subjectStore.deleteSubject(id: subject.id)
                                if overviewEditingSubjectID == subject.id {
                                    overviewEditingSubjectID = nil
                                    overviewEditingName = ""
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }

                Button("Open Full Subject Manager") {
                    isShowingSubjects = true
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func inputField(title: String, text: Binding<String>, keyboardType: KeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .tracking(1.2)

            HStack(spacing: 12) {
                stepperButton(symbol: "minus", text: text, keyboardType: keyboardType, delta: -1)

                TextField("0", text: text)
                    .applyKeyboardType(keyboardType)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                stepperButton(symbol: "plus", text: text, keyboardType: keyboardType, delta: 1)
            }
        }
    }

    private var validationBanner: some View {
        Group {
            if let validationMessage = viewModel.validationMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(red: 1.0, green: 0.4, blue: 0.4))
                    Text(validationMessage)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(red: 1.0, green: 0.4, blue: 0.4).opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var placeholderSection: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(height: 160)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.4))
                    Text("Awaiting data input...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
            )
    }

    private func heroCard(for result: AttendanceResult) -> some View {
        let isSafe = result.status == .safe
        let primaryStatusColor = isSafe ? Color(red: 0.1, green: 0.8, blue: 0.4) : Color(red: 1.0, green: 0.2, blue: 0.4)
        let secondaryStatusColor = isSafe ? Color(red: 0.0, green: 0.5, blue: 0.3) : Color(red: 0.8, green: 0.1, blue: 0.2)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: statusIconName(for: result))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(primaryStatusColor)
                        .shadow(color: primaryStatusColor.opacity(0.4), radius: 4, x: 0, y: 0)

                    Text(statusTitle(for: result))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(primaryStatusColor)
                        .tracking(1.5)
                }

                Spacer()

                Button {
                    triggerLightHaptic()
                    shareResult(result)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }

            Text(heroTitle(for: result))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.2), radius: 4, x: 0, y: 2)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(result.currentPercentage, specifier: "%.1f")%")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(primaryStatusColor)
                .contentTransition(.numericText(value: result.currentPercentage))

            Text(heroSubtitle(for: result))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            progressBar(for: result, color: primaryStatusColor)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [primaryStatusColor.opacity(0.5), .clear, secondaryStatusColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: primaryStatusColor.opacity(0.08), radius: 20, x: 0, y: 10)
    }

    private func scenarioSection(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SCENARIO SIMULATOR")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .tracking(1.2)

                Text("Forecast your future standing")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 12) {
                ForEach(ScenarioAction.allCases) { scenario in
                    Button {
                        triggerLightHaptic()
                        selectedScenario = scenario
                    } label: {
                        let isSelected = selectedScenario == scenario
                        let accentColor = Color(red: 0.3, green: 0.7, blue: 1.0)

                        Text(scenario.label)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSelected ? accentColor.opacity(0.2) : Color.black.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(isSelected ? accentColor : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
                                    )
                            )
                            .shadow(color: isSelected ? accentColor.opacity(0.3) : .clear, radius: 10, x: 0, y: 4)
                            .scaleEffect(isSelected ? 1.03 : 1.0)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Text(scenarioInsight(baseResult: baseResult, displayedResult: displayedResult))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.9, green: 0.9, blue: 1.0).opacity(0.7))
                .padding(.top, 4)
        }
    }

    private func riskAlertsCard(for result: AttendanceResult) -> some View {
        let riskLevel = CalculationService.riskLevel(
            attended: viewModel.attendedClasses,
            total: viewModel.totalClasses,
            required: viewModel.requiredPercentage
        )

        let message: String = {
            switch riskLevel {
            case .stable:
                return "Early risk check: Stable. You have healthy bunk buffer."
            case .warning:
                return "Early risk warning: You are close to threshold. Avoid unnecessary absences."
            case .critical:
                return "Critical risk: falling below target. Prioritize attendance recovery now."
            }
        }()

        let color: Color = {
            switch riskLevel {
            case .stable:
                return Color(red: 0.2, green: 0.9, blue: 0.5)
            case .warning:
                return .orange
            case .critical:
                return .red
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            Text("RISK ALERTS")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))

            if result.status == .safe {
                Text("Safe bunk buffer now: \(result.bunkAllowed)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            } else {
                Text("Recovery needed now: attend next \(result.recoveryNeeded) classes.")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var whatIfWorkbenchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT-IF SIMULATOR")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            HStack {
                Stepper("Miss next \(customMissCount)", value: $customMissCount, in: 0...20)
                Spacer()
                Stepper("Attend next \(customAttendCount)", value: $customAttendCount, in: 0...20)
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))

            if let customResult = viewModel.simulatedResult(attendMore: customAttendCount, skipMore: customMissCount) {
                Text("Projected attendance: \(String(format: "%.1f%%", customResult.currentPercentage))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(customResult.status == .safe ? Color.green : Color.orange)

                Text(customResult.status == .safe
                     ? "You can still miss \(customResult.bunkAllowed) more classes safely."
                     : "You would need \(customResult.recoveryNeeded) consecutive attended classes to recover.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("Enter attendance values to run what-if simulations.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var subjectForecastCard: some View {
        let forecasts = subjectStore.subjectForecasts(
            weeks: forecastWeeks,
            holidayClassCount: forecastHolidayClasses,
            expectedAbsences: forecastExpectedAbsences
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("SUBJECT-WISE FORECAST")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            HStack {
                Stepper("Weeks: \(forecastWeeks)", value: $forecastWeeks, in: 1...8)
                Spacer()
                Stepper("Holiday classes: \(forecastHolidayClasses)", value: $forecastHolidayClasses, in: 0...30)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))

            Stepper("Expected absences: \(forecastExpectedAbsences)", value: $forecastExpectedAbsences, in: 0...30)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            if forecasts.isEmpty {
                Text("No subjects to forecast yet.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                ForEach(forecasts) { item in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.subjectName)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Current \(String(format: "%.1f%%", item.currentPercentage)) → Forecast \(String(format: "%.1f%%", item.forecastedPercentage))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Text(item.riskLevel.rawValue)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(colorForRiskLevel(item.riskLevel))
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var facultyDashboardCard: some View {
        let summary = subjectStore.dashboardSummary

        return VStack(alignment: .leading, spacing: 10) {
            Text("FACULTY / ADMIN DASHBOARD")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            HStack(spacing: 10) {
                trendChip(title: "Subjects", value: "\(summary.totalSubjects)")
                trendChip(title: "At Risk", value: "\(summary.riskSubjects)")
                trendChip(title: "Safe", value: "\(summary.safeSubjects)")
            }

            Text("Average attendance: \(String(format: "%.1f%%", summary.averageAttendance))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            if let atRisk = summary.mostAtRiskSubject {
                Text("Most at risk: \(atRisk.name) (\(String(format: "%.1f%%", atRisk.currentPercentage)) vs target \(String(format: "%.0f%%", atRisk.requiredPercentage)))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func progressCard(for result: AttendanceResult) -> some View {
        let progress = min(max(result.currentPercentage / 100, 0), 1)
        let ringColor = result.status == .safe ? Color(red: 0.15, green: 0.85, blue: 0.5) : Color(red: 1.0, green: 0.3, blue: 0.3)

        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.3), radius: 5, x: 0, y: 0)
                
                Text("\(Int(result.currentPercentage.rounded()))%")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 90, height: 90)

            Text("CURRENT\nSTANDING")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .tracking(1.0)
        }
        .frame(maxWidth: 130)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        )
    }

    private func progressBar(for result: AttendanceResult, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let currentWidth = geometry.size.width * min(max(result.currentPercentage / 100, 0), 1)
                let targetWidth = geometry.size.width * min(max(viewModel.requiredPercentage / 100, 0), 1)

                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(color)
                            .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 0)
                            .frame(width: max(20, currentWidth))
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 20)
                            .shadow(color: .white, radius: 4, x: 0, y: 0)
                            .offset(x: max(0, min(targetWidth, geometry.size.width - 2)))
                    }
            }
            .frame(height: 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: result.currentPercentage)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.requiredPercentage)

            HStack(spacing: 8) {
                Text("CURRENT: \(Int(result.currentPercentage.rounded()))%")
                Spacer()
                Text("TARGET: \(Int(viewModel.requiredPercentage))%")
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .padding(.top, 4)

            Text(gapLabel(for: result))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var displayResult: AttendanceResult? {
        switch selectedScenario {
        case .current:
            return viewModel.result
        case .skipOne:
            return viewModel.simulatedResult(skipMore: 1)
        case .skipThree:
            return viewModel.simulatedResult(skipMore: 3)
        case .attendFive:
            return viewModel.simulatedResult(attendMore: 5)
        }
    }

    private func heroTitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "No classes logged yet."
        }
        if isPerfectAttendance(result: result) {
            return "You're perfect, but don't get overconfident 😄"
        }
        if isRecoveryMode(result: result) {
            return "Recovery mode activated."
        }
        if isCriticalRisk(result: result) {
            return "Attend next \(result.recoveryNeeded) classes or you're in danger ⚠️"
        }
        if result.status == .safe {
            return result.bunkAllowed > 0
                ? "You can skip \(result.bunkAllowed) classes safely."
                : "Perfectly balanced on the safe line."
        }
        return "Attend next \(result.recoveryNeeded) classes to recover."
    }

    private func heroSubtitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "Add your first class record to unlock predictions."
        }
        if isPerfectAttendance(result: result) {
            return "100% attendance streak. Great discipline."
        }
        if isRecoveryMode(result: result) {
            return "You're below 50%. Focus on attending consistently for the next few weeks."
        }
        if isCriticalRisk(result: result) {
            return "One more bunk can increase the recovery burden quickly."
        }
        if result.status == .safe {
            return result.bunkAllowed <= 1
                ? "1 more bunk = danger ⚠️"
                : "You're chilling 😎 Current attendance is \(String(format: "%.1f%%", result.currentPercentage))."
        }
        return "Your rate is \(String(format: "%.1f%%", result.currentPercentage)). Perfect attendance is mandatory now."
    }

    private func scenarioInsight(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> String {
        let percentageText = String(format: "%.0f%%", displayedResult.currentPercentage)
        let statusText = displayedResult.status == .safe ? "System Safe" : "Risk Detected"

        guard selectedScenario != .current, let _ = baseResult else {
            if displayedResult.status == .safe {
                return "Optimized: \(percentageText) — safely above target."
            }
            return "Action Required: Attend next \(displayedResult.recoveryNeeded) classes."
        }

        if displayedResult.status == .safe {
            return "Post Simulation → \(percentageText) (\(statusText))"
        }
        return "Post Simulation → Must attend next \(displayedResult.recoveryNeeded) classes."
    }

    private func actionSummary(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "Log first class"
        }
        if isRecoveryMode(result: result) {
            return "Recovery mode"
        }
        if result.status == .safe {
            return "Skip \(result.bunkAllowed) classes"
        }
        return "Attend \(result.recoveryNeeded) next"
    }

    private func planSubtitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "Start tracking"
        }
        if isRecoveryMode(result: result) {
            return "Below 50% attendance"
        }
        if result.status == .safe {
            return "Retains threshold"
        }
        return "Critical recovery"
    }

    private func gapLabel(for result: AttendanceResult) -> String {
        let gap = max(0, viewModel.requiredPercentage - result.currentPercentage)
        if gap == 0 {
            return "GAP TO TARGET: 0%"
        }
        return "GAP TO TARGET: \(String(format: "%.1f%%", gap))"
    }

    private func stepperButton(
        symbol: String,
        text: Binding<String>,
        keyboardType: KeyboardType,
        delta: Double
    ) -> some View {
        Button {
            triggerLightHaptic()
            adjustInput(text: text, keyboardType: keyboardType, delta: delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func adjustInput(text: Binding<String>, keyboardType: KeyboardType, delta: Double) {
        switch keyboardType {
        case .numberPad:
            let currentValue = Int(text.wrappedValue) ?? 0
            text.wrappedValue = String(max(0, currentValue + Int(delta)))
        case .decimalPad:
            let currentValue = Double(text.wrappedValue) ?? 0
            let newValue = max(0, currentValue + delta)
            text.wrappedValue = newValue.rounded(.towardZero) == newValue
                ? String(Int(newValue))
                : String(format: "%.1f", newValue)
        }
    }

    private func triggerLightHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func shareResult(_ result: AttendanceResult) {
        let message = shareMessage(for: result)
        #if canImport(UIKit)
        if let image = generateShareImage(result: result, message: message) {
            shareItems = [image, message]
        } else {
            shareItems = [message]
        }
        #else
        shareItems = [message]
        #endif
        isShowingShareSheet = true
    }

    private func requestAppReview() {
        #if canImport(StoreKit) && canImport(UIKit)
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
        #endif
    }

    private func shareMessage(for result: AttendanceResult) -> String {
        let cta = "Try Bunk Planner: Attendance Track."
        if result.status == .safe {
            if result.bunkAllowed > 0 {
                return "I can bunk \(result.bunkAllowed) classes safely 😎\n\(cta)"
            }
            return "I'm exactly on the safe attendance line ⚖️\n\(cta)"
        }
        return "I'm in recovery mode: need to attend \(result.recoveryNeeded) classes 💪\n\(cta)"
    }

    #if canImport(UIKit)
    private func generateShareImage(result: AttendanceResult, message: String) -> UIImage? {
        let renderer = ImageRenderer(content: shareSnapshotCard(result: result, message: message))
        let screenScale = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.scale ?? 2
        renderer.scale = screenScale
        return renderer.uiImage
    }
    #endif

    private func shareSnapshotCard(result: AttendanceResult, message: String) -> some View {
        return ZStack {
            shareBackground(for: result)

            VStack(alignment: .leading, spacing: 30) {
                shareHeader(for: result)
                shareHero(for: result)
                shareStatsGrid(for: result)
                shareFooter(message: message)
            }
            .padding(.horizontal, 68)
            .padding(.vertical, 76)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 1080, height: 1920)
    }

    private func shareBackground(for result: AttendanceResult) -> some View {
        let palette = sharePalette(for: result)

        return ZStack {
            LinearGradient(
                colors: palette.background,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.glow.opacity(0.28))
                .frame(width: 520, height: 520)
                .blur(radius: 50)
                .offset(x: 260, y: -540)

            Circle()
                .fill(palette.secondaryGlow.opacity(0.2))
                .frame(width: 620, height: 620)
                .blur(radius: 70)
                .offset(x: -250, y: 480)

            RoundedRectangle(cornerRadius: 140, style: .continuous)
                .fill(.white.opacity(0.03))
                .frame(width: 820, height: 820)
                .rotationEffect(.degrees(-18))
                .offset(x: 270, y: 520)
        }
    }

    private func shareHeader(for result: AttendanceResult) -> some View {
        let palette = sharePalette(for: result)

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [palette.accent, palette.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.72))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bunk Planner")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Attendance Track")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                Text(subjectStore.selectedSubjectName.uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent.opacity(0.95))
                    .tracking(1.8)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Text(result.status == .safe ? "SAFE ZONE" : "ATTENDANCE ALERT")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .tracking(1.6)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.08))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(palette.accent.opacity(0.45), lineWidth: 1)
                            )
                    )

                Text(shareTimestamp)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func shareHero(for result: AttendanceResult) -> some View {
        let palette = sharePalette(for: result)

        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text(shareHeadline(for: result))
                    .font(.system(size: 82, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(shareSubheadline(for: result))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .bottom, spacing: 16) {
                Text("\(result.currentPercentage, specifier: "%.1f")%")
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [palette.accent, palette.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text("current")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.bottom, 24)
            }

            VStack(alignment: .leading, spacing: 14) {
                shareProgressLabel(title: "Target", value: String(format: "%.0f%%", viewModel.requiredPercentage))
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.08))
                            .frame(height: 18)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [palette.accent, palette.secondaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * min(max(result.currentPercentage / 100, 0), 1),
                                height: 18
                            )
                    }
                }
                .frame(height: 18)
            }
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func shareStatsGrid(for result: AttendanceResult) -> some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                shareStatCard(
                    title: "Next Move",
                    value: sharePrimaryAction(for: result),
                    detail: sharePrimaryActionDetail(for: result),
                    tint: sharePalette(for: result).accent
                )
                shareStatCard(
                    title: "Attended",
                    value: "\(viewModel.attendedClasses)/\(viewModel.totalClasses)",
                    detail: "classes locked in",
                    tint: Color(red: 0.34, green: 0.77, blue: 1.0)
                )
            }

            HStack(spacing: 18) {
                shareStatCard(
                    title: "Margin",
                    value: shareMarginText(for: result),
                    detail: "vs required threshold",
                    tint: result.status == .safe ? Color(red: 0.35, green: 0.9, blue: 0.58) : Color(red: 1.0, green: 0.56, blue: 0.32)
                )
                shareStatCard(
                    title: "Status",
                    value: result.status == .safe ? "On Track" : "Needs Focus",
                    detail: result.status == .safe ? "story-ready flex" : "bounce-back phase",
                    tint: sharePalette(for: result).secondaryAccent
                )
            }
        }
    }

    private func shareFooter(message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(message)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Track. Predict. Share.")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)

                Spacer()

                Text("@ Bunk Planner")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func shareStatCard(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.2)

            Text(value)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func shareProgressLabel(title: String, value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.3)

            Spacer()

            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func shareHeadline(for result: AttendanceResult) -> String {
        if result.status == .safe {
            if result.bunkAllowed > 0 {
                return "I can skip \(result.bunkAllowed) class\(result.bunkAllowed == 1 ? "" : "es") and still stay safe."
            }
            return "I'm exactly on the attendance safe line."
        }

        return "I need \(result.recoveryNeeded) solid class\(result.recoveryNeeded == 1 ? "" : "es") to bounce back."
    }

    private func shareSubheadline(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return "Threshold cleared. This one is social-post worthy."
        }

        return "No more random bunks. Recovery starts with the very next lecture."
    }

    private func sharePrimaryAction(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return result.bunkAllowed > 0 ? "\(result.bunkAllowed) safe bunk\(result.bunkAllowed == 1 ? "" : "s")" : "Hold steady"
        }

        return "\(result.recoveryNeeded) classes"
    }

    private func sharePrimaryActionDetail(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return result.bunkAllowed > 0 ? "before crossing the line" : "one bunk changes the story"
        }

        return "needed in a row to recover"
    }

    private func shareMarginText(for result: AttendanceResult) -> String {
        let margin = result.currentPercentage - viewModel.requiredPercentage
        if abs(margin) < 0.05 {
            return "0.0%"
        }
        return String(format: "%@%.1f%%", margin > 0 ? "+" : "", margin)
    }

    private var shareTimestamp: String {
        Self.shareDateFormatter.string(from: Date())
    }

    private func sharePalette(for result: AttendanceResult) -> SharePalette {
        if result.status == .safe {
            return SharePalette(
                background: [
                    Color(red: 0.04, green: 0.08, blue: 0.14),
                    Color(red: 0.04, green: 0.15, blue: 0.20),
                    Color(red: 0.07, green: 0.08, blue: 0.14)
                ],
                accent: Color(red: 0.42, green: 0.98, blue: 0.78),
                secondaryAccent: Color(red: 0.29, green: 0.76, blue: 1.0),
                glow: Color(red: 0.26, green: 0.96, blue: 0.78),
                secondaryGlow: Color(red: 0.22, green: 0.71, blue: 1.0)
            )
        }

        return SharePalette(
            background: [
                Color(red: 0.12, green: 0.04, blue: 0.08),
                Color(red: 0.19, green: 0.06, blue: 0.11),
                Color(red: 0.09, green: 0.05, blue: 0.16)
            ],
            accent: Color(red: 1.0, green: 0.54, blue: 0.36),
            secondaryAccent: Color(red: 1.0, green: 0.32, blue: 0.52),
            glow: Color(red: 1.0, green: 0.38, blue: 0.44),
            secondaryGlow: Color(red: 0.95, green: 0.35, blue: 0.76)
        )
    }

    private static let shareDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM • h:mm a"
        return formatter
    }()

    private var trendGraphCard: some View {
        let points = trendPointsForSelectedSubject()
        let latest = points.last?.percentage ?? 0
        let minValue = points.map(\.percentage).min() ?? 0
        let maxValue = points.map(\.percentage).max() ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ATTENDANCE TREND")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .tracking(1.1)
                Spacer()
                Text("\(points.count) pts")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if points.count < 2 {
                Text("Trend graph unlocks after at least 2 updates for this subject.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                AttendanceTrendSparkline(points: points)
                    .frame(height: 90)

                HStack(spacing: 10) {
                    trendChip(title: "Latest", value: "\(String(format: "%.1f", latest))%")
                    trendChip(title: "Min", value: "\(String(format: "%.1f", minValue))%")
                    trendChip(title: "Max", value: "\(String(format: "%.1f", maxValue))%")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func trendPointsForSelectedSubject() -> [AttendanceTrendPoint] {
        guard let subjectID = subjectStore.selectedSubjectID else { return [] }
        return AttendanceTrendStore.load(subjectID: subjectID)
    }

    private func trendChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var nextClassImpactCard: some View {
        let attendImpact = viewModel.simulatedResult(attendMore: 1)
        let skipImpact = viewModel.simulatedResult(skipMore: 1)

        return VStack(alignment: .leading, spacing: 10) {
            Text("NEXT CLASS IMPACT")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(1.1)

            if viewModel.totalClasses == 0 {
                Text("No class history yet. Add classes to see tomorrow impact.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                if let skipImpact {
                    Text("If you skip tomorrow → \(String(format: "%.1f%%", skipImpact.currentPercentage))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                if let attendImpact {
                    Text("If you attend tomorrow → \(String(format: "%.1f%%", attendImpact.currentPercentage))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func calculationBreakdownCard(for result: AttendanceResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $isBreakdownExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current: \(viewModel.attendedClasses) / \(viewModel.totalClasses) = \(String(format: "%.2f%%", result.currentPercentage))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))

                    if let simulated = simulatedScenarioCounts(), let simulatedResult = displayResult {
                        Text("After \(simulated.label):")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        Text("\(simulated.attended) / \(simulated.total) = \(String(format: "%.2f%%", simulatedResult.currentPercentage))")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Calculation breakdown")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func simulatedScenarioCounts() -> (attended: Int, total: Int, label: String)? {
        switch selectedScenario {
        case .current:
            return nil
        case .skipOne:
            return (viewModel.attendedClasses, viewModel.totalClasses + 1, "skipping 1")
        case .skipThree:
            return (viewModel.attendedClasses, viewModel.totalClasses + 3, "skipping 3")
        case .attendFive:
            return (viewModel.attendedClasses + 5, viewModel.totalClasses + 5, "attending 5")
        }
    }

    private func isPerfectAttendance(result: AttendanceResult) -> Bool {
        viewModel.totalClasses > 0 && viewModel.attendedClasses == viewModel.totalClasses && result.currentPercentage >= 99.9
    }

    private func isRecoveryMode(result: AttendanceResult) -> Bool {
        viewModel.totalClasses > 0 && result.currentPercentage < 50
    }

    private func isCriticalRisk(result: AttendanceResult) -> Bool {
        result.status == .risk && result.recoveryNeeded >= 5
    }

    private func statusTitle(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "STATUS: READY"
        }
        if isPerfectAttendance(result: result) {
            return "STATUS: PERFECT"
        }
        if isRecoveryMode(result: result) {
            return "STATUS: RECOVERY MODE"
        }
        if result.status == .safe {
            return "STATUS: SAFE"
        }
        return isCriticalRisk(result: result) ? "STATUS: CRITICAL" : "STATUS: RISK"
    }

    private func statusIconName(for result: AttendanceResult) -> String {
        if viewModel.totalClasses == 0 {
            return "sparkles"
        }
        if isPerfectAttendance(result: result) {
            return "star.circle.fill"
        }
        if isRecoveryMode(result: result) {
            return "bolt.heart.fill"
        }
        if result.status == .safe {
            return "shield.checkerboard"
        }
        return isCriticalRisk(result: result) ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill"
    }

    private func floatingActionBanner(for result: AttendanceResult) -> some View {
        ResultCardView(
            title: result.status == .safe ? "Best next move" : "Recovery plan",
            value: actionSummary(for: result),
            subtitle: planSubtitle(for: result),
            tint: result.status == .safe ? Color(red: 0.2, green: 0.9, blue: 0.5) : Color(red: 1.0, green: 0.3, blue: 0.3),
            alignment: .center,
            isEmphasized: true
        )
        .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
    }

    private func colorForRiskLevel(_ level: RiskAlertLevel) -> Color {
        switch level {
        case .stable:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

private struct AttendanceTrendSparkline: View {
    let points: [AttendanceTrendPoint]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let minimum = points.map(\.percentage).min() ?? 0
            let maximum = points.map(\.percentage).max() ?? 100
            let range = max(maximum - minimum, 0.1)
            let stepX = points.count > 1 ? width / CGFloat(points.count - 1) : width

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.2))

                Path { path in
                    guard points.isEmpty == false else { return }
                    for index in points.indices {
                        let point = points[index]
                        let x = CGFloat(index) * stepX
                        let yRatio = (point.percentage - minimum) / range
                        let y = height - (CGFloat(yRatio) * height)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.84, blue: 0.95), Color(red: 0.22, green: 0.95, blue: 0.58)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                if let last = points.last {
                    let x = CGFloat(points.count - 1) * stepX
                    let yRatio = (last.percentage - minimum) / range
                    let y = height - (CGFloat(yRatio) * height)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle().stroke(Color(red: 0.22, green: 0.95, blue: 0.58), lineWidth: 2)
                        )
                        .position(x: x, y: y)
                }
            }
        }
    }
}

private struct SharePalette {
    let background: [Color]
    let accent: Color
    let secondaryAccent: Color
    let glow: Color
    let secondaryGlow: Color
}

#Preview {
    ContentView()
}

enum KeyboardType {
    case numberPad
    case decimalPad
}

private enum HomeTab: CaseIterable {
    case home
    case insights
    case overview

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .insights:
            return "chart.line.uptrend.xyaxis"
        case .overview:
            return "books.vertical.fill"
        }
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .insights:
            return "Insights"
        case .overview:
            return "Overview"
        }
    }
}

private enum ScenarioAction: CaseIterable, Identifiable {
    case current
    case skipOne
    case skipThree
    case attendFive

    var id: Self { self }

    var label: String {
        switch self {
        case .current:
            return "Current"
        case .skipOne:
            return "Skip 1"
        case .skipThree:
            return "Skip 3"
        case .attendFive:
            return "Attend 5"
        }
    }

    var description: String {
        switch self {
        case .current:
            return "current"
        case .skipOne:
            return "skipping 1"
        case .skipThree:
            return "skipping 3"
        case .attendFive:
            return "attending 5"
        }
    }
}

private extension View {
    @ViewBuilder
    func applyKeyboardType(_ keyboardType: KeyboardType) -> some View {
        #if canImport(UIKit)
        switch keyboardType {
        case .numberPad:
            self.keyboardType(.numberPad)
        case .decimalPad:
            self.keyboardType(.decimalPad)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func applyImpactFeedback<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.impact, trigger: trigger)
        } else {
            self
        }
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#if canImport(UIKit)
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct SubjectListView: View {
    @ObservedObject var subjectStore: SubjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAddPrompt = false
    @State private var newSubjectName = ""
    @State private var isShowingRenamePrompt = false
    @State private var renameSubjectName = ""
    @State private var renamingSubjectID: UUID?
    @State private var editingTimetableSubjectID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section("Subjects") {
                    ForEach(subjectStore.subjects) { subject in
                        Button {
                            subjectStore.selectSubject(subject)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(subject.name)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Target \(Int(subject.requiredPercentage))%")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                Spacer()

                                Text("\(Int(subject.currentPercentage.rounded()))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(subject.status == .safe ? Color.green : Color.red)

                                if subject.id == subjectStore.selectedSubjectID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Timetable") {
                                editingTimetableSubjectID = subject.id
                            }
                            .tint(.purple)

                            Button("Rename") {
                                renamingSubjectID = subject.id
                                renameSubjectName = subject.name
                                isShowingRenamePrompt = true
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                subjectStore.deleteSubject(id: subject.id)
                            } label: {
                                Text("Delete")
                            }
                        }
                    }
                    .onDelete(perform: subjectStore.deleteSubjects)
                }

                // v0.2 (hidden for this release): Plan section
                // Section("Plan") {
                //     Text(subjectStore.subjectLimitDescription)
                //         .font(.system(size: 13, weight: .medium, design: .rounded))
                //         .foregroundStyle(.white.opacity(0.75))
                //         .listRowBackground(Color.white.opacity(0.04))
                //
                //     // v0.2 (hidden for this release): Upgrade to Pro entry points
                //     // if subjectStore.isAtSubjectLimit && subjectStore.isProUnlocked == false {
                //     //     Text("Limit reached: add more subjects with Pro.")
                //     //         .font(.system(size: 12, weight: .semibold, design: .rounded))
                //     //         .foregroundStyle(.orange)
                //     //         .listRowBackground(Color.white.opacity(0.04))
                //     // }
                //     //
                //     // if subjectStore.isProUnlocked == false {
                //     //     Button {
                //     //         subjectStore.requestProUpgrade()
                //     //     } label: {
                //     //         Label("Upgrade to Pro", systemImage: "sparkles")
                //     //             .font(.system(size: 14, weight: .bold, design: .rounded))
                //     //             .foregroundStyle(.white)
                //     //     }
                //     //     .listRowBackground(Color.white.opacity(0.04))
                //     // }
                // }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.05, green: 0.06, blue: 0.1))
            .navigationTitle("Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newSubjectName = ""
                        isShowingAddPrompt = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.white)
                    }
                }
            }
            .alert("New Subject", isPresented: $isShowingAddPrompt) {
                TextField("e.g. Math", text: $newSubjectName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let result = subjectStore.addSubject(named: newSubjectName)
                    if case .limitReached = result {
                        // Release override safety: auto-disable gating and retry add.
                        subjectStore.setProGatingEnabled(false)
                        _ = subjectStore.addSubject(named: newSubjectName)
                    }
                }
            } message: {
                Text("Type a subject name or leave blank to auto-name.")
            }
            .alert("Rename Subject", isPresented: $isShowingRenamePrompt) {
                TextField("Subject name", text: $renameSubjectName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let subjectID = renamingSubjectID {
                        subjectStore.renameSubject(id: subjectID, to: renameSubjectName)
                    }
                }
            } message: {
                Text("Update the subject name.")
            }
            .sheet(
                isPresented: Binding(
                    get: { editingTimetableSubjectID != nil },
                    set: { isPresented in
                        if isPresented == false {
                            editingTimetableSubjectID = nil
                        }
                    }
                )
            ) {
                if let subjectID = editingTimetableSubjectID {
                    TimetableEditorSheet(
                        subjectStore: subjectStore,
                        subjectID: subjectID
                    )
                    .preferredColorScheme(.dark)
                }
            }
        }
    }
}

private struct TimetableEditorSheet: View {
    @ObservedObject var subjectStore: SubjectStore
    let subjectID: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var schedule: WeeklySchedule = .empty
    @State private var projectionWeeks = 1
    @State private var holidayClassCount = 0
    @State private var expectedAbsences = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Weekly Classes") {
                    dayStepper("Monday", value: $schedule.monday)
                    dayStepper("Tuesday", value: $schedule.tuesday)
                    dayStepper("Wednesday", value: $schedule.wednesday)
                    dayStepper("Thursday", value: $schedule.thursday)
                    dayStepper("Friday", value: $schedule.friday)
                    dayStepper("Saturday", value: $schedule.saturday)
                    dayStepper("Sunday", value: $schedule.sunday)
                }

                Section("Summary") {
                    HStack {
                        Text("Total classes / week")
                        Spacer()
                        Text("\(schedule.totalPerWeek)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }

                    Button("Set subject total classes = weekly total") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyWeeklySchedule(for: subjectID, addToExisting: false)
                    }

                    Button("Add one full week to total classes") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyWeeklySchedule(for: subjectID, addToExisting: true)
                    }
                }

                Section("Auto-Mark Expected Classes") {
                    Stepper("Weeks to project: \(projectionWeeks)", value: $projectionWeeks, in: 1...16)
                    Stepper("Holiday classes to exclude: \(holidayClassCount)", value: $holidayClassCount, in: 0...80)
                    Stepper("Expected absences: \(expectedAbsences)", value: $expectedAbsences, in: 0...80)

                    let expected = CalculationService.projectedTotalClasses(
                        schedule: schedule,
                        weeks: projectionWeeks,
                        holidayClassCount: holidayClassCount
                    )
                    let expectedAttended = max(0, expected - min(expectedAbsences, expected))

                    Text("Projected classes: \(expected), projected attended: \(expectedAttended)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Button("Apply projection to existing totals") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyProjectedSchedule(
                            for: subjectID,
                            weeks: projectionWeeks,
                            holidayClassCount: holidayClassCount,
                            expectedAbsences: expectedAbsences,
                            addToExisting: true
                        )
                    }

                    Button("Replace totals with projection") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        subjectStore.applyProjectedSchedule(
                            for: subjectID,
                            weeks: projectionWeeks,
                            holidayClassCount: holidayClassCount,
                            expectedAbsences: expectedAbsences,
                            addToExisting: false
                        )
                    }
                }
            }
            .navigationTitle("Timetable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        subjectStore.updateWeeklySchedule(for: subjectID, schedule: schedule)
                        dismiss()
                    }
                }
            }
            .onAppear {
                schedule = subjectStore.weeklySchedule(for: subjectID)
            }
        }
    }

    private func dayStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 0...12) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
        }
    }
}
