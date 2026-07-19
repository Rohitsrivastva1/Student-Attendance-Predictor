//
//  AcademicsView.swift
//  Student Attendance Predictor
//
//  US/UK-friendly GPA + exams/deadlines hub (also useful for India).
//

import SwiftUI

struct AcademicsView: View {
    @ObservedObject var gpaStore: GPAStore
    @ObservedObject var deadlineStore: DeadlineStore
    private var market: StudentMarket { StudentMarketStore.current }

    @State private var showAddCourse = false
    @State private var showAddDeadline = false
    @State private var courseName = ""
    @State private var courseCredits = "3"
    @State private var courseGrade: LetterGrade = .b
    @State private var deadlineTitle = ""
    @State private var deadlineCourse = ""
    @State private var deadlineKind: AcademicDeadlineKind = .exam
    @State private var deadlineDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    private let cyan = Color(red: 0.32, green: 0.84, blue: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            gpaCard
            deadlinesCard
        }
        .onAppear {
            AnalyticsService.shared.setScreen(.academics)
        }
        .sheet(isPresented: $showAddCourse) { addCourseSheet }
        .sheet(isPresented: $showAddDeadline) { addDeadlineSheet }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(market.academicsHeadline)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Built for US & UK grades and deadlines — works great in India too.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var gpaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(market.gpaScaleLabel)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showAddCourse = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }

            if let gpa = gpaStore.gpa {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "%.2f", gpa))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GPA")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(gpaStore.courses.count) course\(gpaStore.courses.count == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Spacer()
                }

                if market == .unitedKingdom {
                    Text("Letter grades use the US 4.0 scale. Track module % in notes for UK classification later.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            } else {
                Text("Add your courses to see a live GPA.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            ForEach(gpaStore.courses) { course in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(course.credits.cleanCredits) credits · \(course.grade.rawValue)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Button(role: .destructive) {
                        gpaStore.delete(id: course.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var deadlinesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Exams & Deadlines")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showAddDeadline = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }

            if deadlineStore.upcoming.isEmpty && deadlineStore.past.isEmpty {
                Text("Track exams and assignments so you know when not to \(market.skipVerb).")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

            ForEach(deadlineStore.upcoming.prefix(8)) { item in
                deadlineRow(item)
            }

            if deadlineStore.past.isEmpty == false {
                Text("Past")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 4)
                ForEach(deadlineStore.past.prefix(3)) { item in
                    deadlineRow(item, dimmed: true)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func deadlineRow(_ item: AcademicDeadline, dimmed: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(countdownColor(item))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(dimmed ? 0.55 : 1))
                Text(item.courseName.isEmpty ? item.kind.title : "\(item.kind.title) · \(item.courseName)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.countdownLabel)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(countdownColor(item))
                Button(role: .destructive) {
                    deadlineStore.delete(id: item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func countdownColor(_ item: AcademicDeadline) -> Color {
        let days = item.daysRemaining
        if days < 0 { return .red.opacity(0.85) }
        if days <= 3 { return .orange }
        if days <= 7 { return Color(red: 1.0, green: 0.84, blue: 0.2) }
        return cyan
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private var addCourseSheet: some View {
        NavigationStack {
            Form {
                TextField("Course name", text: $courseName)
                TextField("Credits", text: $courseCredits)
                    .keyboardType(.decimalPad)
                Picker("Grade", selection: $courseGrade) {
                    ForEach(LetterGrade.allCases) { grade in
                        Text("\(grade.rawValue) (\(String(format: "%.1f", grade.points4_0)))")
                            .tag(grade)
                    }
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddCourse = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let credits = Double(courseCredits.replacingOccurrences(of: ",", with: ".")) ?? 3
                        gpaStore.addCourse(name: courseName, credits: credits, grade: courseGrade)
                        courseName = ""
                        courseCredits = "3"
                        courseGrade = .b
                        showAddCourse = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var addDeadlineSheet: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $deadlineTitle)
                TextField("Course / module (optional)", text: $deadlineCourse)
                Picker("Type", selection: $deadlineKind) {
                    ForEach(AcademicDeadlineKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                DatePicker("Due date", selection: $deadlineDate, displayedComponents: .date)
            }
            .navigationTitle("Add Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddDeadline = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let title = deadlineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard title.isEmpty == false else { return }
                        deadlineStore.add(
                            AcademicDeadline(
                                title: title,
                                dueDate: deadlineDate,
                                kind: deadlineKind,
                                courseName: deadlineCourse.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        deadlineTitle = ""
                        deadlineCourse = ""
                        deadlineKind = .exam
                        deadlineDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        showAddDeadline = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private extension Double {
    var cleanCredits: String {
        rounded() == self ? String(Int(self)) : String(format: "%.1f", self)
    }
}
