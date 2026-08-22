//
//  BunkPlannerWidgets.swift
//  BunkPlannerWidgets
//

import WidgetKit
import SwiftUI

struct AttendanceEntry: TimelineEntry {
    let date: Date
    let percentage: Double
    let bunksLeft: Int
    let subjectName: String
    let isSafe: Bool
    let hasData: Bool
}

struct AttendanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> AttendanceEntry {
        AttendanceEntry(
            date: Date(),
            percentage: 82,
            bunksLeft: 4,
            subjectName: "Math",
            isSafe: true,
            hasData: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AttendanceEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttendanceEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> AttendanceEntry {
        AttendanceEntry(
            date: Date(),
            percentage: WidgetSnapshotReader.percentage,
            bunksLeft: WidgetSnapshotReader.bunksLeft,
            subjectName: WidgetSnapshotReader.subjectName,
            isSafe: WidgetSnapshotReader.isSafe,
            hasData: WidgetSnapshotReader.hasData
        )
    }
}

struct BunkPlannerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: AttendanceEntry

    private var accent: Color {
        entry.isSafe ? Color(red: 0.2, green: 0.85, blue: 0.5) : Color(red: 1.0, green: 0.4, blue: 0.4)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            accessoryInline
        default:
            homeScreen
        }
    }

    private var homeScreen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.subjectName)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if entry.hasData {
                Text("\(Int(entry.percentage.rounded()))%")
                    .font(.system(size: family == .systemSmall ? 34 : 40, weight: .black, design: .rounded))
                    .foregroundStyle(accent)

                Text(entry.isSafe
                      ? "\(entry.bunksLeft) safe bunk\(entry.bunksLeft == 1 ? "" : "s")"
                      : "At risk — attend next")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            } else {
                Text("Open app")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text("Add a subject to see % and bunks")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.hasData ? "\(Int(entry.percentage.rounded()))" : "--")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("%")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.subjectName)
                .font(.headline)
                .lineLimit(1)
            if entry.hasData {
                Text("\(Int(entry.percentage.rounded()))% · \(entry.bunksLeft) bunks")
                    .font(.subheadline)
            } else {
                Text("Open Bunk Planner")
                    .font(.subheadline)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var accessoryInline: some View {
        Text(entry.hasData
              ? "\(entry.subjectName) \(Int(entry.percentage.rounded()))% · \(entry.bunksLeft) bunks"
              : "Bunk Planner")
    }
}

@main
struct BunkPlannerWidgets: WidgetBundle {
    var body: some Widget {
        AttendanceGlanceWidget()
        FocusTimerLiveActivity()
    }
}

struct AttendanceGlanceWidget: Widget {
    let kind = "AttendanceGlanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AttendanceProvider()) { entry in
            BunkPlannerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Attendance")
        .description("Current % and safe bunks left.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
