//
//  GPAModels.swift
//  Student Attendance Predictor
//
//  US 4.0 GPA · UK module % · India 10-point CGPA (UGC-style).
//  Courses are grouped into AcademicTerm for SGPA-per-semester + archive.
//

import Foundation

// MARK: - US letter grades (4.0)

enum LetterGrade: String, CaseIterable, Identifiable, Codable {
    case aPlus = "A+"
    case a = "A"
    case aMinus = "A-"
    case bPlus = "B+"
    case b = "B"
    case bMinus = "B-"
    case cPlus = "C+"
    case c = "C"
    case cMinus = "C-"
    case dPlus = "D+"
    case d = "D"
    case f = "F"

    var id: String { rawValue }

    var points4_0: Double {
        switch self {
        case .aPlus, .a: return 4.0
        case .aMinus: return 3.7
        case .bPlus: return 3.3
        case .b: return 3.0
        case .bMinus: return 2.7
        case .cPlus: return 2.3
        case .c: return 2.0
        case .cMinus: return 1.7
        case .dPlus: return 1.3
        case .d: return 1.0
        case .f: return 0.0
        }
    }
}

// MARK: - India UGC-style 10-point grades

enum IndiaGrade: String, CaseIterable, Identifiable, Codable {
    case o = "O"
    case aPlus = "A+"
    case a = "A"
    case bPlus = "B+"
    case b = "B"
    case c = "C"
    case p = "P"
    case f = "F"

    var id: String { rawValue }

    var points10: Double {
        switch self {
        case .o: return 10
        case .aPlus: return 9
        case .a: return 8
        case .bPlus: return 7
        case .b: return 6
        case .c: return 5
        case .p: return 4
        case .f: return 0
        }
    }

    var subtitle: String {
        switch self {
        case .o: return "Outstanding"
        case .aPlus: return "Excellent"
        case .a: return "Very Good"
        case .bPlus: return "Good"
        case .b: return "Above Average"
        case .c: return "Average"
        case .p: return "Pass"
        case .f: return "Fail"
        }
    }
}

// MARK: - Term / semester

struct AcademicTerm: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var isArchived: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

struct GPACourse: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var credits: Double
    var grade: LetterGrade
    /// UK module mark (0–100). When set, this course is a UK module.
    var markPercent: Double?
    /// India 10-point letter. When set, this course uses the India CGPA calculator.
    var indiaGrade: IndiaGrade?
    /// UK year level (2 or 3 typically) for degree classification weighting.
    var ukYear: Int?
    /// Semester / term this course belongs to. Nil is migrated to the active term on load.
    var termID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        credits: Double,
        grade: LetterGrade = .b,
        markPercent: Double? = nil,
        indiaGrade: IndiaGrade? = nil,
        ukYear: Int? = nil,
        termID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.credits = max(0, credits)
        self.grade = grade
        self.markPercent = markPercent.map { min(100, max(0, $0)) }
        self.indiaGrade = indiaGrade
        self.ukYear = ukYear.map { min(4, max(1, $0)) }
        self.termID = termID
    }
}

enum GPACalculator {
    static func cumulativeGPA(courses: [GPACourse]) -> Double? {
        let usable = courses.filter { $0.indiaGrade == nil && $0.markPercent == nil }
        let totalCredits = usable.reduce(0.0) { $0 + $1.credits }
        guard totalCredits > 0 else { return nil }
        let points = usable.reduce(0.0) { $0 + ($1.credits * $1.grade.points4_0) }
        return points / totalCredits
    }

    static func indiaCGPA(courses: [GPACourse]) -> Double? {
        let modules = courses.filter { $0.indiaGrade != nil }
        let totalCredits = modules.reduce(0.0) { $0 + $1.credits }
        guard totalCredits > 0 else { return nil }
        let points = modules.reduce(0.0) { $0 + ($1.credits * ($1.indiaGrade?.points10 ?? 0)) }
        return points / totalCredits
    }

    static func indiaPercentage(fromCGPA cgpa: Double) -> Double {
        min(100, max(0, cgpa * 9.5))
    }

    static func ukClassification(averagePercent: Double) -> String {
        switch averagePercent {
        case 70...: return "First Class"
        case 60..<70: return "Upper Second (2:1)"
        case 50..<60: return "Lower Second (2:2)"
        case 40..<50: return "Third Class"
        default: return "Below pass"
        }
    }

    static func ukWeightedAverage(
        courses: [GPACourse],
        year2Weight: Double = 0.33,
        year3Weight: Double = 0.67
    ) -> Double? {
        let modules = courses.filter { $0.markPercent != nil }
        guard modules.isEmpty == false else { return nil }

        let withYear = modules.filter { ($0.ukYear ?? 0) >= 2 }
        if withYear.count >= 2,
           withYear.contains(where: { ($0.ukYear ?? 0) == 2 }),
           withYear.contains(where: { ($0.ukYear ?? 0) >= 3 }) {
            func avg(_ year: Int) -> Double? {
                let slice = modules.filter {
                    if year >= 3 { return ($0.ukYear ?? 0) >= 3 }
                    return ($0.ukYear ?? 0) == year
                }
                let credits = slice.reduce(0.0) { $0 + $1.credits }
                guard credits > 0 else { return nil }
                let weighted = slice.reduce(0.0) { $0 + ($1.credits * ($1.markPercent ?? 0)) }
                return weighted / credits
            }
            guard let y2 = avg(2), let y3 = avg(3) else {
                return flatUKAverage(modules)
            }
            let sum = year2Weight + year3Weight
            guard sum > 0 else { return flatUKAverage(modules) }
            return (y2 * year2Weight + y3 * year3Weight) / sum
        }

        return flatUKAverage(modules)
    }

    private static func flatUKAverage(_ modules: [GPACourse]) -> Double? {
        let totalCredits = modules.reduce(0.0) { $0 + $1.credits }
        guard totalCredits > 0 else { return nil }
        let weighted = modules.reduce(0.0) { $0 + ($1.credits * ($1.markPercent ?? 0)) }
        return weighted / totalCredits
    }

    static func letterForUKMark(_ percent: Double) -> LetterGrade {
        switch percent {
        case 70...: return .a
        case 60..<70: return .b
        case 50..<60: return .c
        case 40..<50: return .d
        default: return .f
        }
    }

    static func requiredAverageInRemaining(
        currentPoints: Double,
        currentCredits: Double,
        remainingCredits: Double,
        targetAverage: Double
    ) -> Double? {
        guard remainingCredits > 0 else { return nil }
        let totalCredits = currentCredits + remainingCredits
        let neededTotalPoints = targetAverage * totalCredits
        let neededFromRemaining = neededTotalPoints - currentPoints
        return neededFromRemaining / remainingCredits
    }
}

// MARK: - Snapshot for Pro PDF

struct GradesReportSnapshot {
    struct TermBlock: Identifiable {
        let id: UUID
        let name: String
        let isArchived: Bool
        let scoreLabel: String
        let scoreValue: String
        let rows: [(name: String, detail: String)]
    }

    let marketCode: String
    let overallLabel: String
    let overallValue: String
    let overallDetail: String?
    let terms: [TermBlock]
}

@MainActor
final class GPAStore: ObservableObject {
    @Published private(set) var courses: [GPACourse] = []
    @Published private(set) var terms: [AcademicTerm] = []
    @Published private(set) var activeTermID: UUID?

    private let coursesKey = "academics.gpa.courses"
    private let termsKey = "academics.gpa.terms"
    private let activeTermKey = "academics.gpa.activeTermID"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var activeTerm: AcademicTerm? {
        guard let id = activeTermID else { return terms.first(where: { $0.isArchived == false }) }
        return terms.first(where: { $0.id == id })
    }

    var activeCourses: [GPACourse] {
        guard let id = activeTermID ?? activeTerm?.id else { return courses }
        return courses.filter { $0.termID == id }
    }

    var archivedTerms: [AcademicTerm] {
        terms.filter(\.isArchived).sorted { $0.createdAt > $1.createdAt }
    }

    var openTerms: [AcademicTerm] {
        terms.filter { $0.isArchived == false }.sorted { $0.createdAt > $1.createdAt }
    }

    func courses(in termID: UUID) -> [GPACourse] {
        courses.filter { $0.termID == termID }
    }

    // MARK: Scores (active term = SGPA / term GPA; all = CGPA / cumulative)

    var gpa: Double? {
        GPACalculator.cumulativeGPA(courses: activeCourses)
    }

    var cumulativeGPA: Double? {
        GPACalculator.cumulativeGPA(courses: courses)
    }

    var ukAveragePercent: Double? {
        GPACalculator.ukWeightedAverage(courses: activeCourses)
    }

    var ukCumulativeAveragePercent: Double? {
        GPACalculator.ukWeightedAverage(courses: courses)
    }

    /// India: active-term SGPA.
    var indiaSGPA: Double? {
        GPACalculator.indiaCGPA(courses: activeCourses)
    }

    /// India: all-terms CGPA.
    var indiaCGPA: Double? {
        GPACalculator.indiaCGPA(courses: courses)
    }

    var indiaPercentage: Double? {
        guard let cgpa = indiaCGPA else { return nil }
        return GPACalculator.indiaPercentage(fromCGPA: cgpa)
    }

    func termScoreLabel(for market: StudentMarket) -> String {
        switch market {
        case .india: return "SGPA"
        case .unitedKingdom: return "Term %"
        case .unitedStates, .other: return "Term GPA"
        }
    }

    func overallScoreLabel(for market: StudentMarket) -> String {
        switch market {
        case .india: return "CGPA"
        case .unitedKingdom: return "Overall %"
        case .unitedStates, .other: return "Cumulative GPA"
        }
    }

    /// One-line summary for the Tools hub row.
    func toolsScoreSummary(market: StudentMarket) -> String? {
        let courseCount = activeCourses.count
        switch market {
        case .india:
            guard let cgpa = indiaCGPA else { return nil }
            let courses = courseCount == 1 ? "1 subject" : "\(courseCount) subjects"
            return String(format: "%.2f CGPA · %@", cgpa, courses)
        case .unitedKingdom:
            guard let average = ukCumulativeAveragePercent ?? ukAveragePercent else { return nil }
            let modules = courseCount == 1 ? "1 module" : "\(moduleCountLabel(courseCount))"
            return String(format: "%.0f%% · %@", average, modules)
        case .unitedStates, .other:
            guard let gpa = cumulativeGPA ?? gpa else { return nil }
            let courses = courseCount == 1 ? "1 course" : "\(courseCount) courses"
            return String(format: "%.2f GPA · %@", gpa, courses)
        }
    }

    private func moduleCountLabel(_ count: Int) -> String {
        "\(count) modules"
    }

    func score(for termID: UUID, market: StudentMarket) -> Double? {
        let slice = courses(in: termID)
        switch market {
        case .india: return GPACalculator.indiaCGPA(courses: slice)
        case .unitedKingdom: return GPACalculator.ukWeightedAverage(courses: slice)
        case .unitedStates, .other: return GPACalculator.cumulativeGPA(courses: slice)
        }
    }

    // MARK: Mutations

    func addCourse(name: String, credits: Double, grade: LetterGrade, termID: UUID? = nil) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let course = GPACourse(
            name: cleaned.isEmpty ? "Course \(courses.count + 1)" : cleaned,
            credits: credits,
            grade: grade,
            termID: termID ?? ensureActiveTermID()
        )
        courses.append(course)
        persist()
        AnalyticsService.shared.log(.academicCourseAdded(market: "US", total: courses.count))
    }

    func addUKModule(name: String, credits: Double, markPercent: Double, year: Int? = nil, termID: UUID? = nil) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clamped = min(100, max(0, markPercent))
        let course = GPACourse(
            name: cleaned.isEmpty ? "Module \(courses.count + 1)" : cleaned,
            credits: credits,
            grade: GPACalculator.letterForUKMark(clamped),
            markPercent: clamped,
            ukYear: year,
            termID: termID ?? ensureActiveTermID()
        )
        courses.append(course)
        persist()
        AnalyticsService.shared.log(.academicCourseAdded(market: "GB", total: courses.count))
    }

    func addIndiaSubject(name: String, credits: Double, grade: IndiaGrade, termID: UUID? = nil) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let course = GPACourse(
            name: cleaned.isEmpty ? "Subject \(courses.count + 1)" : cleaned,
            credits: credits,
            grade: .b,
            indiaGrade: grade,
            termID: termID ?? ensureActiveTermID()
        )
        courses.append(course)
        persist()
        AnalyticsService.shared.log(.academicCourseAdded(market: "IN", total: courses.count))
    }

    func update(_ course: GPACourse) {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else { return }
        var next = course
        if let mark = next.markPercent {
            next.grade = GPACalculator.letterForUKMark(mark)
        }
        if next.termID == nil {
            next.termID = ensureActiveTermID()
        }
        courses[index] = next
        persist()
        AnalyticsService.shared.log(.academicCourseUpdated)
    }

    func delete(id: UUID) {
        courses.removeAll { $0.id == id }
        persist()
        AnalyticsService.shared.log(.academicCourseDeleted(total: courses.count))
    }

    func selectTerm(_ id: UUID) {
        guard terms.contains(where: { $0.id == id }) else { return }
        activeTermID = id
        defaults.set(id.uuidString, forKey: activeTermKey)
    }

    /// Archives the active term and opens a fresh one for the next semester.
    @discardableResult
    func archiveActiveTermAndStartNew(named name: String? = nil) -> AcademicTerm {
        if let active = activeTerm, active.isArchived == false {
            if let index = terms.firstIndex(where: { $0.id == active.id }) {
                terms[index].isArchived = true
            }
        }
        let label = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? nextTermDefaultName()
        let term = AcademicTerm(name: label, isArchived: false)
        terms.append(term)
        activeTermID = term.id
        defaults.set(term.id.uuidString, forKey: activeTermKey)
        persist()
        AnalyticsService.shared.log(.academicTermArchived)
        return term
    }

    func renameTerm(id: UUID, to name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false,
              let index = terms.firstIndex(where: { $0.id == id }) else { return }
        terms[index].name = cleaned
        persist()
    }

    func makeGradesReportSnapshot(market: StudentMarket) -> GradesReportSnapshot? {
        guard courses.isEmpty == false else { return nil }

        let overallLabel = overallScoreLabel(for: market)
        let overallValue: String
        let overallDetail: String?
        switch market {
        case .india:
            guard let cgpa = indiaCGPA else { return nil }
            overallValue = String(format: "%.2f / 10", cgpa)
            if let pct = indiaPercentage {
                overallDetail = String(format: "~%.0f%% (× 9.5)", pct)
            } else {
                overallDetail = nil
            }
        case .unitedKingdom:
            guard let avg = ukCumulativeAveragePercent else { return nil }
            overallValue = String(format: "%.0f%%", avg)
            overallDetail = GPACalculator.ukClassification(averagePercent: avg)
        case .unitedStates, .other:
            guard let gpa = cumulativeGPA else { return nil }
            overallValue = String(format: "%.2f / 4.0", gpa)
            overallDetail = "\(courses.count) course\(courses.count == 1 ? "" : "s")"
        }

        let orderedTerms = terms.sorted { $0.createdAt > $1.createdAt }
        let blocks: [GradesReportSnapshot.TermBlock] = orderedTerms.compactMap { term in
            let slice = courses(in: term.id)
            guard slice.isEmpty == false else { return nil }
            let scoreValue: String
            switch market {
            case .india:
                guard let sgpa = GPACalculator.indiaCGPA(courses: slice) else { return nil }
                scoreValue = String(format: "%.2f", sgpa)
            case .unitedKingdom:
                guard let avg = GPACalculator.ukWeightedAverage(courses: slice) else { return nil }
                scoreValue = String(format: "%.0f%%", avg)
            case .unitedStates, .other:
                guard let gpa = GPACalculator.cumulativeGPA(courses: slice) else { return nil }
                scoreValue = String(format: "%.2f", gpa)
            }
            let rows = slice.map { course -> (String, String) in
                let detail: String
                if let india = course.indiaGrade {
                    detail = "\(course.credits.cleanCredits) cr · \(india.rawValue)"
                } else if let mark = course.markPercent {
                    let year = course.ukYear.map { " · Y\($0)" } ?? ""
                    detail = "\(course.credits.cleanCredits) cr · \(String(format: "%.0f%%", mark))\(year)"
                } else {
                    detail = "\(course.credits.cleanCredits) cr · \(course.grade.rawValue)"
                }
                return (course.name, detail)
            }
            return GradesReportSnapshot.TermBlock(
                id: term.id,
                name: term.name,
                isArchived: term.isArchived,
                scoreLabel: termScoreLabel(for: market),
                scoreValue: scoreValue,
                rows: rows
            )
        }
        guard blocks.isEmpty == false else { return nil }

        return GradesReportSnapshot(
            marketCode: market.rawValue,
            overallLabel: overallLabel,
            overallValue: overallValue,
            overallDetail: overallDetail,
            terms: blocks
        )
    }

    // MARK: Persistence

    private func load() {
        if let data = defaults.data(forKey: coursesKey),
           let decoded = try? JSONDecoder().decode([GPACourse].self, from: data) {
            courses = decoded
        } else {
            courses = []
        }

        if let data = defaults.data(forKey: termsKey),
           let decoded = try? JSONDecoder().decode([AcademicTerm].self, from: data) {
            terms = decoded
        } else {
            terms = []
        }

        migrateTermsIfNeeded()
    }

    /// Ensures at least one open term exists and backfills `termID` on legacy courses.
    private func migrateTermsIfNeeded() {
        if terms.isEmpty {
            let term = AcademicTerm(name: "Current semester")
            terms = [term]
            activeTermID = term.id
        } else if let stored = defaults.string(forKey: activeTermKey).flatMap(UUID.init(uuidString:)),
                  terms.contains(where: { $0.id == stored }) {
            activeTermID = stored
        } else if let open = terms.first(where: { $0.isArchived == false }) {
            activeTermID = open.id
        } else {
            activeTermID = terms.first?.id
        }

        let fallback = ensureActiveTermID()
        var changed = false
        for index in courses.indices where courses[index].termID == nil {
            courses[index].termID = fallback
            changed = true
        }
        if changed || defaults.data(forKey: termsKey) == nil {
            persist()
        } else {
            defaults.set(fallback.uuidString, forKey: activeTermKey)
        }
    }

    @discardableResult
    private func ensureActiveTermID() -> UUID {
        if let id = activeTermID, terms.contains(where: { $0.id == id }) {
            return id
        }
        if let open = terms.first(where: { $0.isArchived == false }) {
            activeTermID = open.id
            return open.id
        }
        let term = AcademicTerm(name: "Current semester")
        terms.append(term)
        activeTermID = term.id
        return term.id
    }

    private func nextTermDefaultName() -> String {
        let count = terms.count + 1
        return "Semester \(count)"
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(courses) {
            defaults.set(data, forKey: coursesKey)
        }
        if let data = try? JSONEncoder().encode(terms) {
            defaults.set(data, forKey: termsKey)
        }
        if let activeTermID {
            defaults.set(activeTermID.uuidString, forKey: activeTermKey)
        }
    }
}

private extension Double {
    var cleanCredits: String {
        rounded() == self ? String(Int(self)) : String(format: "%.1f", self)
    }
}
