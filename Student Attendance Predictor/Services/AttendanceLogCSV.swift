//
//  AttendanceLogCSV.swift
//  Student Attendance Predictor
//
//  Pro CSV export of current subject snapshot + daily attendance log.
//

import Foundation

enum AttendanceLogCSV {
    enum ExportError: LocalizedError {
        case emptySubjects
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .emptySubjects:
                return "Add at least one subject before exporting a CSV."
            case .writeFailed:
                return "Couldn't create the CSV. Please try again."
            }
        }
    }

    /// Writes a CSV to a temp file. Returns the file URL and data-row count (excluding headers).
    static func makeFile(
        entries: [AttendanceLogEntry],
        subjects: [SubjectSummary],
        generatedAt: Date = Date()
    ) throws -> (url: URL, rowCount: Int) {
        guard subjects.isEmpty == false else {
            throw ExportError.emptySubjects
        }

        let names = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0.name) })
        let iso = Self.dayFormatter
        let stamp = Self.fileStampFormatter.string(from: generatedAt)

        var lines: [String] = []
        lines.append("# Bunk Planner attendance export")
        lines.append("# Generated \(stamp)")
        lines.append("")
        lines.append("Subject,Total classes,Attended,Missed,Percentage,Target %,Status")
        for subject in subjects.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let missed = max(0, subject.totalClasses - subject.attendedClasses)
            lines.append(
                [
                    csv(subject.name),
                    "\(subject.totalClasses)",
                    "\(subject.attendedClasses)",
                    "\(missed)",
                    String(format: "%.2f", subject.currentPercentage),
                    String(format: "%.0f", subject.requiredPercentage),
                    csv(subject.status.rawValue)
                ].joined(separator: ",")
            )
        }

        lines.append("")
        lines.append("Date,Subject,Scheduled,Attended,Missed,Holiday")
        let sortedEntries = entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            let leftName = names[lhs.subjectID] ?? ""
            let rightName = names[rhs.subjectID] ?? ""
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }
        for entry in sortedEntries {
            let missed = entry.isHoliday ? 0 : max(0, entry.totalContribution - entry.attendedContribution)
            lines.append(
                [
                    iso.string(from: entry.date),
                    csv(names[entry.subjectID] ?? "Subject"),
                    "\(entry.scheduledClasses)",
                    "\(entry.attendedClasses)",
                    "\(missed)",
                    entry.isHoliday ? "yes" : "no"
                ].joined(separator: ",")
            )
        }

        let body = lines.joined(separator: "\n") + "\n"
        guard let data = body.data(using: .utf8) else {
            throw ExportError.writeFailed
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BunkPlanner-Attendance-\(stamp).csv")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed
        }
        return (url, subjects.count + sortedEntries.count)
    }

    private static func csv(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}
