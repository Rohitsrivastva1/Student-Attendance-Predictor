//
//  StudyTaskExtractService.swift
//  Student Attendance Predictor
//
//  Photo text stays on device. Only confirmed text is sent to Schoolabe / Groq.
//

import Foundation
import Combine

@MainActor
final class StudyTaskExtractLog: ObservableObject {
    static let shared = StudyTaskExtractLog()

    @Published private(set) var lines: [String] = []

    var text: String { lines.joined(separator: "\n") }

    func clear() {
        lines = []
    }

    func append(_ message: String) {
        let stamp = Self.clock.string(from: Date())
        lines.append("\(stamp)  \(message)")
        if lines.count > 250 {
            lines.removeFirst(lines.count - 250)
        }
        NSLog("[TasksExtract] %@", message)
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

enum StudyTaskExtractError: LocalizedError, Equatable {
    case emptyText
    case notConfigured
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyText: return "Add some text first."
        case .notConfigured: return "Couldn’t reach AI. Using a local read instead."
        case .invalidResponse: return "Couldn’t read that text. Edit the list before adding."
        }
    }
}

struct StudyTaskExtractResponse: Decodable {
    struct ItemDTO: Decodable {
        let title: String?
        let kind: String?
        let subject_name: String?
        let due_date: String?
        let topics: [String]?
    }

    let items: [ItemDTO]?
    let error: String?
}

@MainActor
final class StudyTaskExtractService {
    static let shared = StudyTaskExtractService()

    private let session: URLSession
    private let maxChars = 12_000

    init(session: URLSession = .shared) {
        self.session = session
    }

    func extract(
        rawText: String,
        subjectNames: [String],
        market: String,
        laidOutRows: String? = nil
    ) async -> (drafts: [StudyTaskDraft], usedAI: Bool) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return ([], false) }

        let rows = laidOutRows?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let gluedRows = rows.isEmpty ? "" : Self.glueOrphanHomework(rows, knownSubjects: subjectNames)
        let payload: String
        if gluedRows.isEmpty == false, gluedRows != trimmed {
            Self.log("LAYOUT rows from photo positions:\n\(gluedRows)")
            payload = """
            DIARY ROWS (already paired from photo layout — trust this pairing):
            \(gluedRows)

            RAW OCR (spelling only; do not re-zip this):
            \(trimmed)
            """
        } else if Self.looksAlreadyPaired(trimmed) {
            payload = Self.glueOrphanHomework(trimmed, knownSubjects: subjectNames)
        } else {
            let paired = Self.pairDiaryColumns(from: trimmed, knownSubjects: subjectNames)
            let glued = Self.glueOrphanHomework(paired, knownSubjects: subjectNames)
            if glued != trimmed {
                Self.log("PAIRED diary columns before SEND:\n\(glued)")
            }
            payload = glued
        }

        do {
            let remote = try await extractRemoteWithRetry(
                rawText: payload,
                subjectNames: subjectNames + Self.diarySubjectNames(in: gluedRows.isEmpty ? trimmed : gluedRows),
                market: market
            )
            if remote.isEmpty == false {
                let snapped = Self.applyDefaultDue(Self.snapSubjects(remote, known: subjectNames))
                Self.log("SHOW drafts from BE (\(snapped.count))")
                Self.logDrafts(snapped)
                return (snapped, true)
            }
            Self.log("BE returned 0 items — falling back to local parse")
        } catch {
            Self.log("BE extract failed: \(error.localizedDescription) — falling back to local parse")
        }
        let localSource = gluedRows.isEmpty ? payload : gluedRows
        let local = Self.applyDefaultDue(
            Self.snapSubjects(
                Self.heuristicDrafts(from: localSource, subjectNames: subjectNames),
                known: subjectNames
            )
        )
        let cleanedLocal = local.count > 1
            ? local.filter { $0.title.caseInsensitiveCompare("Exam prep") != .orderedSame }
            : local
        Self.log("SHOW drafts from local parse (\(cleanedLocal.count))")
        Self.logDrafts(cleanedLocal)
        return (cleanedLocal, false)
    }

    private func extractRemoteWithRetry(
        rawText: String,
        subjectNames: [String],
        market: String
    ) async throws -> [StudyTaskDraft] {
        var lastError: Error = StudyTaskExtractError.invalidResponse
        for attempt in 1...2 {
            do {
                return try await extractRemote(
                    rawText: rawText,
                    subjectNames: subjectNames,
                    market: market
                )
            } catch StudyTaskExtractError.notConfigured {
                throw StudyTaskExtractError.notConfigured
            } catch {
                lastError = error
                Self.log("BE extract attempt \(attempt) failed: \(error.localizedDescription)")
            }
        }
        throw lastError
    }

    private func extractRemote(
        rawText: String,
        subjectNames: [String],
        market: String
    ) async throws -> [StudyTaskDraft] {
        guard let url = SchoolabeAPIConfiguration.tasksExtractURL else {
            throw StudyTaskExtractError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("BunkPlanner/iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 45

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let body: [String: Any] = [
            "client_user_id": AnalyticsService.shared.userId,
            "raw_text": String(rawText.prefix(maxChars)),
            "market": market,
            "subject_names": subjectNames,
            "today": formatter.string(from: Date())
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let payload = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        Self.log("SEND \(url.absoluteString)")
        Self.log("SEND body:\n\(payload)")

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? -1
        let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        Self.log("RECV HTTP \(status)")
        Self.log("RECV body:\n\(raw)")

        guard let http, (200...299).contains(http.statusCode) else {
            throw StudyTaskExtractError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(StudyTaskExtractResponse.self, from: data)
        if let err = decoded.error, err.isEmpty == false {
            Self.log("RECV error field: \(err)")
            throw StudyTaskExtractError.invalidResponse
        }
        let drafts = (decoded.items ?? []).compactMap { Self.draft(from: $0, today: Date()) }
        Self.log("MAPPED \(drafts.count) draft(s) from \(decoded.items?.count ?? 0) BE item(s)")
        guard drafts.isEmpty == false else { throw StudyTaskExtractError.invalidResponse }
        return drafts
    }

    static func snapSubjects(_ drafts: [StudyTaskDraft], known: [String]) -> [StudyTaskDraft] {
        drafts.map { draft in
            var next = draft
            next.subjectName = snapSubject(draft.subjectName, known: known)
            return next
        }
    }

    static func snapSubject(_ name: String, known: [String]) -> String {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.isEmpty == false else { return "" }
        let lower = needle.lowercased()
        if ["general", "none", "unknown", "other", "n/a", "na"].contains(lower) {
            return ""
        }
        if let exact = known.first(where: { $0.lowercased() == lower }) {
            return exact
        }
        guard needle.count >= 4 else { return needle }
        if let partial = known.first(where: { knownName in
            let key = knownName.lowercased()
            guard key.count >= 4 else { return false }
            return key.contains(lower) || lower.contains(key)
        }) {
            return partial
        }
        return Self.canonicalSchoolSubject(needle)
    }

    static func looksAlreadyPaired(_ text: String) -> Bool {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard lines.count >= 3 else { return false }
        let paired = lines.filter { line in
            guard let colon = line.firstIndex(of: ":") else { return false }
            let left = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let right = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            return left.count >= 2 && left.count <= 28 && right.isEmpty == false
        }
        return paired.count * 2 >= lines.count
    }

    /// Attach leftover homework lines to the subject above them.
    static func glueOrphanHomework(_ text: String, knownSubjects: [String]) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard lines.count >= 2 else { return text }

        var out: [String] = []
        for line in lines {
            if let colon = line.firstIndex(of: ":") {
                let left = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                if isBareSubjectLine(left, known: knownSubjects) {
                    out.append(line)
                    continue
                }
            }
            if isBareSubjectLine(line, known: knownSubjects) {
                out.append(canonicalSchoolSubject(line))
                continue
            }
            if let last = out.last {
                if last.contains(":") {
                    out[out.count - 1] = "\(last) \(line)"
                } else {
                    out[out.count - 1] = "\(last): \(line)"
                }
                continue
            }
            out.append(line)
        }
        return out.joined(separator: "\n")
    }

    static func isBareSubjectLine(_ line: String, known: [String]) -> Bool {
        if line.contains(":") { return false }
        if isDiarySubjectLine(line, known: known) { return true }
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(whereSeparator: { $0.isWhitespace })
        guard words.count <= 2, cleaned.count >= 3, cleaned.count <= 22 else { return false }
        if cleaned.filter(\.isNumber).isEmpty == false { return false }
        let lower = cleaned.lowercased()
        if ["learn", "write", "draw", "reading", "activity", "classwork", "homework"].contains(where: { lower.contains($0) }) {
            return false
        }
        return true
    }

    /// School diary OCR often reads the subject column first, then all homework.
    /// Zip them so Groq gets `English: Pg#43 Q#3` instead of two disconnected lists.
    static func pairDiaryColumns(from text: String, knownSubjects: [String]) -> String {
        if looksAlreadyPaired(text) { return text }
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard lines.count >= 4 else { return text }

        var subjects: [String] = []
        var rest: [String] = []
        var collectingSubjects = true
        for line in lines {
            if collectingSubjects, isDiarySubjectLine(line, known: knownSubjects) {
                subjects.append(canonicalSchoolSubject(line))
            } else {
                collectingSubjects = false
                rest.append(line)
            }
        }

        guard subjects.count >= 3, rest.count >= 2 else { return text }
        var homework = expandMergedClasswork(rest, extraSlots: max(0, subjects.count - rest.count))
        let count = min(subjects.count, homework.count)
        var paired = (0..<count).map { "\(subjects[$0]): \(homework[$0])" }
        if homework.count > count {
            paired.append(contentsOf: homework[count...])
        }
        return paired.joined(separator: "\n")
    }

    /// When OCR glues two short C.W lines (Science + Maths), split so zip stays aligned.
    static func expandMergedClasswork(_ lines: [String], extraSlots: Int) -> [String] {
        guard extraSlots > 0 else { return lines }
        var result = lines
        var needed = extraSlots
        var index = 0
        while needed > 0, index < result.count {
            let line = result[index]
            if let parts = splitMergedClasswork(line), parts.count == 2 {
                result.replaceSubrange(index...index, with: parts)
                needed -= 1
                index += 2
                continue
            }
            index += 1
        }
        return result
    }

    static func splitMergedClasswork(_ line: String) -> [String]? {
        let lower = line.lowercased()
        if lower.contains("pg") || lower.contains("unit") || lower.contains("map")
            || lower.contains("test") || lower.contains("q#") || lower.contains("q ") {
            return nil
        }
        let tokens = line
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
        guard tokens.count == 2, tokens.allSatisfy({ $0.count <= 16 }) else { return nil }
        let looksLikeCW = tokens.contains { token in
            let t = token.lowercased().replacingOccurrences(of: ".", with: "")
            return t.contains("cw") || t.contains("hw") || t.contains("ish") || t.contains("cin")
        }
        guard looksLikeCW || line.count <= 18 else { return nil }
        return tokens
    }

    static func diarySubjectNames(in text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isDiarySubjectLine($0, known: []) }
            .map { canonicalSchoolSubject($0) }
    }

    private static let schoolSubjectKeys: [(match: String, label: String)] = [
        ("islam", "Islamiat"),
        ("islamiyat", "Islamiat"),
        ("islamiat", "Islamiat"),
        ("islamial", "Islamiat"),
        ("isamiat", "Islamiat"),
        ("english", "English"),
        ("science", "Science"),
        ("math", "Maths"),
        ("urdu", "Urdu"),
        ("hindi", "Hindi"),
        ("punjabi", "Punjabi"),
        ("sst", "S. Studies"),
        ("social", "S. Studies"),
        ("studies", "S. Studies"),
        ("computer", "Computer"),
        ("physics", "Physics"),
        ("chemistry", "Chemistry"),
        ("biology", "Biology"),
        ("history", "History"),
        ("geography", "Geography"),
        ("drawing", "Drawing"),
        ("gk", "GK")
    ]

    static func isDiarySubjectLine(_ line: String, known: [String]) -> Bool {
        let cleaned = line
            .lowercased()
            .replacingOccurrences(of: #"^\d+\.?\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count >= 2, cleaned.count <= 24 else { return false }
        if line.contains(":") { return false }
        if line.range(of: #"\d{2,}"#, options: .regularExpression) != nil { return false }
        if known.contains(where: { $0.lowercased() == cleaned || cleaned.contains($0.lowercased()) }) {
            return true
        }
        return schoolSubjectKeys.contains { key in
            cleaned == key.match
                || (key.match.count >= 4 && (cleaned.hasPrefix(key.match) || cleaned.contains(key.match)))
                || (cleaned.count >= 4 && key.match.hasPrefix(cleaned))
        }
    }

    static func canonicalSchoolSubject(_ line: String) -> String {
        let cleaned = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\d+\.?\s*"#, with: "", options: .regularExpression)
        let lower = cleaned.lowercased()
        if let match = schoolSubjectKeys.first(where: { lower.contains($0.match) }) {
            return match.label
        }
        return cleaned
    }

    static func log(_ message: String) {
        StudyTaskExtractLog.shared.append(message)
    }

    static func logDrafts(_ drafts: [StudyTaskDraft]) {
        for (index, draft) in drafts.enumerated() {
            let due = draft.dueDate.map { isoDate($0) } ?? "nil"
            log("SHOW[\(index)] selected=\(draft.isSelected) kind=\(draft.kind.rawValue) subject=\(draft.subjectName.isEmpty ? "—" : draft.subjectName) due=\(due) flagged=\(draft.isDateFlagged) title=\(draft.title)")
            if draft.topicsText.isEmpty == false {
                log("SHOW[\(index)] topics=\(draft.topicsText.replacingOccurrences(of: "\n", with: " | "))")
            }
        }
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func heuristicDrafts(from rawText: String, subjectNames: [String]) -> [StudyTaskDraft] {
        let today = Date()
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false && $0.count > 1 }
            .prefix(40)

        let diaryPairs = lines.filter { line in
            guard let colon = line.firstIndex(of: ":") else { return false }
            let left = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            return isDiarySubjectLine(left, known: subjectNames) || left.count <= 22
        }.count

        let looksLikeSyllabus = diaryPairs < 2 && lines.filter {
            $0.lowercased().hasPrefix("unit")
                || $0.lowercased().hasPrefix("chapter")
                || $0.lowercased().hasPrefix("module")
                || $0.hasPrefix("-")
                || $0.hasPrefix("•")
        }.count >= 3

        if looksLikeSyllabus {
            let topics = lines
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-•* ").union(.whitespaces)) }
                .filter { $0.count > 2 }
            let subject = subjectNames.first { rawText.localizedCaseInsensitiveContains($0) } ?? ""
            return [
                StudyTaskDraft(
                    title: subject.isEmpty ? "Exam prep" : "\(subject) exam",
                    kind: .exam,
                    subjectName: subject,
                    dueDate: nil,
                    topicsText: topics.prefix(20).joined(separator: "\n"),
                    isDateFlagged: true
                )
            ]
        }

        var drafts: [StudyTaskDraft] = []
        for line in lines {
            let cleaned = line.replacingOccurrences(of: "•", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "-* ").union(.whitespaces))
            guard cleaned.count > 2 else { continue }
            if cleaned.lowercased().contains("see diary") { continue }
            if isDiarySubjectLine(cleaned, known: subjectNames), cleaned.contains(":") == false {
                continue
            }
            var title = cleaned
            var subject = subjectNames.first { cleaned.localizedCaseInsensitiveContains($0) } ?? ""
            if let colon = cleaned.firstIndex(of: ":") {
                let left = String(cleaned[..<colon]).trimmingCharacters(in: .whitespaces)
                let right = String(cleaned[cleaned.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if isDiarySubjectLine(left, known: subjectNames), right.isEmpty == false {
                    subject = canonicalSchoolSubject(left)
                    title = right
                }
            }
            let kind = StudyTaskKind.inferred(from: title)
            let parsed = parseDate(in: title, today: today)
            drafts.append(
                StudyTaskDraft(
                    title: String(cleanedTitle(title).prefix(80)),
                    kind: kind,
                    subjectName: subject,
                    dueDate: parsed,
                    isDateFlagged: parsed == nil && kind != .other
                )
            )
        }

        if drafts.isEmpty {
            let first = String(rawText.prefix(80))
                .replacingOccurrences(of: "\n", with: " ")
            drafts = [
                StudyTaskDraft(
                    title: first,
                    kind: StudyTaskKind.inferred(from: rawText),
                    subjectName: subjectNames.first { rawText.localizedCaseInsensitiveContains($0) } ?? "",
                    isDateFlagged: true
                )
            ]
        }
        return drafts
    }

    private static func draft(from dto: StudyTaskExtractResponse.ItemDTO, today: Date) -> StudyTaskDraft? {
        let title = (dto.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return nil }
        if title.lowercased().contains("see diary") { return nil }
        let kind = StudyTaskKind(rawValue: (dto.kind ?? "").lowercased())
            ?? StudyTaskKind.inferred(from: title)
        let due = parseISODate(dto.due_date) ?? parseDate(in: dto.due_date ?? "", today: today)
        let topics = (dto.topics ?? []).joined(separator: "\n")
        return StudyTaskDraft(
            title: String(cleanedTitle(title).prefix(80)),
            kind: kind,
            subjectName: dto.subject_name ?? "",
            dueDate: due,
            topicsText: topics,
            isDateFlagged: due == nil && kind != .other
        )
    }

    /// If the photo has no date, the task is due tomorrow.
    static func applyDefaultDue(_ drafts: [StudyTaskDraft], today: Date = Date()) -> [StudyTaskDraft] {
        let tomorrow = nextDay(from: today)
        return drafts.map { draft in
            var next = draft
            guard next.dueDate == nil else { return next }
            next.dueDate = tomorrow
            next.isDateFlagged = true
            return next
        }
    }

    static func nextDay(from today: Date = Date()) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: today)) ?? today
    }

    static func cleanedTitle(_ title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let colon = text.firstIndex(of: ":") {
            let left = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
            let right = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if isDiarySubjectLine(left, known: []), right.isEmpty == false {
                text = right
            }
        }
        return text
    }

    private static func parseISODate(_ raw: String?) -> Date? {
        guard let raw, raw.isEmpty == false else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    static func parseDate(in text: String, today: Date) -> Date? {
        let cal = Calendar.current
        let lower = text.lowercased()
        if lower.contains("day after tomorrow") {
            return cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: today))
        }
        if lower.contains("tomorrow") {
            return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: today))
        }
        if lower.contains("today") {
            return cal.startOfDay(for: today)
        }

        let patterns = [
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "dd/MM",
            "dd-MM",
            "d MMM",
            "d MMMM",
            "MMM d"
        ]
        for pattern in patterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pattern
            let tokens = text.split(whereSeparator: { $0.isWhitespace || ",.;".contains($0) }).map(String.init)
            for token in tokens {
                if let date = formatter.date(from: token) {
                    return normalizeYear(date, today: today, calendar: cal)
                }
            }
            // Try sliding windows of two tokens (24 Sep)
            if tokens.count >= 2 {
                for i in 0..<(tokens.count - 1) {
                    let pair = "\(tokens[i]) \(tokens[i + 1])"
                    if let date = formatter.date(from: pair) {
                        return normalizeYear(date, today: today, calendar: cal)
                    }
                }
            }
        }
        return nil
    }

    private static func normalizeYear(_ date: Date, today: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.month, .day], from: date)
        let todayParts = calendar.dateComponents([.year, .month, .day], from: today)
        parts.year = todayParts.year
        guard let thisYear = calendar.date(from: parts) else { return date }
        if thisYear < calendar.startOfDay(for: today) {
            parts.year = (todayParts.year ?? 0) + 1
            return calendar.date(from: parts) ?? thisYear
        }
        return thisYear
    }
}
