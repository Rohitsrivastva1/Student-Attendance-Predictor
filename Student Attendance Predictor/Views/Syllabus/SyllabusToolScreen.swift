//
//  SyllabusToolScreen.swift
//  Student Attendance Predictor
//
//  Tools → Syllabus: capture, OCR, AI structure, learning checklist, Focus bridge.
//

import SwiftUI
import PhotosUI
import UIKit

struct SyllabusToolScreen: View {
    var subjects: [SubjectSummary]

    @ObservedObject private var store = SyllabusStore.shared
    @State private var showCreate = false
    @State private var selectedDocumentID: UUID?

    private let cyan = BrandColor.colorAccentPrimary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if store.documents.isEmpty {
                    emptyState
                } else {
                    ForEach(store.documents) { doc in
                        NavigationLink {
                            SyllabusDetailScreen(documentID: doc.id, subjects: subjects)
                        } label: {
                            documentRow(doc)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(BrandColor.colorBackground.ignoresSafeArea())
        .navigationTitle("Syllabus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(cyan)
                }
                .accessibilityLabel("Add syllabus")
            }
        }
        .sheet(isPresented: $showCreate) {
            SyllabusCreateSheet(subjects: subjects) { id in
                selectedDocumentID = id
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }
        .navigationDestination(item: $selectedDocumentID) { id in
            SyllabusDetailScreen(documentID: id, subjects: subjects)
        }
        .onAppear {
            AnalyticsService.shared.setScreen(.syllabus)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Track what you’ve learned")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Photo or type your syllabus, then add each chapter as a task so you can cover them one by one.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No syllabus yet")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Add one from a photo or paste the outline. You’ll get a checklist for pending vs learned.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Button {
                showCreate = true
            } label: {
                Text("Add syllabus")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cyan))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(cardBackground)
    }

    private func documentRow(_ doc: SyllabusDocument) -> some View {
        let subjectName = subjects.first(where: { $0.id == doc.subjectID })?.name
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cyan.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(cyan)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subjectName.map { "\($0) · \(doc.progressLabel)" } ?? doc.progressLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                ProgressView(value: doc.progressFraction)
                    .tint(cyan)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(14)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Create

private struct SyllabusCreateSheet: View {
    var subjects: [SubjectSummary]
    var onCreated: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SyllabusStore.shared

    @State private var title = ""
    @State private var subjectID: UUID?
    @State private var errorMessage: String?

    private let cyan = BrandColor.colorAccentPrimary

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. OS syllabus", text: $title)
                }
                Section("Subject") {
                    Picker("Subject", selection: $subjectID) {
                        Text("General").tag(UUID?.none)
                        ForEach(subjects) { subject in
                            Text(subject.name).tag(Optional(subject.id))
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(BrandColor.colorMissed)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle("New syllabus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if let doc = store.createDocument(
                            title: title.isEmpty ? "Syllabus" : title,
                            subjectID: subjectID,
                            source: .manual
                        ) {
                            onCreated(doc.id)
                            dismiss()
                        } else {
                            errorMessage = "You can save up to \(SyllabusStore.maxDocuments) syllabi."
                        }
                    }
                    .foregroundStyle(cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Detail

struct SyllabusDetailScreen: View {
    let documentID: UUID
    var subjects: [SubjectSummary]

    @ObservedObject private var store = SyllabusStore.shared
    @State private var rawText: String = ""
    @State private var isRecognizing = false
    @State private var isStructuring = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showFocusSuggest = false
    @State private var showChapterTasks = false
    @State private var includeLearnedInSuggest = false
    @State private var showDeleteConfirm = false
    @State private var navigateToFocus = false
    @State private var pendingOpenFocus = false

    private let cyan = BrandColor.colorAccentPrimary
    private let green = BrandColor.colorAttend
    private let gold = BrandColor.colorPremium

    private var document: SyllabusDocument? {
        store.document(id: documentID)
    }

    private var subjectName: String? {
        guard let sid = document?.subjectID else { return nil }
        return subjects.first(where: { $0.id == sid })?.name
    }

    var body: some View {
        Group {
            if let document {
                detailBody(document)
            } else {
                Text("Syllabus removed")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .background(BrandColor.colorBackground.ignoresSafeArea())
        .navigationTitle(document?.title ?? "Syllabus")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToFocus) {
            FocusTimerToolScreen(subjects: subjects)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add chapters as tasks") {
                        showChapterTasks = true
                    }
                    .disabled((document?.totalTopicCount ?? 0) == 0)
                    Toggle("Include learned chapters", isOn: $includeLearnedInSuggest)
                    Divider()
                    Button("Delete syllabus", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .onAppear {
            rawText = document?.rawText ?? ""
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .sheet(isPresented: $showCamera) {
            SyllabusCameraPicker { image in
                Task { await runOCR(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showChapterTasks) {
            if let document {
                SyllabusChaptersToTasksSheet(
                    document: document,
                    subjectName: subjectName ?? "",
                    includeLearned: includeLearnedInSuggest,
                    onAdded: { count in
                        statusMessage = count == 0
                            ? "Those chapters are already on your task list."
                            : "\(count) chapter task\(count == 1 ? "" : "s") added."
                        errorMessage = nil
                    },
                    onStartFocus: {
                        pendingOpenFocus = true
                        navigateToFocus = true
                    }
                )
                .presentationDetents([.medium, .large])
                .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showFocusSuggest, onDismiss: {
            if pendingOpenFocus {
                pendingOpenFocus = false
                navigateToFocus = true
            }
        }) {
            if let document {
                SyllabusFocusSuggestSheet(
                    documentID: document.id,
                    subjectID: document.subjectID,
                    subjectName: subjectName,
                    includeLearned: includeLearnedInSuggest,
                    onAdded: {
                        pendingOpenFocus = true
                    }
                )
                .presentationDetents([.medium, .large])
                .preferredColorScheme(.dark)
            }
        }
        .alert("Delete this syllabus?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.deleteDocument(id: documentID)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func detailBody(_ document: SyllabusDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                progressCard(document)

                captureSection

                textSection

                structureActions

                if document.units.isEmpty == false {
                    checklistSection(document)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(green)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(BrandColor.colorMissed)
                }
            }
            .padding(20)
        }
    }

    private func progressCard(_ document: SyllabusDocument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(document.progressLabel)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if let subjectName {
                    Text(subjectName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(cyan)
                }
            }
            ProgressView(value: document.progressFraction)
                .tint(cyan)
            Text("Add chapters as tasks. Cover one, mark it done, then the next.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .background(cardBackground)
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD CONTENT")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.1)

            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    labelChip(icon: "photo.on.rectangle", title: "Photo")
                }
                .buttonStyle(.plain)

                Button {
                    showCamera = true
                } label: {
                    labelChip(icon: "camera.fill", title: "Camera")
                }
                .buttonStyle(.plain)
            }

            if isRecognizing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reading photo…")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SYLLABUS TEXT")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.1)
            Text("Fix anything wrong before Make better.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
            TextEditor(text: $rawText)
                .frame(minHeight: 140)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .foregroundStyle(.white)
                .onChange(of: rawText) { _, newValue in
                    store.setRawText(documentID: documentID, text: newValue)
                }
        }
    }

    private var structureActions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await makeBetter() }
            } label: {
                HStack {
                    if isStructuring { ProgressView().tint(.black) }
                    Text(isStructuring ? "Structuring…" : "Make better with AI")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cyan))
            }
            .buttonStyle(.plain)
            .disabled(isStructuring || rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                let units = SyllabusAIService.heuristicUnits(from: rawText)
                store.replaceUnits(documentID: documentID, units: units)
                statusMessage = "Outline built on device."
                errorMessage = nil
            } label: {
                Text("Build outline without AI")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if (document?.totalTopicCount ?? 0) > 0 {
                Button {
                    showChapterTasks = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Add chapters as tasks")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(gold))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func checklistSection(_ document: SyllabusDocument) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHECKLIST")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.1)

            ForEach(document.units) { unit in
                VStack(alignment: .leading, spacing: 8) {
                    Text(unit.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(cyan)
                    ForEach(unit.topics) { topic in
                        topicRow(topic)
                    }
                }
                .padding(12)
                .background(cardBackground)
            }
        }
    }

    private func topicRow(_ topic: SyllabusTopic) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                cycleStatus(topic)
            } label: {
                Image(systemName: statusIcon(topic.status))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(statusColor(topic.status))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(topic.status == .learned ? .white.opacity(0.45) : .white)
                    .strikethrough(topic.status == .learned)
                Text(topic.status.label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func cycleStatus(_ topic: SyllabusTopic) {
        let next: SyllabusLearnStatus
        switch topic.status {
        case .pending: next = .inProgress
        case .inProgress: next = .learned
        case .learned: next = .pending
        }
        store.setTopicStatus(documentID: documentID, topicID: topic.id, status: next)
    }

    private func statusIcon(_ status: SyllabusLearnStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .learned: return "checkmark.circle.fill"
        }
    }

    private func statusColor(_ status: SyllabusLearnStatus) -> Color {
        switch status {
        case .pending: return .white.opacity(0.35)
        case .inProgress: return gold
        case .learned: return green
        }
    }

    private func labelChip(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        isRecognizing = true
        errorMessage = nil
        defer { isRecognizing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Couldn’t open that photo."
                return
            }
            await runOCR(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runOCR(_ image: UIImage) async {
        isRecognizing = true
        errorMessage = nil
        defer { isRecognizing = false }
        do {
            let text = try await SyllabusOCRService.recognizeText(from: image)
            if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rawText = text
            } else {
                rawText = rawText + "\n\n" + text
            }
            store.setRawText(documentID: documentID, text: rawText, sourceBump: .photo)
            statusMessage = "Text extracted on this device."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeBetter() async {
        isStructuring = true
        errorMessage = nil
        statusMessage = nil
        defer { isStructuring = false }
        store.setRawText(documentID: documentID, text: rawText)
        do {
            let units = try await SyllabusAIService.shared.structureSyllabus(
                rawText: rawText,
                subjectName: subjectName,
                market: StudentMarketStore.current.rawValue
            )
            store.replaceUnits(documentID: documentID, units: units)
            statusMessage = "Outline ready — check off what you’ve learned."
            AnalyticsService.shared.log(.syllabusAIStructured(unitCount: units.count, topicCount: units.reduce(0) { $0 + $1.topics.count }))
        } catch let error as SyllabusAIError where error == .aiNotConfigured || error == .notConfigured {
            let units = SyllabusAIService.heuristicUnits(from: rawText)
            store.replaceUnits(documentID: documentID, units: units)
            errorMessage = nil
            statusMessage = "Built outline on this device (AI briefly unavailable)."
        } catch {
            // Never leave the student stuck — always produce a usable checklist.
            let units = SyllabusAIService.heuristicUnits(from: rawText)
            store.replaceUnits(documentID: documentID, units: units)
            errorMessage = nil
            statusMessage = "Built outline on this device. You can edit topics anytime."
        }
    }
}

// MARK: - Focus suggest

struct SyllabusFocusSuggestSheet: View {
    let documentID: UUID
    var subjectID: UUID?
    var subjectName: String? = nil
    var includeLearned: Bool
    var onAdded: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = SyllabusStore.shared
    @State private var suggestions: [FocusTopicSuggestion] = []
    @State private var customTitle = ""
    @State private var resultMessage: String?

    private let cyan = BrandColor.colorAccentPrimary

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("We’ll suggest Focus topics from pending / in-progress checklist items. Turn off any you don’t want, rename, or add your own.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .listRowBackground(Color.clear)
                }

                Section("Suggested") {
                    if suggestions.isEmpty {
                        Text("Nothing to suggest — add topics or include learned.")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    ForEach($suggestions) { $item in
                        HStack(spacing: 10) {
                            Toggle("", isOn: $item.isSelected)
                                .labelsHidden()
                                .tint(cyan)
                            TextField("Topic", text: $item.title)
                                .foregroundStyle(.white)
                        }
                    }
                }

                Section("Add your own") {
                    HStack {
                        TextField("Custom topic", text: $customTitle)
                        Button("Add") {
                            let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard trimmed.isEmpty == false else { return }
                            suggestions.append(
                                FocusTopicSuggestion(
                                    title: String(trimmed.prefix(48)),
                                    syllabusTopicIDs: [],
                                    isSelected: true,
                                    isCustom: true
                                )
                            )
                            customTitle = ""
                        }
                        .foregroundStyle(cyan)
                    }
                }

                if let resultMessage {
                    Section {
                        Text(resultMessage)
                            .foregroundStyle(BrandColor.colorAttend)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle("Study in Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Focus") {
                        let count = store.applyFocusSuggestions(
                            documentID: documentID,
                            suggestions: suggestions,
                            subjectID: subjectID
                        )
                        if count > 0, let subjectID {
                            FocusTimerService.shared.tagSubject(
                                id: subjectID,
                                name: subjectName
                            )
                        }
                        AnalyticsService.shared.log(.syllabusFocusTopicsAdded(count: count))
                        resultMessage = count == 0
                            ? "No topics added."
                            : "Added \(count) Focus topic\(count == 1 ? "" : "s"). Open Focus Timer to see them."
                        if count > 0 {
                            onAdded?()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                dismiss()
                            }
                        }
                    }
                    .foregroundStyle(cyan)
                }
            }
            .onAppear {
                let existing = FocusTopicStore.shared.topics(for: subjectID).map(\.name)
                suggestions = store.focusSuggestions(
                    for: documentID,
                    includeLearned: includeLearned,
                    existingFocusNames: existing
                )
            }
        }
    }
}

// MARK: - Camera

private struct SyllabusCameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SyllabusCameraPicker
        init(parent: SyllabusCameraPicker) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }
    }
}

// MARK: - Chapters → tasks

private struct SyllabusChaptersToTasksSheet: View {
    let document: SyllabusDocument
    let subjectName: String
    var includeLearned: Bool
    var onAdded: (Int) -> Void
    var onStartFocus: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [SyllabusChapterDraft] = []
    @State private var savedCount: Int?

    private let cyan = BrandColor.colorAccentPrimary

    private var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if let savedCount {
                    confirmation(count: savedCount)
                } else {
                    chapterList
                }
            }
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle(savedCount == nil ? "Chapters" : "Added")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(savedCount == nil ? "Close" : "Done") {
                        if let savedCount { onAdded(savedCount) }
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                if savedCount == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add \(selectedCount)") {
                            let count = StudyTaskStore.shared.addSyllabusChapters(
                                drafts,
                                document: document,
                                subjectName: subjectName
                            )
                            savedCount = count
                            if count > 0, let first = StudyTaskStore.shared.pending.first(where: {
                                $0.syllabusDocumentID == document.id
                            }) {
                                FocusTimerService.shared.selectTask(first)
                            }
                        }
                        .disabled(selectedCount == 0)
                        .foregroundStyle(cyan)
                    }
                }
            }
            .onAppear {
                drafts = StudyTaskStore.chapterDrafts(from: document, includeLearned: includeLearned)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var chapterList: some View {
        List {
            Section {
                Text("Each chapter becomes its own task, due on a later day so you can cover them one by one.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .listRowBackground(Color.clear)
            }
            ForEach($drafts) { $item in
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Button {
                            item.isSelected.toggle()
                        } label: {
                            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(item.isSelected ? cyan : .white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Chapter", text: $item.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(StudyTask(title: item.title, kind: .chapter, dueDate: item.dueDate).dueLabel)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                            if item.topicTitles.isEmpty == false {
                                Text(item.topicTitles.prefix(4).joined(separator: " · "))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(2)
                            }
                        }
                    }
                    DatePicker("Due", selection: $item.dueDate, displayedComponents: .date)
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func confirmation(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(count == 0 ? "Already on your list" : "\(count) chapter task\(count == 1 ? "" : "s") added")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            if count > 0 {
                Text("They show on Tasks, Home, and Focus. Mark a chapter done when you’ve covered it.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Button {
                    onAdded(count)
                    dismiss()
                    onStartFocus()
                } label: {
                    Text("Start Focus")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cyan))
                }
                .buttonStyle(.plain)
            }
            Button {
                onAdded(count)
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(24)
    }
}
