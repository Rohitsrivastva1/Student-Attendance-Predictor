//
//  AttendanceReportPDF.swift
//  Student Attendance Predictor
//
//  Builds a multi-page A4 attendance (+ optional grades) PDF from SwiftUI pages.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AttendanceReportPDF {
    enum ExportError: LocalizedError {
        case emptySubjects
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .emptySubjects:
                return "Add at least one subject before exporting a report."
            case .renderFailed:
                return "Couldn't create the PDF. Please try again."
            }
        }
    }

#if canImport(UIKit)
    /// Writes a polished A4 attendance PDF (and grades page when snapshot is provided) to a temp file.
    @MainActor
    static func makeFile(
        subjects: [SubjectSummary],
        summary: FacultyDashboardSummary,
        generatedAt: Date = Date(),
        semesterStart: Date? = SemesterSettings.startDate,
        semesterEnd: Date? = SemesterSettings.endDate,
        grades: GradesReportSnapshot? = nil
    ) throws -> URL {
        guard subjects.isEmpty == false else {
            throw ExportError.emptySubjects
        }

        let attendancePages = pageModels(
            subjects: subjects,
            summary: summary,
            generatedAt: generatedAt,
            semesterStart: semesterStart,
            semesterEnd: semesterEnd,
            extraPageCount: grades == nil ? 0 : 1
        )

        let pageRect = CGRect(origin: .zero, size: AttendanceReportLayout.pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let totalPages = attendancePages.count + (grades == nil ? 0 : 1)

        let data = renderer.pdfData { context in
            for page in attendancePages {
                context.beginPage()
                let host = AttendanceReportPageView(model: page)
                draw(host, in: pageRect)
            }

            if let grades {
                context.beginPage()
                let host = GradesReportPageView(
                    model: GradesReportPageModel(
                        pageIndex: totalPages,
                        pageCount: totalPages,
                        generatedAt: generatedAt,
                        snapshot: grades
                    )
                )
                draw(host, in: pageRect)
            }
        }

        guard data.isEmpty == false else {
            throw ExportError.renderFailed
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "BunkPlanner-Report-\(formatter.string(from: generatedAt)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    @MainActor
    private static func draw<V: View>(_ view: V, in pageRect: CGRect) {
        let imageRenderer = ImageRenderer(content: view)
        imageRenderer.scale = 2
        imageRenderer.proposedSize = ProposedViewSize(
            width: AttendanceReportLayout.pageSize.width,
            height: AttendanceReportLayout.pageSize.height
        )
        if let image = imageRenderer.uiImage {
            image.draw(in: pageRect)
        }
    }
#endif

    static func pageModels(
        subjects: [SubjectSummary],
        summary: FacultyDashboardSummary,
        generatedAt: Date,
        semesterStart: Date?,
        semesterEnd: Date?,
        extraPageCount: Int = 0
    ) -> [AttendanceReportPageModel] {
        var chunks: [[SubjectSummary]] = []
        var remaining = subjects

        if remaining.isEmpty == false {
            let firstCount = min(AttendanceReportLayout.subjectsPerFirstPage, remaining.count)
            chunks.append(Array(remaining.prefix(firstCount)))
            remaining = Array(remaining.dropFirst(firstCount))
        }

        while remaining.isEmpty == false {
            let count = min(AttendanceReportLayout.subjectsPerNextPage, remaining.count)
            chunks.append(Array(remaining.prefix(count)))
            remaining = Array(remaining.dropFirst(count))
        }

        if chunks.isEmpty {
            chunks = [[]]
        }

        let pageCount = chunks.count + extraPageCount
        return chunks.enumerated().map { index, pageSubjects in
            AttendanceReportPageModel(
                id: index,
                pageIndex: index + 1,
                pageCount: pageCount,
                subjects: pageSubjects,
                summary: summary,
                generatedAt: generatedAt,
                semesterStart: semesterStart,
                semesterEnd: semesterEnd,
                isFirstPage: index == 0
            )
        }
    }
}
