//
//  ToolScreens.swift
//  Student Attendance Predictor
//
//  Standalone tool screens linked from the Tools hub.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Skip Planner

struct SkipPlannerToolScreen: View {
    @ObservedObject var subjectStore: SubjectStore
    @ObservedObject private var entitlements = AdEntitlementsStore.shared

    @State private var selectedDay: Date?
    @State private var isShowingProPaywall = false

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let green = Color(red: 0.2, green: 0.9, blue: 0.5)
    private var skipVerb: String { StudentMarketStore.current.skipVerb }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SkipPlannerWeekCard(
                    subjects: subjectStore.subjects,
                    isPro: entitlements.isPro,
                    onUnlock: presentSkipPlannerPaywall,
                    onSelectDay: { selectedDay = $0 }
                )

                if entitlements.isPro {
                    rankedSkipDaysSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Skip Planner")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: Binding(
                get: { selectedDay != nil },
                set: { if $0 == false { selectedDay = nil } }
            )
        ) {
            if let day = selectedDay {
                SkipPlannerSheet(
                    result: SkipPlanner.evaluate(date: day, subjects: subjectStore.subjects)
                )
            }
        }
        .sheet(isPresented: $isShowingProPaywall) {
            ProPaywallView(source: "skip_planner")
        }
        .onAppear {
            AnalyticsService.shared.setScreen(.skipPlannerTool)
        }
    }

    private var rankedSkipDaysSection: some View {
        let ranked = SkipPlanner.rankedSkipDays(subjects: subjectStore.subjects, limit: 5)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Safest days this week")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if ranked.isEmpty {
                Text("Add a weekly timetable to see ranked \(skipVerb) days.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(Array(ranked.enumerated()), id: \.element.date.timeIntervalSince1970) { index, result in
                    rankedDayRow(rank: index + 1, result: result)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(cyan.opacity(0.85))
                Text("Ask Siri “Safest day to \(skipVerb) this week” via Shortcuts.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(toolCardBackground)
    }

    private func rankedDayRow(rank: Int, result: SkipPlannerResult) -> some View {
        let tint: Color = {
            switch result.riskLevel {
            case .safe: return green
            case .mixed: return .orange
            case .unsafe: return .red
            case .noClass: return .white.opacity(0.4)
            }
        }()

        return Button {
            selectedDay = result.date
        } label: {
            HStack(spacing: 12) {
                Text("#\(rank)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(cyan)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(result.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(result.totalClasses) class\(result.totalClasses == 1 ? "" : "es") · \(result.safeCount) safe")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    private func presentSkipPlannerPaywall() {
        AnalyticsService.shared.log(.skipPlannerLocked)
        AnalyticsService.shared.log(.proCtaTapped(surface: "skip_planner", action: "go_pro"))
        isShowingProPaywall = true
    }
}

// MARK: - Semester Forecast

struct SemesterForecastToolScreen: View {
    @ObservedObject var subjectStore: SubjectStore
    @ObservedObject private var entitlements = AdEntitlementsStore.shared

    @State private var forecastWeeks = SemesterSettings.weeksRemaining()
    @State private var forecastHolidayClasses = ForecastAssumptions.holidayClassCount
    @State private var forecastExpectedAbsences = ForecastAssumptions.plannedBunks
    @State private var forecastClassesPerWeek = ForecastAssumptions.fallbackClassesPerWeek
    @State private var expandedForecastSubjectIDs: Set<UUID> = []
    @State private var isShowingProPaywall = false

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private var skipVerb: String { StudentMarketStore.current.skipVerb }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let progress = SemesterSettings.progress() {
                    SemesterProgressStrip(progress: progress)
                }

                if entitlements.isForecastUnlocked {
                    unlockedForecastContent
                } else {
                    lockedForecastContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Semester Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingProPaywall) {
            ProPaywallView(source: "forecast")
        }
        .onAppear {
            AnalyticsService.shared.setScreen(.semesterForecastTool)
            SemesterSettings.ensureDefaultDatesIfNeeded()
            refreshForecastAssumptions()
            if entitlements.isForecastUnlocked {
                AnalyticsService.shared.log(.forecastViewed)
            } else {
                AnalyticsService.shared.log(.lockedForecastViewed)
                AnalyticsService.shared.logProCtaShownOnce(surface: "locked_forecast")
            }
        }
        .onChange(of: forecastHolidayClasses) { _, value in
            ForecastAssumptions.holidayClassCount = value
        }
        .onChange(of: forecastExpectedAbsences) { _, value in
            ForecastAssumptions.plannedBunks = value
        }
        .onChange(of: forecastClassesPerWeek) { _, value in
            ForecastAssumptions.fallbackClassesPerWeek = value
        }
    }

    private var unlockedForecastContent: some View {
        let forecasts = subjectStore.subjectForecasts(
            weeks: forecastWeeks,
            holidayClassCount: forecastHolidayClasses,
            expectedAbsences: forecastExpectedAbsences,
            fallbackClassesPerWeek: forecastClassesPerWeek
        )

        return VStack(alignment: .leading, spacing: 18) {
            plannedBunksInput

            assumptionsSummary

            VStack(alignment: .leading, spacing: 12) {
                Text("Projected Attendance")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if forecasts.isEmpty {
                    Text("Add a subject with attendance to see projections.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                } else {
                    ForEach(forecasts) { item in
                        forecastRow(for: item)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(toolCardBackground)
    }

    private var lockedForecastContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(cyan)
                Text("SUBJECT FORECAST")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .tracking(1.1)
            }

            Text("See where each subject lands by the end of the semester — and which ones may fall below target.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            Button {
                AnalyticsService.shared.log(.proCtaTapped(surface: "locked_forecast", action: "go_pro"))
                isShowingProPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Go Pro · Unlock forecast forever")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.86, blue: 0.42),
                                    Color(red: 0.95, green: 0.58, blue: 0.18)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(toolCardBackground)
    }

    private var plannedBunksInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How many classes do you plan to miss?")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 18) {
                Button {
                    forecastExpectedAbsences = max(0, forecastExpectedAbsences - 1)
                } label: {
                    stepperCircle(icon: "minus")
                }
                .buttonStyle(.plain)

                Text("\(forecastExpectedAbsences)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(cyan)
                    .frame(minWidth: 64)

                Button {
                    forecastExpectedAbsences = min(80, forecastExpectedAbsences + 1)
                } label: {
                    stepperCircle(icon: "plus")
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }

            Text("Classes you plan to miss this semester")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(cyan.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private var assumptionsSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast assumptions")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(forecastWeeks) weeks left · \(forecastHolidayClasses) holidays · \(forecastClassesPerWeek)/week fallback")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func forecastRow(for item: SubjectForecast) -> some View {
        let isExpanded = expandedForecastSubjectIDs.contains(item.id)
        let statusColor = colorForRiskLevel(item.riskLevel)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if isExpanded {
                        expandedForecastSubjectIDs.remove(item.id)
                    } else {
                        expandedForecastSubjectIDs.insert(item.id)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.subjectName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(item.primaryActionMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(String(format: "%.0f%%", item.forecastedPercentage))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(item.willFallBelowTarget ? Color.orange : .white)
                        forecastStatusBadge(item.riskLevel, color: statusColor)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().overlay(Color.white.opacity(0.08))
                    Text(forecastDetailMessage(for: item))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func forecastDetailMessage(for item: SubjectForecast) -> String {
        let target = Int(item.requiredPercentage.rounded())
        switch item.riskLevel {
        case .stable:
            if item.bunkAllowedAfterProjection > 0 {
                let bunks = item.bunkAllowedAfterProjection
                return "Projected at \(String(format: "%.0f", item.forecastedPercentage))%. You can safely \(skipVerb) \(bunks) more class\(bunks == 1 ? "" : "es")."
            }
            return "No change expected — you're set to stay above \(target)%."
        case .warning:
            return "Still above \(target)% for now, but your buffer is thin."
        case .critical:
            return "Projected below your \(target)% target."
        }
    }

    private func refreshForecastAssumptions() {
        forecastWeeks = SemesterSettings.weeksRemaining()
        forecastHolidayClasses = ForecastAssumptions.holidayClassCount
        forecastExpectedAbsences = ForecastAssumptions.plannedBunks
        forecastClassesPerWeek = ForecastAssumptions.fallbackClassesPerWeek
        if let any = subjectStore.subjects.first(where: { $0.weeklySchedule.totalPerWeek > 0 }) {
            forecastClassesPerWeek = any.weeklySchedule.totalPerWeek
        }
    }

    private func stepperCircle(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.white.opacity(0.1)))
    }

    private func forecastStatusBadge(_ level: RiskAlertLevel, color: Color) -> some View {
        Text(level.rawValue)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule(style: .continuous).fill(color.opacity(0.16)))
    }

    private func colorForRiskLevel(_ level: RiskAlertLevel) -> Color {
        switch level {
        case .stable: return Color(red: 0.2, green: 0.9, blue: 0.5)
        case .warning: return Color(red: 1.0, green: 0.84, blue: 0.2)
        case .critical: return Color(red: 1.0, green: 0.35, blue: 0.4)
        }
    }
}

// MARK: - Export Reports

struct ExportToolScreen: View {
    @ObservedObject var subjectStore: SubjectStore
    @ObservedObject var gpaStore: GPAStore
    @ObservedObject private var entitlements = AdEntitlementsStore.shared

    @State private var isExportingPDF = false
    @State private var shareItems: [Any] = []
    @State private var isShowingShareSheet = false
    @State private var exportErrorMessage: String?
    @State private var isShowingProPaywall = false
    @State private var proPaywallSource = "pdf_export"

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)
    private let gold = Color(red: 1.0, green: 0.78, blue: 0.28)
    private var market: StudentMarket { StudentMarketStore.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Share a polished PDF summary or a CSV log of every attendance entry.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))

                exportButton(
                    icon: "doc.richtext",
                    tint: cyan,
                    title: "PDF Report",
                    subtitle: pdfSubtitle,
                    isLocked: !entitlements.isPro,
                    isLoading: isExportingPDF,
                    action: exportPDF
                )

                exportButton(
                    icon: "tablecells",
                    tint: gold,
                    title: "CSV Log",
                    subtitle: csvSubtitle,
                    isLocked: !entitlements.isPro,
                    isLoading: false,
                    action: exportCSV
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Export Reports")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingShareSheet) {
            ToolShareActivityView(activityItems: shareItems)
        }
        .sheet(isPresented: $isShowingProPaywall) {
            ProPaywallView(source: proPaywallSource)
        }
        .alert("Export", isPresented: exportAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .onAppear {
            AnalyticsService.shared.setScreen(.exportReportsTool)
        }
    }

    private var pdfSubtitle: String {
        if subjectStore.subjects.isEmpty {
            return "Add subjects to export"
        }
        return entitlements.isPro
            ? "Attendance summary\(gpaStore.courses.isEmpty ? "" : " + grades")"
            : "Pro · attendance summary PDF"
    }

    private var csvSubtitle: String {
        if subjectStore.subjects.isEmpty {
            return "Add subjects to export"
        }
        return entitlements.isPro
            ? "Full attendance log for spreadsheets"
            : "Pro · CSV attendance log"
    }

    private var exportAlertPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { if $0 == false { exportErrorMessage = nil } }
        )
    }

    private func exportButton(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        isLocked: Bool,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 48, height: 48)
                    if isLoading {
                        ProgressView().tint(tint)
                    } else {
                        Image(systemName: isLocked ? "lock.fill" : icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(tint)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.28))
            }
            .padding(14)
            .background(toolCardBackground)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || subjectStore.subjects.isEmpty)
        .opacity(subjectStore.subjects.isEmpty ? 0.45 : 1)
    }

    private func exportPDF() {
        AnalyticsService.shared.log(.pdfExportTapped)
        guard entitlements.isPro else {
            proPaywallSource = "pdf_export"
            isShowingProPaywall = true
            return
        }

        #if canImport(UIKit)
        isExportingPDF = true
        Task { @MainActor in
            defer { isExportingPDF = false }
            do {
                let url = try AttendanceReportPDF.makeFile(
                    subjects: subjectStore.subjects,
                    summary: subjectStore.dashboardSummary,
                    grades: gpaStore.makeGradesReportSnapshot(market: market)
                )
                let caption = gpaStore.courses.isEmpty
                    ? "My attendance summary from Bunk Planner."
                    : "My attendance & grades summary from Bunk Planner."
                shareItems = [url, caption]
                isShowingShareSheet = true
                AnalyticsService.shared.log(.pdfExportShared(subjectCount: subjectStore.subjects.count))
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
        #endif
    }

    private func exportCSV() {
        AnalyticsService.shared.log(.csvExportTapped)
        guard entitlements.isPro else {
            proPaywallSource = "csv_export"
            isShowingProPaywall = true
            return
        }

        do {
            let result = try AttendanceLogCSV.makeFile(
                entries: subjectStore.allLogEntries(),
                subjects: subjectStore.subjects
            )
            shareItems = [result.url, "My attendance log from Bunk Planner."]
            isShowingShareSheet = true
            AnalyticsService.shared.log(.csvExportShared(rowCount: result.rowCount))
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared helpers

private var toolCardBackground: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
}

#if canImport(UIKit)
private struct ToolShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed == false {
                AnalyticsService.shared.log(.shareCancelled)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
