//
//  AttendanceViewModel.swift
//  Student Attendance Predictor
//

import Combine
import CoreData
import Foundation

@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published var totalClassesInput: String {
        didSet {
            let sanitized = sanitizeIntegerInput(totalClassesInput)
            if totalClassesInput != sanitized {
                totalClassesInput = sanitized
            }
        }
    }
    @Published var attendedClassesInput: String {
        didSet {
            let sanitized = sanitizeIntegerInput(attendedClassesInput)
            if attendedClassesInput != sanitized {
                attendedClassesInput = sanitized
            }
        }
    }
    @Published var requiredPercentageInput: String {
        didSet {
            let sanitized = sanitizePercentageInput(requiredPercentageInput)
            if requiredPercentageInput != sanitized {
                requiredPercentageInput = sanitized
            }
        }
    }
    @Published private(set) var result: AttendanceResult?
    @Published private(set) var validationMessage: String?
    @Published private(set) var reviewRequestToken: Int = 0

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private var lastSafeCountSignature: String?
    private var lastLoggedCalcSignature: String?
    private var suppressReviewTracking = false
    private var isApplyingSubjectLoad = false

    private enum Keys {
        static let defaultRequiredPercentage = "attendance.defaultRequiredPercentage"
        static let safeCalculationCount = "attendance.safeCalculationCount"
        static let didPromptForReview = "attendance.didPromptForReview"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultRequired = Self.sanitizedPercentageInput(defaults.string(forKey: Keys.defaultRequiredPercentage) ?? "75")
        self.totalClassesInput = ""
        self.attendedClassesInput = ""
        self.requiredPercentageInput = defaultRequired
        bindDebouncedCalculation()
        calculate()
    }

    private func bindDebouncedCalculation() {
        Publishers.CombineLatest3(
            $totalClassesInput,
            $attendedClassesInput,
            $requiredPercentageInput
        )
        .dropFirst()
        .removeDuplicates { previous, current in
            previous.0 == current.0 && previous.1 == current.1 && previous.2 == current.2
        }
        .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
        .sink { [weak self] _, _, _ in
            guard let self, !self.isApplyingSubjectLoad else { return }
            self.calculate()
        }
        .store(in: &cancellables)
    }

    var totalClasses: Int { Int(totalClassesInput) ?? 0 }
    var attendedClasses: Int { Int(attendedClassesInput) ?? 0 }
    var requiredPercentage: Double { Double(requiredPercentageInput) ?? 75 }
    var defaultRequiredPercentage: Double { Double(defaults.string(forKey: Keys.defaultRequiredPercentage) ?? "75") ?? 75 }

    func calculate() {
        guard let input = validatedInput() else {
            result = nil
            return
        }

        validationMessage = nil
        let computedResult = makeResult(from: input)
        result = computedResult
        trackReviewTriggerIfNeeded(input: input, result: computedResult)
        logCalculationIfChanged(input: input, result: computedResult)
    }

    /// Logs a `calculation_completed` event only when the produced result is
    /// meaningfully different, so live (debounced) recalculation on each keystroke
    /// doesn't flood analytics.
    private func logCalculationIfChanged(input: AttendanceInput, result: AttendanceResult) {
        let signature = "\(result.status)|\(Int(result.currentPercentage.rounded()))|\(Int(input.requiredPercentage.rounded()))"
        guard signature != lastLoggedCalcSignature else { return }
        lastLoggedCalcSignature = signature
        AnalyticsService.shared.log(.calculationCompleted(
            status: result.status == .safe ? "safe" : "risk",
            currentPercentage: Int(result.currentPercentage.rounded()),
            requiredPercentage: Int(input.requiredPercentage.rounded())
        ))
        let riskStatus: String
        if result.status == .safe {
            riskStatus = "safe"
        } else if result.recoveryNeeded >= 5 {
            riskStatus = "critical"
        } else {
            riskStatus = "at_risk"
        }
        if riskStatus != "safe" {
            AnalyticsService.shared.log(.attendanceAtRiskShown(
                currentPct: Int(result.currentPercentage.rounded()),
                status: riskStatus
            ))
        }
    }

    func simulatedResult(attendMore: Int = 0, skipMore: Int = 0) -> AttendanceResult? {
        guard let input = validatedInput(showValidation: false) else {
            return nil
        }

        let simulatedInput = AttendanceInput(
            totalClasses: input.totalClasses + attendMore + skipMore,
            attendedClasses: input.attendedClasses + attendMore,
            requiredPercentage: input.requiredPercentage
        )

        return makeResult(from: simulatedInput)
    }

    func updateDefaultRequiredPercentage(_ value: Double) {
        let boundedValue = min(max(value, 0), 100)
        let formattedValue = Self.formattedPercentageString(for: boundedValue)
        defaults.set(formattedValue, forKey: Keys.defaultRequiredPercentage)
        requiredPercentageInput = formattedValue
        AnalyticsService.shared.log(.defaultRequiredPercentageSaved(value: Int(boundedValue.rounded())))
    }

    func applyRequiredPercentagePreset(_ value: Double) {
        let bounded = min(max(value, 0), 100)
        requiredPercentageInput = Self.formattedPercentageString(for: bounded)
        AnalyticsService.shared.log(.requiredPercentagePresetApplied(value: Int(bounded.rounded())))
    }

    func resetInputs() {
        totalClassesInput = ""
        attendedClassesInput = ""
        requiredPercentageInput = Self.formattedPercentageString(for: defaultRequiredPercentage)
        validationMessage = nil
        AnalyticsService.shared.log(.inputsReset)
    }

    func loadSubject(totalClasses: Int, attendedClasses: Int, requiredPercentage: Double) {
        suppressReviewTracking = true
        isApplyingSubjectLoad = true
        totalClassesInput = totalClasses > 0 ? String(totalClasses) : ""
        attendedClassesInput = attendedClasses > 0 ? String(attendedClasses) : ""
        requiredPercentageInput = Self.formattedPercentageString(for: min(max(requiredPercentage, 0), 100))
        validationMessage = nil
        isApplyingSubjectLoad = false
        suppressReviewTracking = false
        calculate()
    }

    private func validatedInput(showValidation: Bool = true) -> AttendanceInput? {
        if totalClassesInput.isEmpty || attendedClassesInput.isEmpty || requiredPercentageInput.isEmpty {
            if showValidation {
                validationMessage = nil
            }
            return nil
        }

        guard let total = Int(totalClassesInput), let attended = Int(attendedClassesInput) else {
            if showValidation {
                validationMessage = "Enter valid whole numbers for total and attended classes."
            }
            return nil
        }

        guard let required = Double(requiredPercentageInput) else {
            if showValidation {
                validationMessage = "Enter a valid attendance percentage."
            }
            return nil
        }

        guard total >= 0, attended >= 0 else {
            if showValidation {
                validationMessage = "Negative values are not allowed."
            }
            return nil
        }

        guard attended <= total else {
            if showValidation {
                validationMessage = "Attended classes cannot be greater than total classes."
            }
            return nil
        }

        guard required >= 0, required <= 100 else {
            if showValidation {
                validationMessage = "Required attendance must be between 0 and 100."
            }
            return nil
        }

        return AttendanceInput(
            totalClasses: total,
            attendedClasses: attended,
            requiredPercentage: required
        )
    }

    private func sanitizeIntegerInput(_ value: String) -> String {
        Self.sanitizedIntegerInput(value)
    }

    private func sanitizePercentageInput(_ value: String) -> String {
        Self.sanitizedPercentageInput(value)
    }

    private func makeResult(from input: AttendanceInput) -> AttendanceResult {
        let currentPercentage = CalculationService.currentPercentage(
            attended: input.attendedClasses,
            total: input.totalClasses
        )
        let status: AttendanceStatus = currentPercentage >= input.requiredPercentage ? .safe : .risk

        return AttendanceResult(
            currentPercentage: currentPercentage,
            bunkAllowed: CalculationService.maxBunk(
                attended: input.attendedClasses,
                total: input.totalClasses,
                required: input.requiredPercentage
            ),
            recoveryNeeded: CalculationService.requiredClasses(
                attended: input.attendedClasses,
                total: input.totalClasses,
                required: input.requiredPercentage
            ),
            status: status
        )
    }

    private func trackReviewTriggerIfNeeded(input: AttendanceInput, result: AttendanceResult) {
        guard suppressReviewTracking == false else { return }
        guard result.status == .safe else { return }
        guard defaults.bool(forKey: Keys.didPromptForReview) == false else { return }

        let signature = "\(input.totalClasses)|\(input.attendedClasses)|\(Self.formattedPercentageString(for: input.requiredPercentage))"
        guard signature != lastSafeCountSignature else { return }
        lastSafeCountSignature = signature

        let nextCount = defaults.integer(forKey: Keys.safeCalculationCount) + 1
        defaults.set(nextCount, forKey: Keys.safeCalculationCount)

        if nextCount >= 3 {
            defaults.set(true, forKey: Keys.didPromptForReview)
            reviewRequestToken += 1
        }
    }

    private static func sanitizedIntegerInput(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    private static func sanitizedPercentageInput(_ value: String) -> String {
        var result = ""
        var hasDecimalSeparator = false

        for character in value {
            if character.isNumber {
                result.append(character)
                continue
            }

            if character == ".", !hasDecimalSeparator {
                hasDecimalSeparator = true
                result.append(character)
            }
        }

        return result
    }

    private static func formattedPercentageString(for value: Double) -> String {
        let roundedValue = (value * 10).rounded() / 10
        return roundedValue.rounded(.towardZero) == roundedValue
            ? String(Int(roundedValue))
            : String(format: "%.1f", roundedValue)
    }
}

@MainActor
final class SubjectStore: ObservableObject {
    @Published private(set) var subjects: [SubjectSummary] = []
    @Published var selectedSubjectID: UUID? {
        didSet {
            guard selectedSubjectID != oldValue else { return }
            if oldValue != nil, selectedSubjectID != nil {
                AnalyticsService.shared.log(.subjectSwitched(totalSubjects: subjects.count))
            }
            persistSelectedSubjectID()
            loadSelectedSubjectIntoCalculator()
        }
    }

    let calculator: AttendanceViewModel

    var selectedSubjectName: String {
        selectedSubject?.name ?? "Subject"
    }

    var dashboardSummary: FacultyDashboardSummary {
        let total = subjects.count
        let safeCount = subjects.filter { $0.status == .safe }.count
        let riskCount = max(0, total - safeCount)
        let average = total == 0 ? 0 : subjects.map(\.currentPercentage).reduce(0, +) / Double(total)
        let mostAtRisk = subjects.min {
            ($0.currentPercentage - $0.requiredPercentage) < ($1.currentPercentage - $1.requiredPercentage)
        }

        return FacultyDashboardSummary(
            totalSubjects: total,
            safeSubjects: safeCount,
            riskSubjects: riskCount,
            averageAttendance: average,
            mostAtRiskSubject: mostAtRisk
        )
    }

    var bestSubject: SubjectSummary? {
        subjects.filter { $0.totalClasses > 0 }.max(by: { $0.currentPercentage < $1.currentPercentage })
    }

    var worstSubject: SubjectSummary? {
        subjects.filter { $0.totalClasses > 0 }.min(by: { $0.currentPercentage < $1.currentPercentage })
    }

    /// Consecutive recent days (across selected subject) with at least one attended class.
    func attendanceStreakDays(referenceDate: Date = Date()) -> Int {
        guard let subjectID = selectedSubjectID else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var day = calendar.startOfDay(for: referenceDate)

        for _ in 0..<120 {
            if let entry = logEntry(subjectID: subjectID, date: day) {
                if entry.isHoliday {
                    // Holidays don't break the streak.
                } else if entry.attendedContribution > 0 {
                    streak += 1
                } else if entry.totalContribution > 0 {
                    break
                }
            } else if classesScheduledToday(for: subjectID, on: day) > 0 {
                // Unmarked scheduled day — only break if it's in the past.
                if calendar.compare(day, to: calendar.startOfDay(for: referenceDate), toGranularity: .day) == .orderedAscending {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func weeklyAttendanceSummary(referenceDate: Date = Date()) -> WeeklyAttendanceSummary {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return WeeklyAttendanceSummary(attendedClasses: 0, missedClasses: 0, holidayDays: 0, percentageDelta: 0)
        }

        var attended = 0
        var missed = 0
        var holidays = 0

        for subject in subjects {
            var day = week.start
            while day < week.end {
                if let entry = logEntry(subjectID: subject.id, date: day) {
                    if entry.isHoliday {
                        holidays += 1
                    } else {
                        attended += entry.attendedContribution
                        missed += max(0, entry.totalContribution - entry.attendedContribution)
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        let points = selectedSubjectID.map { AttendanceTrendStore.load(subjectID: $0) } ?? []
        let delta: Double
        if points.count >= 2 {
            delta = points[points.count - 1].percentage - points[points.count - 2].percentage
        } else {
            delta = 0
        }

        return WeeklyAttendanceSummary(
            attendedClasses: attended,
            missedClasses: missed,
            holidayDays: holidays,
            percentageDelta: delta
        )
    }

    func hasLoggedToday(for subjectID: UUID? = nil, date: Date = Date()) -> Bool {
        guard let id = subjectID ?? selectedSubjectID else { return false }
        return logEntry(subjectID: id, date: date) != nil
    }

    private var selectedSubject: SubjectSummary? {
        subjects.first(where: { $0.id == selectedSubjectID })
    }

    private let defaults: UserDefaults
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let selectedSubjectID = "attendance.selectedSubjectID"
        static let didMigrateToCoreData = "attendance.didMigrateToCoreDataV1"
        static let legacyTotalClasses = "attendance.totalClasses"
        static let legacyAttendedClasses = "attendance.attendedClasses"
        static let legacyRequiredPercentage = "attendance.requiredPercentage"
        static let notificationsEnabled = "feature.notificationsEnabled"
    }

    init(
        defaults: UserDefaults = .standard,
        context: NSManagedObjectContext? = nil
    ) {
        self.defaults = defaults
        self.context = context ?? PersistenceController.shared.container.viewContext
        self.calculator = AttendanceViewModel(defaults: defaults)

        reloadSubjects()
        migrateLegacyUserDefaultsIfNeeded()
        ensureAtLeastOneSubject()
        reloadSubjects()

        let storedSelectedID = defaults.string(forKey: Keys.selectedSubjectID).flatMap(UUID.init(uuidString:))
        if let storedSelectedID, subjects.contains(where: { $0.id == storedSelectedID }) {
            selectedSubjectID = storedSelectedID
        } else {
            selectedSubjectID = subjects.first?.id
        }
        loadSelectedSubjectIntoCalculator()
        bindCalculatorChanges()
    }

    /// Notification setup is deferred so first paint is not blocked on launch.
    func performDeferredLaunchTasks() {
        Task(priority: .utility) { @MainActor in
            NotificationService.requestAuthorizationIfNeeded()
            NotificationService.scheduleClassReminder()
            NotificationService.scheduleWeeklyEngagementReminders()
        }
    }

    func addSubject(named customName: String? = nil) {
        let entity = SubjectEntity(context: context)
        entity.id = UUID()
        entity.name = validatedSubjectName(customName) ?? nextSubjectName()
        entity.totalClasses = 0
        entity.attendedClasses = 0
        entity.requiredPercentage = calculator.defaultRequiredPercentage
        entity.scheduleData = Self.encodeSchedule(.empty)
        entity.createdAt = Date()
        entity.updatedAt = Date()

        saveContext()
        reloadSubjects()
        selectedSubjectID = entity.id
        AnalyticsService.shared.log(.subjectAdded(totalSubjects: subjects.count))
        AnalyticsUserProfile.sync(subjectStore: self)
    }

    func deleteSubjects(at offsets: IndexSet) {
        guard subjects.count > 1 else { return }
        let idsToDelete = offsets.map { subjects[$0].id }

        let request = SubjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", idsToDelete)

        if let entities = try? context.fetch(request) {
            entities.forEach(context.delete)
            saveContext()
            reloadSubjects()

            if let currentID = selectedSubjectID, subjects.contains(where: { $0.id == currentID }) == false {
                selectedSubjectID = subjects.first?.id
            }
            AnalyticsService.shared.log(.subjectDeleted(totalSubjects: subjects.count))
            AnalyticsUserProfile.sync(subjectStore: self)
        }
    }

    func deleteSubject(id: UUID) {
        guard subjects.count > 1 else { return }

        let request = SubjectEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try? context.fetch(request).first {
            context.delete(entity)
            saveContext()
            reloadSubjects()

            if let currentID = selectedSubjectID, currentID == id {
                selectedSubjectID = subjects.first?.id
            }
            AnalyticsService.shared.log(.subjectDeleted(totalSubjects: subjects.count))
            AnalyticsUserProfile.sync(subjectStore: self)
        }
    }

    func selectSubject(_ subject: SubjectSummary) {
        guard selectedSubjectID != subject.id else { return }
        selectedSubjectID = subject.id
        AnalyticsService.shared.log(.subjectSelected)
    }

    func selectSubject(id: UUID) {
        guard subjects.contains(where: { $0.id == id }) else { return }
        guard selectedSubjectID != id else { return }
        selectedSubjectID = id
        AnalyticsService.shared.log(.subjectSelected)
    }

    func renameSubject(id: UUID, to name: String) {
        guard let cleanedName = validatedSubjectName(name) else { return }

        let request = SubjectEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let entity = try? context.fetch(request).first else { return }
        entity.name = cleanedName
        entity.updatedAt = Date()
        saveContext()
        reloadSubjects()
        AnalyticsService.shared.log(.subjectRenamed)
    }

    func weeklySchedule(for subjectID: UUID) -> WeeklySchedule {
        guard let subject = subjects.first(where: { $0.id == subjectID }) else {
            return .empty
        }
        return subject.weeklySchedule
    }

    func updateWeeklySchedule(for subjectID: UUID, schedule: WeeklySchedule) {
        let request = SubjectEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", subjectID as CVarArg)
        guard let entity = try? context.fetch(request).first else { return }

        entity.scheduleData = Self.encodeSchedule(schedule)
        entity.updatedAt = Date()
        saveContext()
        reloadSubjects()
        AnalyticsService.shared.log(.timetableUpdated(classesPerWeek: schedule.totalPerWeek))
        AnalyticsUserProfile.sync(subjectStore: self)
    }

    func applyWeeklySchedule(for subjectID: UUID, addToExisting: Bool) {
        let request = SubjectEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", subjectID as CVarArg)
        guard let entity = try? context.fetch(request).first else { return }

        let schedule = Self.decodeSchedule(entity.scheduleData)
        let weeklyTotal = schedule.totalPerWeek
        guard weeklyTotal > 0 else { return }

        if addToExisting {
            entity.totalClasses += Int32(weeklyTotal)
        } else {
            entity.totalClasses = Int32(weeklyTotal)
        }
        entity.updatedAt = Date()
        saveContext()
        reloadSubjects()

        if selectedSubjectID == subjectID {
            loadSelectedSubjectIntoCalculator()
        }
        AnalyticsService.shared.log(.timetableProjectionApplied)
    }

    func applyProjectedSchedule(
        for subjectID: UUID,
        weeks: Int,
        holidayClassCount: Int,
        expectedAbsences: Int,
        addToExisting: Bool
    ) {
        let request = SubjectEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", subjectID as CVarArg)
        guard let entity = try? context.fetch(request).first else { return }

        let schedule = Self.decodeSchedule(entity.scheduleData)
        let projectedClasses = CalculationService.projectedTotalClasses(
            schedule: schedule,
            weeks: weeks,
            holidayClassCount: holidayClassCount
        )
        guard projectedClasses > 0 else { return }

        let boundedAbsences = min(max(expectedAbsences, 0), projectedClasses)
        let projectedAttendance = projectedClasses - boundedAbsences

        if addToExisting {
            entity.totalClasses += Int32(projectedClasses)
            entity.attendedClasses += Int32(projectedAttendance)
        } else {
            entity.totalClasses = Int32(projectedClasses)
            entity.attendedClasses = Int32(projectedAttendance)
        }

        entity.updatedAt = Date()
        saveContext()
        reloadSubjects()

        if selectedSubjectID == subjectID {
            loadSelectedSubjectIntoCalculator()
        }
    }

    func subjectForecasts(
        weeks: Int,
        holidayClassCount: Int,
        expectedAbsences: Int,
        fallbackClassesPerWeek: Int = 5
    ) -> [SubjectForecast] {
        subjects.map { subject in
            let hasTimetable = subject.weeklySchedule.totalPerWeek > 0
            let expectedClasses = CalculationService.projectedTotalClasses(
                schedule: subject.weeklySchedule,
                weeks: weeks,
                holidayClassCount: holidayClassCount,
                fallbackClassesPerWeek: hasTimetable ? 0 : fallbackClassesPerWeek
            )
            let projection = CalculationService.forecast(
                attended: subject.attendedClasses,
                total: subject.totalClasses,
                required: subject.requiredPercentage,
                expectedClasses: expectedClasses,
                expectedAbsences: expectedAbsences
            )
            return SubjectForecast(
                id: subject.id,
                subjectName: subject.name,
                currentPercentage: subject.currentPercentage,
                forecastedPercentage: projection.forecastedPercentage,
                requiredPercentage: subject.requiredPercentage,
                expectedClasses: expectedClasses,
                forecastAttended: projection.attendedClasses,
                forecastTotal: projection.totalClasses,
                riskLevel: projection.riskLevel,
                usedFallbackSchedule: hasTimetable == false
            )
        }
        .sorted { $0.subjectName.localizedCaseInsensitiveCompare($1.subjectName) == .orderedAscending }
    }

    // MARK: - Daily Attendance Log

    /// Number of classes scheduled today for a subject, based on its timetable.
    func classesScheduledToday(for subjectID: UUID, on date: Date = Date()) -> Int {
        guard let subject = subjects.first(where: { $0.id == subjectID }) else { return 0 }
        return subject.weeklySchedule.classes(on: date)
    }

    /// The saved log entry for a subject on a specific day, if any.
    func logEntry(subjectID: UUID, date: Date) -> AttendanceLogEntry? {
        let day = Calendar.current.startOfDay(for: date)
        guard let entity = fetchRecordEntity(subjectID: subjectID, day: day) else { return nil }
        return logEntry(from: entity)
    }

    /// All log entries for a subject within the month containing `month`.
    func logEntries(subjectID: UUID, month: Date) -> [AttendanceLogEntry] {
        let calendar = Calendar.current
        guard
            let interval = calendar.dateInterval(of: .month, for: month)
        else {
            return []
        }

        let request = AttendanceRecordEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "subjectID == %@ AND date >= %@ AND date < %@",
            subjectID as CVarArg,
            interval.start as NSDate,
            interval.end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let fetched = (try? context.fetch(request)) ?? []
        return fetched.map(logEntry(from:))
    }

    /// Adds or updates a day's attendance mark, applying the change additively to
    /// the subject's running total/attended counters.
    func markDay(
        subjectID: UUID,
        date: Date,
        attendedCount: Int,
        scheduledCount: Int,
        isHoliday: Bool,
        source: String = "unknown"
    ) {
        let day = Calendar.current.startOfDay(for: date)

        let subjectRequest = SubjectEntity.fetchRequest()
        subjectRequest.fetchLimit = 1
        subjectRequest.predicate = NSPredicate(format: "id == %@", subjectID as CVarArg)
        guard let subjectEntity = try? context.fetch(subjectRequest).first else { return }

        let boundedScheduled = max(0, scheduledCount)
        let boundedAttended = min(max(0, attendedCount), boundedScheduled)

        let record = fetchRecordEntity(subjectID: subjectID, day: day)
        let previousEntry = record.map(logEntry(from:))

        if let record {
            let previous = logEntry(from: record)
            subjectEntity.totalClasses -= Int32(previous.totalContribution)
            subjectEntity.attendedClasses -= Int32(previous.attendedContribution)
        }

        let newEntry = AttendanceLogEntry(
            subjectID: subjectID,
            date: day,
            scheduledClasses: boundedScheduled,
            attendedClasses: boundedAttended,
            isHoliday: isHoliday
        )

        subjectEntity.totalClasses += Int32(newEntry.totalContribution)
        subjectEntity.attendedClasses += Int32(newEntry.attendedContribution)

        subjectEntity.totalClasses = max(0, subjectEntity.totalClasses)
        subjectEntity.attendedClasses = min(max(0, subjectEntity.attendedClasses), subjectEntity.totalClasses)
        subjectEntity.updatedAt = Date()

        let entity = record ?? AttendanceRecordEntity(context: context)
        if record == nil {
            entity.id = newEntry.id
        }
        entity.subjectID = subjectID
        entity.date = day
        entity.scheduledClasses = Int32(boundedScheduled)
        entity.attendedClasses = Int32(boundedAttended)
        entity.isHoliday = isHoliday
        entity.updatedAt = newEntry.updatedAt

        saveContext()
        finalizeAfterCounterChange(subjectEntity: subjectEntity)

        let status: String
        if isHoliday {
            status = "holiday"
        } else if boundedAttended <= 0 {
            status = "missed"
        } else if boundedAttended >= boundedScheduled {
            status = "attended"
        } else {
            status = "partial"
        }
        AnalyticsService.shared.log(.dayMarked(
            status: status,
            scheduled: boundedScheduled,
            attended: boundedAttended,
            source: source
        ))
        AnalyticsUserProfile.recordDayMarked(source: source)

        if source == "mark_today" || source == "day_editor" {
            let markChanged: Bool
            if let previousEntry {
                markChanged = previousEntry.scheduledClasses != boundedScheduled
                    || previousEntry.attendedClasses != boundedAttended
                    || previousEntry.isHoliday != isHoliday
            } else {
                markChanged = true
            }
            if markChanged {
                AdMobInterstitialService.shared.tryShowAfterDayMarked()
            }
        }
        AnalyticsUserProfile.sync(subjectStore: self)
    }

    /// Removes a day's mark and reverses its contribution to the counters.
    func clearDay(subjectID: UUID, date: Date, source: String = "unknown") {
        let day = Calendar.current.startOfDay(for: date)
        guard let record = fetchRecordEntity(subjectID: subjectID, day: day) else { return }

        let subjectRequest = SubjectEntity.fetchRequest()
        subjectRequest.fetchLimit = 1
        subjectRequest.predicate = NSPredicate(format: "id == %@", subjectID as CVarArg)

        if let subjectEntity = try? context.fetch(subjectRequest).first {
            let previous = logEntry(from: record)
            subjectEntity.totalClasses = max(0, subjectEntity.totalClasses - Int32(previous.totalContribution))
            subjectEntity.attendedClasses = max(0, subjectEntity.attendedClasses - Int32(previous.attendedContribution))
            subjectEntity.attendedClasses = min(subjectEntity.attendedClasses, subjectEntity.totalClasses)
            subjectEntity.updatedAt = Date()
            context.delete(record)
            saveContext()
            finalizeAfterCounterChange(subjectEntity: subjectEntity)
        } else {
            context.delete(record)
            saveContext()
            reloadSubjects()
        }
        AnalyticsService.shared.log(.dayCleared(source: source))
    }

    private func finalizeAfterCounterChange(subjectEntity: SubjectEntity) {
        reloadSubjects()

        if selectedSubjectID == subjectEntity.id {
            loadSelectedSubjectIntoCalculator()
        }

        scheduleNotificationIfNeeded(
            subjectName: subjectEntity.name,
            totalClasses: Int(subjectEntity.totalClasses),
            attendedClasses: Int(subjectEntity.attendedClasses),
            requiredPercentage: subjectEntity.requiredPercentage
        )
        recordTrendIfNeeded(
            subjectID: subjectEntity.id,
            totalClasses: Int(subjectEntity.totalClasses),
            attendedClasses: Int(subjectEntity.attendedClasses),
            requiredPercentage: subjectEntity.requiredPercentage
        )
    }

    private func fetchRecordEntity(subjectID: UUID, day: Date) -> AttendanceRecordEntity? {
        let request = AttendanceRecordEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "subjectID == %@ AND date == %@",
            subjectID as CVarArg,
            day as NSDate
        )
        return try? context.fetch(request).first
    }

    private func logEntry(from entity: AttendanceRecordEntity) -> AttendanceLogEntry {
        AttendanceLogEntry(
            id: entity.id,
            subjectID: entity.subjectID,
            date: entity.date,
            scheduledClasses: Int(entity.scheduledClasses),
            attendedClasses: Int(entity.attendedClasses),
            isHoliday: entity.isHoliday,
            updatedAt: entity.updatedAt
        )
    }

    private func bindCalculatorChanges() {
        Publishers.CombineLatest3(
            calculator.$totalClassesInput,
            calculator.$attendedClassesInput,
            calculator.$requiredPercentageInput
        )
        .dropFirst()
        .removeDuplicates { previous, current in
            previous.0 == current.0 && previous.1 == current.1 && previous.2 == current.2
        }
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] total, attended, required in
            self?.persistCalculatorValues(totalInput: total, attendedInput: attended, requiredInput: required)
        }
        .store(in: &cancellables)
    }

    private func persistCalculatorValues(totalInput: String, attendedInput: String, requiredInput: String) {
        guard let selectedID = selectedSubjectID else { return }
        let request = SubjectEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", selectedID as CVarArg)

        guard let entity = try? context.fetch(request).first else { return }

        let totalClasses = Int(totalInput) ?? 0
        let attendedClasses = Int(attendedInput) ?? 0
        let requiredPercentage = Double(requiredInput) ?? calculator.defaultRequiredPercentage

        guard entity.totalClasses != Int32(totalClasses)
            || entity.attendedClasses != Int32(attendedClasses)
            || entity.requiredPercentage != requiredPercentage
        else {
            return
        }

        entity.totalClasses = Int32(totalClasses)
        entity.attendedClasses = Int32(attendedClasses)
        entity.requiredPercentage = requiredPercentage
        entity.updatedAt = Date()

        saveContext()
        replaceSubjectInList(with: entity)

        guard totalInput.isEmpty == false,
              attendedInput.isEmpty == false,
              requiredInput.isEmpty == false,
              totalClasses > 0,
              attendedClasses <= totalClasses,
              (0...100).contains(requiredPercentage)
        else {
            return
        }

        scheduleNotificationIfNeeded(
            subjectName: entity.name,
            totalClasses: totalClasses,
            attendedClasses: attendedClasses,
            requiredPercentage: requiredPercentage
        )
        recordTrendIfNeeded(
            subjectID: selectedID,
            totalClasses: totalClasses,
            attendedClasses: attendedClasses,
            requiredPercentage: requiredPercentage
        )
    }

    private func loadSelectedSubjectIntoCalculator() {
        guard let subject = selectedSubject else { return }
        calculator.loadSubject(
            totalClasses: subject.totalClasses,
            attendedClasses: subject.attendedClasses,
            requiredPercentage: subject.requiredPercentage
        )
    }

    private func reloadSubjects() {
        let request = SubjectEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.returnsObjectsAsFaults = true

        let fetched = (try? context.fetch(request)) ?? []
        subjects = fetched.map(subjectSummary(from:))
    }

    private func replaceSubjectInList(with entity: SubjectEntity) {
        let updated = subjectSummary(from: entity)
        guard let index = subjects.firstIndex(where: { $0.id == updated.id }) else {
            reloadSubjects()
            return
        }
        guard subjects[index] != updated else { return }
        subjects[index] = updated
    }

    private func subjectSummary(from entity: SubjectEntity) -> SubjectSummary {
        SubjectSummary(
            id: entity.id,
            name: entity.name,
            totalClasses: Int(entity.totalClasses),
            attendedClasses: Int(entity.attendedClasses),
            requiredPercentage: entity.requiredPercentage,
            weeklySchedule: Self.decodeSchedule(entity.scheduleData),
            createdAt: entity.createdAt
        )
    }

    private func ensureAtLeastOneSubject() {
        guard subjects.isEmpty else { return }

        let entity = SubjectEntity(context: context)
        entity.id = UUID()
        entity.name = "Subject 1"
        entity.totalClasses = 0
        entity.attendedClasses = 0
        entity.requiredPercentage = calculator.defaultRequiredPercentage
        entity.scheduleData = Self.encodeSchedule(.empty)
        entity.createdAt = Date()
        entity.updatedAt = Date()
        saveContext()
    }

    private func migrateLegacyUserDefaultsIfNeeded() {
        guard defaults.bool(forKey: Keys.didMigrateToCoreData) == false else { return }
        guard subjects.isEmpty else {
            defaults.set(true, forKey: Keys.didMigrateToCoreData)
            return
        }

        let legacyTotal = defaults.string(forKey: Keys.legacyTotalClasses) ?? ""
        let legacyAttended = defaults.string(forKey: Keys.legacyAttendedClasses) ?? ""
        let legacyRequired = defaults.string(forKey: Keys.legacyRequiredPercentage) ?? ""

        let hasLegacyInputs = legacyTotal.isEmpty == false || legacyAttended.isEmpty == false || legacyRequired.isEmpty == false
        if hasLegacyInputs {
            let entity = SubjectEntity(context: context)
            entity.id = UUID()
            entity.name = "Subject 1"
            entity.totalClasses = Int32(Int(legacyTotal) ?? 0)
            entity.attendedClasses = Int32(Int(legacyAttended) ?? 0)
            entity.requiredPercentage = Double(legacyRequired) ?? calculator.defaultRequiredPercentage
            entity.scheduleData = Self.encodeSchedule(.empty)
            entity.createdAt = Date()
            entity.updatedAt = Date()
            saveContext()
        }

        defaults.set(true, forKey: Keys.didMigrateToCoreData)
    }

    private func nextSubjectName() -> String {
        let existingNames = Set(subjects.map(\.name))
        var index = subjects.count + 1
        while existingNames.contains("Subject \(index)") {
            index += 1
        }
        return "Subject \(index)"
    }

    private func validatedSubjectName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return String(trimmed.prefix(40))
    }

    private func scheduleNotificationIfNeeded(
        subjectName: String,
        totalClasses: Int,
        attendedClasses: Int,
        requiredPercentage: Double
    ) {
        let notificationsEnabled = defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true
        guard notificationsEnabled else { return }

        let currentPercentage = CalculationService.currentPercentage(attended: attendedClasses, total: totalClasses)
        let recoveryNeeded = CalculationService.requiredClasses(
            attended: attendedClasses,
            total: totalClasses,
            required: requiredPercentage
        )
        let bunkAllowed = CalculationService.maxBunk(
            attended: attendedClasses,
            total: totalClasses,
            required: requiredPercentage
        )
        let status: AttendanceStatus = currentPercentage >= requiredPercentage ? .safe : .risk

        if status == .risk {
            NotificationService.scheduleRiskAlert(
                subjectName: subjectName,
                currentPercentage: currentPercentage,
                recoveryNeeded: recoveryNeeded
            )
            NotificationService.scheduleRecoveryDeadlineAlert(
                subjectName: subjectName,
                recoveryNeeded: recoveryNeeded
            )
        } else {
            NotificationService.scheduleLowBufferAlert(
                subjectName: subjectName,
                currentPercentage: currentPercentage,
                bunkAllowed: bunkAllowed
            )
        }
    }

    private func recordTrendIfNeeded(
        subjectID: UUID,
        totalClasses: Int,
        attendedClasses: Int,
        requiredPercentage: Double
    ) {
        guard totalClasses > 0 else { return }
        guard attendedClasses >= 0, attendedClasses <= totalClasses else { return }
        guard (0...100).contains(requiredPercentage) else { return }

        let currentPercentage = CalculationService.currentPercentage(attended: attendedClasses, total: totalClasses)
        AttendanceTrendStore.append(subjectID: subjectID, percentage: currentPercentage)
    }

    private static func decodeSchedule(_ raw: String) -> WeeklySchedule {
        guard
            let data = raw.data(using: .utf8),
            let schedule = try? JSONDecoder().decode(WeeklySchedule.self, from: data)
        else {
            return .empty
        }
        return schedule
    }

    private static func encodeSchedule(_ schedule: WeeklySchedule) -> String {
        guard
            let data = try? JSONEncoder().encode(schedule),
            let raw = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return raw
    }

    private func persistSelectedSubjectID() {
        defaults.set(selectedSubjectID?.uuidString, forKey: Keys.selectedSubjectID)
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
        }
    }
}

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    private(set) var isStoreLoaded = false
    private var storeLoadContinuations: [CheckedContinuation<Void, Never>] = []

    private init() {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "AttendanceModel", managedObjectModel: model)
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { [weak self] _, error in
            if let error {
                fatalError("Core Data store failed: \(error)")
            }
            guard let self else { return }
            self.isStoreLoaded = true
            let waiters = self.storeLoadContinuations
            self.storeLoadContinuations.removeAll()
            waiters.forEach { $0.resume() }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func waitForStoreIfNeeded() async {
        if isStoreLoaded { return }
        await withCheckedContinuation { continuation in
            if isStoreLoaded {
                continuation.resume()
            } else {
                storeLoadContinuations.append(continuation)
            }
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "SubjectEntity"
        entity.managedObjectClassName = NSStringFromClass(SubjectEntity.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false

        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = false
        name.defaultValue = ""

        let totalClasses = NSAttributeDescription()
        totalClasses.name = "totalClasses"
        totalClasses.attributeType = .integer32AttributeType
        totalClasses.isOptional = false
        totalClasses.defaultValue = 0

        let attendedClasses = NSAttributeDescription()
        attendedClasses.name = "attendedClasses"
        attendedClasses.attributeType = .integer32AttributeType
        attendedClasses.isOptional = false
        attendedClasses.defaultValue = 0

        let requiredPercentage = NSAttributeDescription()
        requiredPercentage.name = "requiredPercentage"
        requiredPercentage.attributeType = .doubleAttributeType
        requiredPercentage.isOptional = false
        requiredPercentage.defaultValue = 75.0

        let scheduleData = NSAttributeDescription()
        scheduleData.name = "scheduleData"
        scheduleData.attributeType = .stringAttributeType
        scheduleData.isOptional = false
        scheduleData.defaultValue = "{}"

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false
        createdAt.defaultValue = Date()

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = false
        updatedAt.defaultValue = Date()

        entity.properties = [id, name, totalClasses, attendedClasses, requiredPercentage, scheduleData, createdAt, updatedAt]

        model.entities = [entity, makeRecordEntity()]

        return model
    }

    private static func makeRecordEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "AttendanceRecordEntity"
        entity.managedObjectClassName = NSStringFromClass(AttendanceRecordEntity.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false

        let subjectID = NSAttributeDescription()
        subjectID.name = "subjectID"
        subjectID.attributeType = .UUIDAttributeType
        subjectID.isOptional = false

        let date = NSAttributeDescription()
        date.name = "date"
        date.attributeType = .dateAttributeType
        date.isOptional = false
        date.defaultValue = Date()

        let scheduledClasses = NSAttributeDescription()
        scheduledClasses.name = "scheduledClasses"
        scheduledClasses.attributeType = .integer32AttributeType
        scheduledClasses.isOptional = false
        scheduledClasses.defaultValue = 0

        let attendedClasses = NSAttributeDescription()
        attendedClasses.name = "attendedClasses"
        attendedClasses.attributeType = .integer32AttributeType
        attendedClasses.isOptional = false
        attendedClasses.defaultValue = 0

        let isHoliday = NSAttributeDescription()
        isHoliday.name = "isHoliday"
        isHoliday.attributeType = .booleanAttributeType
        isHoliday.isOptional = false
        isHoliday.defaultValue = false

        let updatedAt = NSAttributeDescription()
        updatedAt.name = "updatedAt"
        updatedAt.attributeType = .dateAttributeType
        updatedAt.isOptional = false
        updatedAt.defaultValue = Date()

        entity.properties = [id, subjectID, date, scheduledClasses, attendedClasses, isHoliday, updatedAt]

        return entity
    }
}

@objc(SubjectEntity)
final class SubjectEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var totalClasses: Int32
    @NSManaged var attendedClasses: Int32
    @NSManaged var requiredPercentage: Double
    @NSManaged var scheduleData: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

extension SubjectEntity {
    @nonobjc class func fetchRequest() -> NSFetchRequest<SubjectEntity> {
        NSFetchRequest<SubjectEntity>(entityName: "SubjectEntity")
    }
}

@objc(AttendanceRecordEntity)
final class AttendanceRecordEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var subjectID: UUID
    @NSManaged var date: Date
    @NSManaged var scheduledClasses: Int32
    @NSManaged var attendedClasses: Int32
    @NSManaged var isHoliday: Bool
    @NSManaged var updatedAt: Date
}

extension AttendanceRecordEntity {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AttendanceRecordEntity> {
        NSFetchRequest<AttendanceRecordEntity>(entityName: "AttendanceRecordEntity")
    }
}
