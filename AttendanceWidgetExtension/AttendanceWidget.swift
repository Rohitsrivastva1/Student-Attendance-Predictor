//
//  AttendanceWidget.swift
//  AttendanceWidgetExtension
//

import SwiftUI
import WidgetKit
import AppIntents

enum AttendanceWidgetStatus {
    case safe
    case risk
}

struct RiskSubjectSummary: Codable, Hashable {
    let id: String
    let name: String
    let currentPercentage: Double
    let requiredPercentage: Double
    let recoveryNeeded: Int
    let shortfall: Double
}

struct AttendanceEntry: TimelineEntry {
    let date: Date
    let subjectID: String
    let subjectName: String
    let currentPercentage: Double
    let status: AttendanceWidgetStatus
    let bunkAllowed: Int
    let recoveryNeeded: Int
    let lastUpdated: Date
    let isPlaceholder: Bool
    let mode: WidgetDisplayMode
    let riskSubjects: [RiskSubjectSummary]
}

struct AttendanceProvider: AppIntentTimelineProvider {
    private let appGroupID = "group.com.schoolabe.attendancepredictor"

    func placeholder(in context: Context) -> AttendanceEntry {
        AttendanceEntry(
            date: Date(),
            subjectID: "",
            subjectName: "Mathematics",
            currentPercentage: 76,
            status: .safe,
            bunkAllowed: 3,
            recoveryNeeded: 0,
            lastUpdated: Date(),
            isPlaceholder: true,
            mode: .lastActive,
            riskSubjects: []
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> AttendanceEntry {
        readEntry(mode: configuration.mode)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<AttendanceEntry> {
        let entry = readEntry(mode: configuration.mode)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func readEntry(mode: WidgetDisplayMode) -> AttendanceEntry {
        let ud = UserDefaults(suiteName: appGroupID)
        let subjectID = ud?.string(forKey: "widget_subjectID") ?? ""
        let attended = ud?.integer(forKey: "widget_attendedClasses") ?? 0
        let total = ud?.integer(forKey: "widget_totalClasses") ?? 0
        let required = ud?.double(forKey: "widget_requiredPercentage") ?? 75.0
        let name = ud?.string(forKey: "widget_subjectName") ?? "—"
        let ts = ud?.double(forKey: "widget_lastUpdated") ?? 0
        let lastUpdated = Date(timeIntervalSince1970: ts)

        let riskSubjects = decodeRiskSubjects(ud: ud)
        let hasData = ts > 0 && total > 0 && name != "—"
        guard hasData else {
            return AttendanceEntry(
                date: Date(),
                subjectID: "",
                subjectName: "—",
                currentPercentage: 0,
                status: .risk,
                bunkAllowed: 0,
                recoveryNeeded: 0,
                lastUpdated: Date(),
                isPlaceholder: true,
                mode: mode,
                riskSubjects: riskSubjects
            )
        }

        let percentage = (Double(attended) / Double(total)) * 100
        let status: AttendanceWidgetStatus = percentage >= required ? .safe : .risk
        let bunkAllowed = maxBunk(attended: attended, total: total, required: required)
        let recoveryNeeded = requiredClasses(attended: attended, total: total, required: required)

        return AttendanceEntry(
            date: Date(),
            subjectID: subjectID,
            subjectName: name,
            currentPercentage: percentage,
            status: status,
            bunkAllowed: bunkAllowed,
            recoveryNeeded: recoveryNeeded,
            lastUpdated: lastUpdated,
            isPlaceholder: false,
            mode: mode,
            riskSubjects: riskSubjects
        )
    }

    private func decodeRiskSubjects(ud: UserDefaults?) -> [RiskSubjectSummary] {
        guard
            let data = ud?.data(forKey: "widget_allSubjects"),
            let rawSubjects = try? JSONDecoder().decode([WidgetSharedSubject].self, from: data)
        else {
            return []
        }

        let riskOnly = rawSubjects.compactMap { subject -> RiskSubjectSummary? in
            guard subject.totalClasses > 0 else { return nil }
            let percentage = (Double(subject.attendedClasses) / Double(subject.totalClasses)) * 100
            let shortfall = max(0, subject.requiredPercentage - percentage)
            guard shortfall > 0 else { return nil }
            return RiskSubjectSummary(
                id: subject.id,
                name: subject.name,
                currentPercentage: percentage,
                requiredPercentage: subject.requiredPercentage,
                recoveryNeeded: requiredClasses(
                    attended: subject.attendedClasses,
                    total: subject.totalClasses,
                    required: subject.requiredPercentage
                ),
                shortfall: shortfall
            )
        }

        return riskOnly
            .sorted { lhs, rhs in
                if lhs.shortfall == rhs.shortfall {
                    return lhs.recoveryNeeded > rhs.recoveryNeeded
                }
                return lhs.shortfall > rhs.shortfall
            }
    }

    private func maxBunk(attended: Int, total: Int, required: Double) -> Int {
        guard total >= 0, attended >= 0 else { return 0 }
        guard required > 0 else { return Int.max }
        let requiredRatio = required / 100
        guard Double(attended) / Double(max(total, 1)) >= requiredRatio || total == 0 else { return 0 }
        let maxAllowed = (Double(attended) / requiredRatio) - Double(total)
        return max(0, Int(floor(maxAllowed)))
    }

    private func requiredClasses(attended: Int, total: Int, required: Double) -> Int {
        guard total >= 0, attended >= 0 else { return 0 }
        guard required > 0 else { return 0 }
        if total == 0 { return 1 }
        let current = Double(attended) / Double(total)
        let requiredRatio = required / 100
        guard current < requiredRatio else { return 0 }
        let numerator = (requiredRatio * Double(total)) - Double(attended)
        let denominator = 1 - requiredRatio
        guard denominator > 0 else { return Int.max }
        return max(0, Int(ceil(numerator / denominator)))
    }
}

struct BunkWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AttendanceEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            case .accessoryCircular:
                circularView
            default:
                smallView
            }
        }
        .widgetURL(deepLinkURL)
    }

    private var deepLinkURL: URL? {
        let subjectIDForTap: String
        if (family == .systemMedium || family == .systemLarge),
           entry.mode == .allRiskLarge,
           let risky = entry.riskSubjects.first {
            subjectIDForTap = risky.id
        } else {
            subjectIDForTap = entry.subjectID
        }
        guard subjectIDForTap.isEmpty == false else { return URL(string: "bunkplanner://widget-tap") }
        return URL(string: "bunkplanner://widget-tap?subjectID=\(subjectIDForTap)")
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.1),
                Color(red: 0.08, green: 0.1, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var smallView: some View {
        VStack(spacing: 12) {
            if entry.isPlaceholder {
                Text("Open app\nto calculate")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            } else {
                Text("\(Int(entry.currentPercentage.rounded()))%")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.3), radius: 6, x: 0, y: 0)
                statusPill
            }
            Spacer(minLength: 0)
            Text("Bunk Planner")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1.1)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    @ViewBuilder
    private var mediumView: some View {
        if entry.mode == .allRiskLarge {
            riskFocusMediumView
        } else {
            lastActiveMediumView
        }
    }

    @ViewBuilder
    private var largeView: some View {
        if entry.mode == .allRiskLarge {
            allRiskLargeView
        } else {
            VStack(spacing: 12) {
                lastActiveMediumView
                Divider().background(Color.white.opacity(0.1))
                Text("Switch mode to \"All Risk Subjects (Large)\" for a multi-subject risk list.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .containerBackground(for: .widget) {
                widgetBackground
            }
        }
    }

    private var lastActiveMediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                if entry.isPlaceholder {
                    Text("Open app to calculate")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                } else {
                    Text("\(Int(entry.currentPercentage.rounded()))%")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.3), radius: 6, x: 0, y: 0)
                    statusPill
                }
                Spacer()
            }

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 8) {
                if entry.isPlaceholder {
                    Text("No subject data yet")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Run one calculation in app")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text(entry.subjectName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.status == .safe ? "Bunks left: \(entry.bunkAllowed)" : "Attend next: \(entry.recoveryNeeded)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("Updated \(entry.lastUpdated, style: .time)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var riskFocusMediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RISK FOCUS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.4))
                .tracking(1.1)

            if entry.riskSubjects.isEmpty {
                Text("No risky subjects right now")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("All tracked subjects are safe.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(Array(entry.riskSubjects.prefix(2)), id: \.id) { subject in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(subject.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(Int(subject.currentPercentage.rounded()))% • need \(subject.recoveryNeeded) classes")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    if subject.id != entry.riskSubjects.prefix(2).last?.id {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var allRiskLargeView: some View {
        let topThree = Array(entry.riskSubjects.prefix(3))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RISK SUBJECTS")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.4))
                    .tracking(1.1)
                Spacer()
                Text("TOP \(topThree.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            if topThree.isEmpty {
                Text("No risky subjects right now")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("All tracked subjects are safe.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(topThree.indices, id: \.self) { index in
                    let subject = topThree[index]
                    HStack(alignment: .center, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.4).opacity(0.8))
                            .frame(width: 20, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(subject.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(Int(subject.currentPercentage.rounded()))% • Need \(subject.recoveryNeeded) classes")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    if index < topThree.count - 1 {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }

            Spacer(minLength: 0)
            Text("Updated \(entry.lastUpdated, style: .time)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(20)
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var circularView: some View {
        let currentWidth = CGFloat(entry.currentPercentage) / 100.0
        let ringColor = entry.status == .safe ? Color(red: 0.12, green: 0.82, blue: 0.46) : Color(red: 1.0, green: 0.3, blue: 0.4)
        
        return ZStack {
            widgetBackground
            
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
                .padding(4)
                
            Circle()
                .trim(from: 0, to: entry.isPlaceholder ? 0 : currentWidth)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(4)
                .shadow(color: ringColor.opacity(0.4), radius: 3, x: 0, y: 0)
                
            Text(entry.isPlaceholder ? "--" : "\(Int(entry.currentPercentage.rounded()))")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var statusPill: some View {
        let isSafe = entry.status == .safe
        let accentColor = isSafe ? Color(red: 0.12, green: 0.82, blue: 0.46) : Color(red: 1.0, green: 0.2, blue: 0.4)
        return Text(isSafe ? "SAFE" : "AT RISK")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(accentColor)
            .tracking(1.1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.15))
                    .overlay(
                        Capsule().stroke(accentColor.opacity(0.35), lineWidth: 1)
                    )
            )
            .shadow(color: accentColor.opacity(0.25), radius: 4, x: 0, y: 0)
    }
}

struct BunkPlannerWidget: Widget {
    let kind = "BunkPlannerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: AttendanceProvider()) { entry in
            BunkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Bunk Planner")
        .description("Last active or all-risk subjects at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular])
    }
}

private struct WidgetSharedSubject: Codable {
    let id: String
    let name: String
    let attendedClasses: Int
    let totalClasses: Int
    let requiredPercentage: Double
}
