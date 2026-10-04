//
//  StudyTaskCaptureFlow.swift
//  Student Attendance Predictor
//
//  Camera / paste → OCR → extract → review → save.
//

import PhotosUI
import SwiftUI
import UIKit

struct StudyTaskCaptureFlow: View {
    var subjects: [SubjectSummary]
    var onNeedSubjects: () -> Void
    var onAdded: (Int) -> Void
    var onStartFocus: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPaste = false
    @State private var pasteText = ""
    @State private var rawText = ""
    @State private var drafts: [StudyTaskDraft] = []
    @State private var isReading = false
    @State private var isExtracting = false
    @State private var usedAI = false
    @State private var errorMessage: String?
    @State private var source: StudyTaskSource = .photo
    @State private var showReview = false

    private let cyan = BrandColor.colorAccentPrimary

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Photograph the diary. Check the list, then add.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                if subjects.isEmpty {
                    Text("Add subjects first so we can attach homework to the right paper.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BrandColor.colorPremium)
                    Button("Add subjects") {
                        dismiss()
                        onNeedSubjects()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cyan))
                } else {
                    captureButtons
                }

                if isReading || isExtracting {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(isReading ? "Reading photo…" : "Making the list…")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(BrandColor.colorMissed)
                }

                #if DEBUG
                StudyTaskExtractLogPanel()
                #endif

                Spacer(minLength: 0)
            }
            .padding(20)
            }
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle("Add from photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showCamera) {
                StudyTaskCameraPicker { image in
                    Task { await readPhoto(image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPaste) {
                pasteSheet
            }
            .sheet(isPresented: $showReview) {
                StudyTaskReviewSheet(
                    drafts: $drafts,
                    usedAI: usedAI,
                    source: source,
                    subjects: subjects,
                    onAdd: { count in
                        showReview = false
                        dismiss()
                        onAdded(count)
                    },
                    onStartFocus: {
                        showReview = false
                        dismiss()
                        onStartFocus?()
                    }
                )
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await readPickerItem(item) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var captureButtons: some View {
        VStack(spacing: 10) {
            Button {
                showCamera = true
            } label: {
                labelRow(icon: "camera.fill", title: "Camera")
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $photoItem, matching: .images) {
                labelRow(icon: "photo.on.rectangle", title: "Photo library")
            }
            .buttonStyle(.plain)

            Button {
                pasteText = ""
                showPaste = true
            } label: {
                labelRow(icon: "doc.on.clipboard", title: "Paste text")
            }
            .buttonStyle(.plain)
        }
    }

    private func labelRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(cyan)
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var pasteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste from WhatsApp, email, or a notice.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                TextEditor(text: $pasteText)
                    .frame(minHeight: 180)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(20)
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle("Paste text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showPaste = false }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        source = .paste
                        showPaste = false
                        StudyTaskExtractLog.shared.clear()
                        StudyTaskExtractService.log("PASTE (\(pasteText.count) chars):\n\(pasteText)")
                        Task { await extract(from: pasteText) }
                    }
                    .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func readPickerItem(_ item: PhotosPickerItem) async {
        isReading = true
        errorMessage = nil
        source = .photo
        StudyTaskExtractLog.shared.clear()
        StudyTaskExtractService.log("START source=photo library")
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw SyllabusOCRError.recognitionFailed
            }
            let ocr = try await SyllabusOCRService.recognizeDiary(from: image)
            StudyTaskExtractService.log("OCR raw from library (\(ocr.rawReadingOrder.count) chars):\n\(ocr.rawReadingOrder)")
            if ocr.diaryRows != ocr.rawReadingOrder {
                StudyTaskExtractService.log("OCR layout rows:\n\(ocr.diaryRows)")
            }
            await extract(from: ocr.rawReadingOrder, laidOutRows: ocr.diaryRows)
        } catch {
            StudyTaskExtractService.log("OCR library failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isReading = false
        }
        photoItem = nil
    }

    private func readPhoto(_ image: UIImage) async {
        isReading = true
        errorMessage = nil
        source = .photo
        StudyTaskExtractLog.shared.clear()
        StudyTaskExtractService.log("START source=camera")
        do {
            let ocr = try await SyllabusOCRService.recognizeDiary(from: image)
            StudyTaskExtractService.log("OCR raw from camera (\(ocr.rawReadingOrder.count) chars):\n\(ocr.rawReadingOrder)")
            if ocr.diaryRows != ocr.rawReadingOrder {
                StudyTaskExtractService.log("OCR layout rows:\n\(ocr.diaryRows)")
            }
            await extract(from: ocr.rawReadingOrder, laidOutRows: ocr.diaryRows)
        } catch {
            StudyTaskExtractService.log("OCR camera failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isReading = false
        }
    }

    private func extract(from text: String, laidOutRows: String? = nil) async {
        rawText = laidOutRows?.isEmpty == false ? (laidOutRows ?? text) : text
        isReading = false
        isExtracting = true
        errorMessage = nil
        StudyTaskExtractService.log("EXTRACT source=\(source.rawValue)")
        AnalyticsService.shared.log(.studyTaskCaptureStarted(source: source.rawValue))
        let result = await StudyTaskExtractService.shared.extract(
            rawText: text,
            subjectNames: subjects.map(\.name),
            market: StudentMarketStore.current.rawValue,
            laidOutRows: laidOutRows
        )
        drafts = result.drafts
        usedAI = result.usedAI
        isExtracting = false
        StudyTaskExtractService.log("UI review source=\(result.usedAI ? "BE/Groq" : "local") count=\(drafts.count)")
        if drafts.isEmpty {
            errorMessage = "No items found. Try a clearer photo or paste the text."
            StudyTaskExtractService.log("UI showing error: \(errorMessage ?? "")")
            return
        }
        AnalyticsService.shared.log(.studyTaskExtracted(count: drafts.count, usedAI: usedAI))
        showReview = true
    }
}

struct StudyTaskReviewSheet: View {
    @Binding var drafts: [StudyTaskDraft]
    var usedAI: Bool
    var source: StudyTaskSource
    var subjects: [SubjectSummary]
    var onAdd: (Int) -> Void
    var onStartFocus: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expandedID: UUID?
    @State private var savedCount: Int?

    private let cyan = BrandColor.colorAccentPrimary

    private var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    private var dueSummary: String {
        let labels = Set(
            drafts.filter(\.isSelected).map { draft in
                StudyTask(title: draft.title, kind: draft.kind, dueDate: draft.dueDate).dueLabel
            }
        )
        if labels.count == 1, let label = labels.first { return label }
        return "On your list"
    }

    var body: some View {
        NavigationStack {
            Group {
                if let savedCount {
                    addedConfirmation(count: savedCount)
                } else {
                    checklist
                }
            }
            .background(BrandColor.colorBackground.ignoresSafeArea())
            .navigationTitle(savedCount == nil ? "Review" : "Added")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(savedCount == nil ? "Close" : "Done") {
                        if savedCount != nil {
                            onAdd(savedCount ?? 0)
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(.white)
                }
                if savedCount == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add \(selectedCount)") {
                            saveDrafts()
                        }
                        .disabled(selectedCount == 0)
                        .foregroundStyle(cyan)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var checklist: some View {
        List {
            Section {
                Text(usedAI
                     ? "Uncheck anything wrong. Tap a row to fix it."
                     : "Check each line. Tap a row to fix title, subject, or date.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .listRowBackground(Color.clear)
            }

            ForEach($drafts) { $item in
                Section {
                    Button {
                        expandedID = expandedID == item.id ? nil : item.id
                    } label: {
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
                                TextField("Homework", text: $item.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(item.subjectName.isEmpty ? "No subject" : item.subjectName) · \(dueText(item.dueDate))")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer(minLength: 0)
                            Image(systemName: expandedID == item.id ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .buttonStyle(.plain)

                    if expandedID == item.id {
                        Picker("Type", selection: $item.kind) {
                            ForEach(StudyTaskKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        Picker("Subject", selection: $item.subjectName) {
                            Text("None").tag("")
                            ForEach(subjectPickerNames(for: item), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        DatePicker(
                            "Due",
                            selection: Binding(
                                get: { item.dueDate ?? StudyTaskExtractService.nextDay() },
                                set: { item.dueDate = $0; item.isDateFlagged = false }
                            ),
                            displayedComponents: .date
                        )
                        if item.isDateFlagged {
                            Text("No date in the photo — set as tomorrow.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(BrandColor.colorPremium)
                        }
                        if item.kind == .exam {
                            TextField("Topics (comma or new line)", text: $item.topicsText, axis: .vertical)
                                .lineLimit(3...8)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))
            }

            #if DEBUG
            Section("Debug") {
                StudyTaskExtractLogPanel()
                    .listRowBackground(Color.clear)
            }
            #endif
        }
        .scrollContentBackground(.hidden)
    }

    private func addedConfirmation(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(count) task\(count == 1 ? "" : "s") added")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(dueSummary)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            Button(action: onStartFocus) {
                Text("Start Focus")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cyan))
            }
            .buttonStyle(.plain)

            Button {
                onAdd(count)
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

    private func saveDrafts() {
        StudyTaskExtractService.log("UI tap Add \(selectedCount) selected of \(drafts.count)")
        StudyTaskExtractService.logDrafts(drafts.filter(\.isSelected))
        let count = StudyTaskStore.shared.add(
            from: drafts,
            source: source,
            subjects: subjects
        )
        StudyTaskExtractService.log("UI saved \(count) task(s)")
        savedCount = count
    }

    private func dueText(_ date: Date?) -> String {
        StudyTask(title: "", kind: .homework, dueDate: date).dueLabel
    }

    private func subjectPickerNames(for item: StudyTaskDraft) -> [String] {
        var names = subjects.map(\.name)
        let current = item.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty == false,
           names.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) == false {
            names.insert(current, at: 0)
        }
        return names
    }
}

struct StudyTaskExtractLogPanel: View {
    @ObservedObject private var log = StudyTaskExtractLog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DEBUG LOG")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .tracking(1.1)
                Spacer()
                if log.lines.isEmpty == false {
                    Button("Copy") {
                        UIPasteboard.general.string = log.text
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(BrandColor.colorAccentPrimary)
                }
            }
            ScrollView {
                Text(log.lines.isEmpty ? "Scan or paste. SEND / RECV / SHOW will show here." : log.text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 140, maxHeight: 240)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
    }
}

struct StudyTaskCameraPicker: UIViewControllerRepresentable {
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
        let parent: StudyTaskCameraPicker
        init(parent: StudyTaskCameraPicker) { self.parent = parent }

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
