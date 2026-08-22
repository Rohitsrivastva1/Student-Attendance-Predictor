//
//  AttendanceReportPageViews.swift
//  Student Attendance Predictor
//
//  Print-friendly A4 pages for the Pro attendance PDF export.
//

import SwiftUI

enum AttendanceReportLayout {
    /// A4 at 72 dpi (points).
    static let pageSize = CGSize(width: 595.28, height: 841.89)
    static let subjectsPerFirstPage = 7
    static let subjectsPerNextPage = 9
}

struct AttendanceReportPageModel: Identifiable {
    let id: Int
    let pageIndex: Int
    let pageCount: Int
    let subjects: [SubjectSummary]
    let summary: FacultyDashboardSummary
    let generatedAt: Date
    let semesterStart: Date?
    let semesterEnd: Date?
    let isFirstPage: Bool
}

struct AttendanceReportPageView: View {
    let model: AttendanceReportPageModel

    private let ink = Color(red: 0.12, green: 0.14, blue: 0.18)
    private let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    private let line = Color(red: 0.88, green: 0.90, blue: 0.93)
    private let cyan = Color(red: 0.12, green: 0.62, blue: 0.78)
    private let green = Color(red: 0.18, green: 0.62, blue: 0.42)
    private let amber = Color(red: 0.86, green: 0.55, blue: 0.16)
    private let risk = Color(red: 0.82, green: 0.32, blue: 0.28)
    private let softFill = Color(red: 0.96, green: 0.97, blue: 0.98)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isFirstPage {
                header
                overviewStrip
                    .padding(.top, 22)
                sectionTitle("Subjects")
                    .padding(.top, 26)
            } else {
                continuedHeader
            }

            VStack(spacing: 10) {
                ForEach(model.subjects) { subject in
                    subjectRow(subject)
                }
            }
            .padding(.top, model.isFirstPage ? 12 : 18)

            Spacer(minLength: 16)

            footer
        }
        .padding(.horizontal, 42)
        .padding(.top, 40)
        .padding(.bottom, 28)
        .frame(width: AttendanceReportLayout.pageSize.width, height: AttendanceReportLayout.pageSize.height, alignment: .topLeading)
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BUNK PLANNER")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(cyan)
                        .tracking(1.6)

                    Text("Attendance Summary")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ink)

                    Text("Parent & admin ready report")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(Self.dateFormatter.string(from: model.generatedAt))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)
                    if let range = semesterRangeLabel {
                        Text(range)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(muted)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [cyan, green.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .clipShape(Capsule())
        }
    }

    private var continuedHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BUNK PLANNER")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(cyan)
                    .tracking(1.4)
                Spacer()
                Text("Attendance Summary · continued")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(muted)
            }
            Rectangle()
                .fill(line)
                .frame(height: 1)
        }
    }

    private var overviewStrip: some View {
        HStack(spacing: 12) {
            overviewCard(
                title: "Average",
                value: String(format: "%.0f%%", model.summary.averageAttendance),
                accent: cyan
            )
            overviewCard(
                title: "Safe",
                value: "\(model.summary.safeSubjects)",
                accent: green
            )
            overviewCard(
                title: "At risk",
                value: "\(model.summary.riskSubjects)",
                accent: model.summary.riskSubjects > 0 ? amber : muted
            )
            overviewCard(
                title: "Subjects",
                value: "\(model.summary.totalSubjects)",
                accent: ink
            )
        }
    }

    private func overviewCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(muted)
                .tracking(0.8)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(softFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(line, lineWidth: 1)
                )
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(ink)
    }

    private func subjectRow(_ subject: SubjectSummary) -> some View {
        let progress = min(max(subject.currentPercentage / 100.0, 0), 1.2)
        let barProgress = min(progress, 1.0)
        let statusColor = subject.status == .safe ? green : risk
        let action = subject.actionChipLabel

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(subject.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(subject.totalClasses > 0
                      ? String(format: "%.0f%%", subject.currentPercentage)
                      : "—")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(statusColor)

                statusPill(subject.status == .safe ? "Safe" : "At risk", color: statusColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(line)
                        .frame(height: 7)
                    Capsule()
                        .fill(statusColor)
                        .frame(width: max(8, geo.size.width * barProgress), height: 7)
                }
            }
            .frame(height: 7)

            HStack(spacing: 14) {
                metaLabel("Attended", "\(subject.attendedClasses)/\(subject.totalClasses)")
                metaLabel("Target", String(format: "%.0f%%", subject.requiredPercentage))
                metaLabel("Action", action)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(line, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }

    private func metaLabel(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(line)
                .frame(height: 1)
            HStack {
                Text("Generated with Bunk Planner · data stays on device")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(muted)
                Spacer()
                Text("Page \(model.pageIndex) of \(model.pageCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(muted)
            }
        }
    }

    private var semesterRangeLabel: String? {
        let start = model.semesterStart
        let end = model.semesterEnd
        guard start != nil || end != nil else { return nil }
        let formatter = Self.shortDateFormatter
        if let start, let end {
            return "Semester \(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
        if let end {
            return "Semester ends \(formatter.string(from: end))"
        }
        if let start {
            return "Semester from \(formatter.string(from: start))"
        }
        return nil
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

// MARK: - Grades page (Pro PDF)

struct GradesReportPageModel {
    let pageIndex: Int
    let pageCount: Int
    let generatedAt: Date
    let snapshot: GradesReportSnapshot
}

struct GradesReportPageView: View {
    let model: GradesReportPageModel

    private let ink = Color(red: 0.12, green: 0.14, blue: 0.18)
    private let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    private let line = Color(red: 0.88, green: 0.90, blue: 0.93)
    private let cyan = Color(red: 0.12, green: 0.62, blue: 0.78)
    private let green = Color(red: 0.18, green: 0.62, blue: 0.42)
    private let softFill = Color(red: 0.96, green: 0.97, blue: 0.98)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            overallCard
                .padding(.top, 22)
            Text("Semesters")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(ink)
                .padding(.top, 22)

            VStack(spacing: 12) {
                ForEach(model.snapshot.terms) { term in
                    termBlock(term)
                }
            }
            .padding(.top, 12)

            Spacer(minLength: 16)

            footer
        }
        .padding(.horizontal, 42)
        .padding(.top, 40)
        .padding(.bottom, 28)
        .frame(width: AttendanceReportLayout.pageSize.width, height: AttendanceReportLayout.pageSize.height, alignment: .topLeading)
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BUNK PLANNER")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(cyan)
                        .tracking(1.6)
                    Text("Grades Summary")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(ink)
                    Text("Included with Pro · on-device data")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(muted)
                }
                Spacer()
                Text(Self.dateFormatter.string(from: model.generatedAt))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
            }
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [cyan, green.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .clipShape(Capsule())
        }
    }

    private var overallCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.snapshot.overallLabel.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(muted)
                .tracking(0.8)
            Text(model.snapshot.overallValue)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(cyan)
            if let detail = model.snapshot.overallDetail {
                Text(detail)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(softFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(line, lineWidth: 1)
                )
        )
    }

    private func termBlock(_ term: GradesReportSnapshot.TermBlock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(term.name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(ink)
                if term.isArchived {
                    Text("Archived")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(line))
                }
                Spacer()
                Text("\(term.scoreLabel) \(term.scoreValue)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(cyan)
            }
            ForEach(Array(term.rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                    Spacer()
                    Text(row.detail)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(muted)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(line, lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(line)
                .frame(height: 1)
            HStack {
                Text("Generated with Bunk Planner · grades stay on device")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(muted)
                Spacer()
                Text("Page \(model.pageIndex) of \(model.pageCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(muted)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
