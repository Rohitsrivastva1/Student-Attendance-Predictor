//
//  HomeView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var selectedScenario: ScenarioAction = .current
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerSection
                    inputSection
                    resultSection
                    adPlaceholder
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(screenBackgroundColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: viewModel.totalClassesInput) { _, _ in
                selectedScenario = .current
            }
            .onChange(of: viewModel.attendedClassesInput) { _, _ in
                selectedScenario = .current
            }
            .onChange(of: viewModel.requiredPercentageInput) { _, _ in
                selectedScenario = .current
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Attendance Predictor")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("Input Data")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.82))
                }

                Spacer()

                Button {
                    triggerLightHaptic()
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(10)
                        .background(Circle().fill(.white))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsSheetView(viewModel: viewModel)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            inputField(title: "Total Classes Hosted", text: $viewModel.totalClassesInput, keyboardType: .numberPad)
            inputField(title: "Classes Attended", text: $viewModel.attendedClassesInput, keyboardType: .numberPad)
            inputField(title: "Required Minimum (%)", text: $viewModel.requiredPercentageInput, keyboardType: .decimalPad)

            validationBanner
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        )
    }

    private var resultSection: some View {
        Group {
            if let result = displayResult {
                VStack(spacing: 16) {
                    heroCard(for: result)
                    scenarioSection(baseResult: viewModel.result, displayedResult: result)

                    HStack(alignment: .top, spacing: 10) {
                        progressCard(for: result)
                        ResultCardView(
                            title: result.status == .safe ? "Best next move" : "Recovery plan",
                            value: actionSummary(for: result),
                            subtitle: planSubtitle(for: result),
                            tint: result.status == .safe ? .green : .orange,
                            alignment: .center,
                            isEmphasized: true
                        )
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedScenario)
            } else {
                placeholderSection
            }
        }
    }

    private func inputField(title: String, text: Binding<String>, keyboardType: KeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.82))

            HStack(spacing: 10) {
                stepperButton(symbol: "minus", text: text, keyboardType: keyboardType, delta: -1)

                TextField(title, text: text)
                    .applyKeyboardType(keyboardType)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(fieldBackgroundColor)
                    )

                stepperButton(symbol: "plus", text: text, keyboardType: keyboardType, delta: 1)
            }
        }
    }

    private var validationBanner: some View {
        Group {
            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
            }
        }
    }

    private var placeholderSection: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.white)
            .frame(height: 132)
            .overlay {
                Text("Enter your class data to see live attendance guidance.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding()
            }
            .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 5)
    }

    private var adPlaceholder: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Text("Ad")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Sponsored banner")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("AdMob banner will appear here")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
    }

    private func heroCard(for result: AttendanceResult) -> some View {
        let isSafe = result.status == .safe
        let primaryStatusColor = isSafe ? Color.green : Color(red: 0.92, green: 0.29, blue: 0.22)
        let secondaryStatusColor = isSafe ? Color(red: 0.28, green: 0.74, blue: 0.48) : Color.orange

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: isSafe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(isSafe ? "SAFE" : "RISK")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(heroTitle(for: result))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(heroSubtitle(for: result))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))

            progressBar(for: result)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primaryStatusColor.opacity(0.94), secondaryStatusColor.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: primaryStatusColor.opacity(0.22), radius: 12, x: 0, y: 6)
    }

    private func scenarioSection(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick simulate")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Try different scenarios instantly")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(ScenarioAction.allCases) { scenario in
                    Button {
                        triggerLightHaptic()
                        selectedScenario = scenario
                    } label: {
                        let isSelected = selectedScenario == scenario

                        Text(scenario.label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSelected ? Color.blue : .white)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.blue.opacity(isSelected ? 0 : 0.22), lineWidth: 1)
                            }
                            .scaleEffect(isSelected ? 1.02 : 1.0)
                            .shadow(color: isSelected ? Color.blue.opacity(0.18) : Color.black.opacity(0.04), radius: isSelected ? 10 : 4, x: 0, y: isSelected ? 5 : 2)
                            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isSelected)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }

            Text(scenarioInsight(baseResult: baseResult, displayedResult: displayedResult))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func progressCard(for result: AttendanceResult) -> some View {
        let progress = min(max(result.currentPercentage / 100, 0), 1)
        let ringColor = result.status == .safe ? Color.green : Color.red

        return VStack(spacing: 10) {
            Text("\(Int(result.currentPercentage.rounded()))%")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(ringColor)
                .frame(width: 88, height: 88)
                .background(
                    Circle()
                        .fill(ringColor.opacity(0.08))
                )
                .overlay {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(4)
                }

            Text("Current attendance")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 124)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 5)
        )
    }

    private func progressBar(for result: AttendanceResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                let currentWidth = geometry.size.width * min(max(result.currentPercentage / 100, 0), 1)
                let targetWidth = geometry.size.width * min(max(viewModel.requiredPercentage / 100, 0), 1)

                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: max(28, currentWidth))
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 3, height: 18)
                            .offset(x: max(0, min(targetWidth, geometry.size.width - 2)))
                    }
            }
            .frame(height: 10)

            HStack(spacing: 8) {
                Text("Current \(Int(result.currentPercentage.rounded()))%")
                Spacer()
                Text("Target \(Int(viewModel.requiredPercentage))%")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.94))

            Text(gapLabel(for: result))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
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
        if result.status == .safe {
            return result.bunkAllowed > 0
                ? "You can skip \(result.bunkAllowed) classes"
                : "You are exactly on the safe line"
        }

        return "Attend the next \(result.recoveryNeeded) classes to reach \(Int(viewModel.requiredPercentage))%"
    }

    private func heroSubtitle(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return "Current attendance is \(String(format: "%.1f%%", result.currentPercentage)). Stay above your required threshold."
        }

        return "Current attendance is \(String(format: "%.1f%%", result.currentPercentage)). Attend the next \(result.recoveryNeeded) classes without skipping."
    }

    private func scenarioInsight(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> String {
        let percentageText = String(format: "%.0f%%", displayedResult.currentPercentage)
        let statusText = displayedResult.status == .safe ? "Still safe" : "At risk"

        guard selectedScenario != .current, let _ = baseResult else {
            if displayedResult.status == .safe {
                return "You're at \(percentageText) — well above target"
            }

            return "Attend the next \(displayedResult.recoveryNeeded) classes to reach \(Int(viewModel.requiredPercentage))%"
        }

        if displayedResult.status == .safe {
            return "After \(selectedScenario.description) -> \(percentageText) (\(statusText))"
        }

        return "After \(selectedScenario.description) -> attend the next \(displayedResult.recoveryNeeded) classes to reach \(Int(viewModel.requiredPercentage))%"
    }

    private func actionSummary(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return "Skip \(result.bunkAllowed) classes safely"
        }

        return "Attend the next \(result.recoveryNeeded) classes"
    }

    private func planSubtitle(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return "You are above the required threshold"
        }

        return "Reach \(Int(viewModel.requiredPercentage))% without skipping"
    }

    private func gapLabel(for result: AttendanceResult) -> String {
        let gap = max(0, viewModel.requiredPercentage - result.currentPercentage)
        if gap == 0 {
            return "Gap to target: 0%"
        }

        return "Gap to target: \(String(format: "%.1f%%", gap))"
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
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.blue)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.10))
                )
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

    private var screenBackgroundColor: Color {
        Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var fieldBackgroundColor: Color {
        Color(red: 0.94, green: 0.95, blue: 0.97)
    }

    private func triggerLightHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview {
    HomeView()
}

enum KeyboardType {
    case numberPad
    case decimalPad
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
            return "current attendance"
        case .skipOne:
            return "skipping 1 class"
        case .skipThree:
            return "skipping 3 classes"
        case .attendFive:
            return "attending 5 classes"
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
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
