//
//  StudyTaskListScreen.swift
//  Student Attendance Predictor
//

import SwiftUI

struct StudyTaskListScreen: View {
    var subjects: [SubjectSummary]
    var onStartFocus: (() -> Void)? = nil

    @ObservedObject private var store = StudyTaskStore.shared
    @State private var showCapture = false
    @State private var editingTask: StudyTask?
    @State private var showFocus = false

    private let cyan = BrandColor.colorAccentPrimary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.pending.isEmpty && store.tasks.isEmpty {
                    Text("Photograph homework. It lands here, on Home, and in Focus Timer.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Button {
                    showCapture = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Add from photo")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cyan))
                }
                .buttonStyle(.plain)

                taskGroup(title: "Due today", items: store.dueToday)
                taskGroup(
                    title: "Open",
                    items: store.pending.filter { task in
                        store.dueToday.contains(where: { $0.id == task.id }) == false
                            && store.upcomingExams.contains(where: { $0.id == task.id }) == false
                    }
                )
                examGroup
                doneGroup
            }
            .padding(20)
        }
        .background(BrandColor.colorBackground.ignoresSafeArea())
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCapture) {
            StudyTaskCaptureFlow(
                subjects: subjects,
                onNeedSubjects: {},
                onAdded: { _ in },
                onStartFocus: {
                    if let first = store.pending.first {
                        FocusTimerService.shared.selectTask(first)
                    }
                    if let onStartFocus {
                        onStartFocus()
                    } else {
                        showFocus = true
                    }
                }
            )
        }
        .sheet(item: $editingTask) { task in
            StudyTaskEditSheet(task: task, subjects: subjects)
        }
        .sheet(isPresented: $showFocus) {
            NavigationStack {
                FocusTimerToolScreen(subjects: subjects)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showFocus = false }
                                .foregroundStyle(.white)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            store.archivePastExams()
            AnalyticsService.shared.setScreen(.studyTasks)
        }
    }

    private func taskGroup(title: String, items: [StudyTask]) -> some View {
        Group {
            if items.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(1.1)
                    ForEach(items) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private var examGroup: some View {
        Group {
            if store.upcomingExams.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXAMS")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(1.1)
                    ForEach(store.upcomingExams) { exam in
                        VStack(alignment: .leading, spacing: 8) {
                            taskRow(exam)
                            ForEach(exam.topics) { topic in
                                Button {
                                    store.setTopicCovered(
                                        taskID: exam.id,
                                        topicID: topic.id,
                                        covered: topic.isCovered == false
                                    )
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: topic.isCovered ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(topic.isCovered ? BrandColor.colorAttend : cyan)
                                        Text(topic.title)
                                            .strikethrough(topic.isCovered)
                                            .foregroundStyle(.white.opacity(topic.isCovered ? 0.45 : 0.85))
                                        Spacer()
                                    }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }
            }
        }
    }

    private var doneGroup: some View {
        let done = store.tasks.filter(\.isDone).prefix(8)
        return Group {
            if done.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DONE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(1.1)
                    ForEach(Array(done)) { task in
                        HStack {
                            Text(task.title)
                                .strikethrough()
                                .foregroundStyle(.white.opacity(0.4))
                            Spacer()
                            Button("Undo") { store.reopen(id: task.id) }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(cyan)
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                }
            }
        }
    }

    private func taskRow(_ task: StudyTask) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                store.complete(id: task.id)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(cyan)
            }
            .buttonStyle(.plain)

            Button {
                editingTask = task
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(task.kind.title) · \(task.displaySubject) · \(task.dueLabel)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 2)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                editingTask = task
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.delete(id: task.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct StudyTaskEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    var subjects: [SubjectSummary]
    @State private var title: String
    @State private var kind: StudyTaskKind
    @State private var subjectName: String
    @State private var dueDate: Date
    private let taskID: UUID
    private let cyan = BrandColor.colorAccentPrimary

    init(task: StudyTask, subjects: [SubjectSummary]) {
        self.subjects = subjects
        taskID = task.id
        _title = State(initialValue: task.title)
        _kind = State(initialValue: task.kind)
        _subjectName = State(initialValue: task.subjectName)
        _dueDate = State(initialValue: task.dueDate ?? StudyTaskStore.nextDay())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                Picker("Type", selection: $kind) {
                    ForEach(StudyTaskKind.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Picker("Subject", selection: $subjectName) {
                    Text("None").tag("")
                    ForEach(pickerNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                Button("Delete", role: .destructive) {
                    StudyTaskStore.shared.delete(id: taskID)
                    dismiss()
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle("Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(cyan)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var pickerNames: [String] {
        var names = subjects.map(\.name)
        if subjectName.isEmpty == false,
           names.contains(where: { $0.caseInsensitiveCompare(subjectName) == .orderedSame }) == false {
            names.insert(subjectName, at: 0)
        }
        return names
    }

    private func save() {
        guard var task = StudyTaskStore.shared.task(id: taskID) else {
            dismiss()
            return
        }
        let match = StudyTaskStore.matchSubject(name: subjectName, subjects: subjects)
        task.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        task.kind = kind
        task.subjectID = match.id
        task.subjectName = match.name
        task.dueDate = dueDate
        StudyTaskStore.shared.update(task)
        dismiss()
    }
}
