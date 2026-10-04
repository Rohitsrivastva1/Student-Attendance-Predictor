//
//  HomeStudyTaskCards.swift
//  Student Attendance Predictor
//
//  Due soon + exam coverage on Home. Same store as Focus Timer.
//

import SwiftUI

struct HomeDueSoonCard: View {
    @ObservedObject var store: StudyTaskStore
    var onOpenAll: () -> Void
    var onEdit: (StudyTask) -> Void

    private let cyan = BrandColor.colorAccentPrimary

    var body: some View {
        let items = store.dueSoon
        if items.isEmpty == false {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Due soon")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("All", action: onOpenAll)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(cyan)
                }

                ForEach(items.prefix(4)) { task in
                    HStack(spacing: 10) {
                        Image(systemName: task.kind.systemImage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(cyan)
                        Button {
                            onEdit(task)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text("\(task.displaySubject) · \(task.dueLabel)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Button("Done") {
                            store.complete(id: task.id)
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(BrandColor.colorAttend)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
            .background(homeCardBackground)
        }
    }

    private var homeCardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

struct HomeExamCoverageCard: View {
    @ObservedObject var store: StudyTaskStore
    var onTick: (StudyTask, StudyTaskTopic) -> Void

    private let gold = BrandColor.colorPremium

    var body: some View {
        if let exam = store.upcomingExams.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(exam.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(exam.dueLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(gold)
                }
                Text("\(exam.displaySubject) · \(exam.topicsLeftLabel)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                ForEach(exam.uncoveredTopics.prefix(4)) { topic in
                    Button {
                        onTick(exam, topic)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(gold)
                            Text(topic.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("Tick covered")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(gold)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gold.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(gold.opacity(0.28), lineWidth: 1)
                    )
            )
        }
    }
}

struct HomeSubjectTasksRow: View {
    let subject: SubjectSummary
    @ObservedObject var store: StudyTaskStore
    var onEdit: (StudyTask) -> Void

    var body: some View {
        let items = store.tasks(for: subject.id)
        if items.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(subject.name) tasks")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                ForEach(items.prefix(3)) { task in
                    Button {
                        onEdit(task)
                    } label: {
                        HStack {
                            Text(task.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(task.dueLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }
}
