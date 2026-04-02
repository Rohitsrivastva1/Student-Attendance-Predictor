//
//  HomeView.swift
//  Student Attendance Predictor
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var selectedScenario: ScenarioAction = .current

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
            .onChange(of: viewModel.totalClassesInput) { _ in
                selectedScenario = .current
            }
            .onChange(of: viewModel.attendedClassesInput) { _ in
                selectedScenario = .current
            }
            .onChange(of: viewModel.requiredPercentageInput) { _ in
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

                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(8)
                    .background(Circle().fill(.white))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
            }

            Text("Live guidance updates as you type. No calculate step needed.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                VStack(spacing: 12) {
                    heroCard(for: result)
                    scenarioSection(baseResult: viewModel.result, displayedResult: result)

                    HStack(alignment: .top, spacing: 10) {
                        progressCard(for: result)

                        VStack(spacing: 10) {
                            ResultCardView(
                                title: "You can skip",
                                value: "\(result.bunkAllowed)",
                                subtitle: "classes and stay safe",
                                tint: .primary,
                                alignment: .center
                            )
                            ResultCardView(
                                title: "Need to attend",
                                value: "\(result.recoveryNeeded)",
                                subtitle: "classes to recover",
                                tint: .primary,
                                alignment: .center
                            )
                        }
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

            TextField(title, text: text)
                .applyKeyboardType(keyboardType)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fieldBackgroundColor)
                )
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
        Text("Google AdMob Placement")
            .font(.system(size: 17, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.95))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.43, blue: 0.48), Color(red: 0.25, green: 0.26, blue: 0.30)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }

    private func heroCard(for result: AttendanceResult) -> some View {
        let isSafe = result.status == .safe
        let statusColor = isSafe ? Color.green : Color.red

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
                        colors: [statusColor.opacity(0.92), statusColor.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: statusColor.opacity(0.22), radius: 12, x: 0, y: 6)
    }

    private func scenarioSection(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick simulate")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(ScenarioAction.allCases) { scenario in
                    Button {
                        selectedScenario = scenario
                    } label: {
                        Text(scenario.label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedScenario == scenario ? .white : .blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selectedScenario == scenario ? Color.blue : .white)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.blue.opacity(selectedScenario == scenario ? 0 : 0.22), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: max(28, geometry.size.width * min(max(result.currentPercentage / 100, 0), 1)))
                    }
            }
            .frame(height: 10)

            Text("Target \(Int(viewModel.requiredPercentage))%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
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

        return "You need \(result.recoveryNeeded) classes to be safe"
    }

    private func heroSubtitle(for result: AttendanceResult) -> String {
        if result.status == .safe {
            return "Current attendance is \(String(format: "%.1f%%", result.currentPercentage)). Stay above your required threshold."
        }

        return "Current attendance is \(String(format: "%.1f%%", result.currentPercentage)). Attend the next few classes to recover."
    }

    private func scenarioInsight(baseResult: AttendanceResult?, displayedResult: AttendanceResult) -> String {
        guard selectedScenario != .current, let baseResult else {
            return "Results update instantly while you type, so there is no separate calculate step."
        }

        let delta = displayedResult.currentPercentage - baseResult.currentPercentage
        let direction = delta >= 0 ? "up" : "down"
        return "This scenario moves your attendance \(direction) by \(String(format: "%.1f", abs(delta))) points."
    }

    private var screenBackgroundColor: Color {
        Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    private var fieldBackgroundColor: Color {
        Color(red: 0.94, green: 0.95, blue: 0.97)
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
