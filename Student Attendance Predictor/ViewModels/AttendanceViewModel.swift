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
        /// Cold/warm process launches — native review waits until the 2nd+ session.
        static let sessionCount = "app.sessionCount"
    }

    /// Call once per process launch (from ContentView) so review can wait for session 3+.
    static func recordAppSession(defaults: UserDefaults = .standard) {
        let next = defaults.integer(forKey: Keys.sessionCount) + 1
        defaults.set(next, forKey: Keys.sessionCount)
    }

    static var appSessionCount: Int {
        UserDefaults.standard.integer(forKey: Keys.sessionCount)
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
            SoftPaywallCoordinator.shared.recordAtRiskWeekIfNeeded(isAtRisk: true)
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

    /// Sets the saved default target without logging a manual save (first-launch market default).
    func applyDefaultRequiredPercentage(_ value: Double) {
        let boundedValue = min(max(value, 0), 100)
        let formattedValue = Self.formattedPercentageString(for: boundedValue)
        defaults.set(formattedValue, forKey: Keys.defaultRequiredPercentage)
        requiredPercentageInput = formattedValue
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
        guard AppStoreReviewPromptCoordinator.shared.canRequestNativeReview else { return }

        let signature = "\(input.totalClasses)|\(input.attendedClasses)|\(Self.formattedPercentageString(for: input.requiredPercentage))"
        guard signature != lastSafeCountSignature else { return }
        lastSafeCountSignature = signature

        let nextCount = defaults.integer(forKey: Keys.safeCalculationCount) + 1
        defaults.set(nextCount, forKey: Keys.safeCalculationCount)

        AppStoreReviewPromptCoordinator.shared.markNativeReviewRequested()
        reviewRequestToken += 1
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
    private var lastHabitReminderSignature: String?

    var selectedSubjectName: String {
        selectedSubject?.name ?? "Subject"
    }

    var dashboardSummary: FacultyDashboardSummary {
        let total = subjects.count
        let started = subjects.filter(\.hasAttendance)
        let safeCount = started.filter { $0.status == .safe }.count
        let riskCount = started.filter(\.isAtRisk).count
        let average = started.isEmpty
            ? 0
            : started.map(\.currentPercentage).reduce(0, +) / Double(started.count)
        let mostAtRisk = started.filter(\.isAtRisk).min {
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
        if let id = subjectID {
            return logEntry(subjectID: id, date: date) != nil
        }
        let targets = subjectsForMarkToday(on: date)
        guard targets.isEmpty == false else {
            guard let selected = selectedSubjectID else { return false }
            return logEntry(subjectID: selected, date: date) != nil
        }
        return targets.allSatisfy { logEntry(subjectID: $0.id, date: date) != nil }
    }

    var selectedSubject: SubjectSummary? {
        subjects.first(where: { $0.id == selectedSubjectID })
    }

    var lockedSubjectCount: Int {
        subjects.filter { isSubjectLocked($0.id) }.count
    }

    func isSubjectLocked(_ id: UUID) -> Bool {
        AdEntitlementsStore.shared.isSubjectLocked(id: id, subjects: subjects)
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
        removeUnusedPlaceholderSubjectsIfNeeded()
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
        applyMarketDefaultAttendanceIfNeeded()
        SemesterSettings.ensureDefaultDatesIfNeeded()
        AppStoreReviewPromptCoordinator.shared.backfillIfNeeded(
            nonHolidayMarkCount: nonHolidayAttendanceMarkCount()
        )
        Task(priority: .utility) { @MainActor in
            if subjects.isEmpty == false {
                NotificationService.requestAuthorizationIfNeeded()
            }
            NotificationService.registerPersonalityCategory()
            NotificationService.scheduleDayTwoMarkNudgeIfNeeded()
            publishWidgetSnapshot()
            SchoolabeSyncService.shared.scheduleActiveTodaySyncIfNeeded(subjectStore: self)
        }
        NotificationCenter.default.addObserver(
            forName: .studentProfileDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rescheduleHabitReminders(force: true)
        }
    }

    /// Reload after Siri, Shortcuts, or Live Activity marks while the app is open.
    func reloadFromExternalChange() {
        reloadSubjects()
        if selectedSubjectID != nil {
            loadSelectedSubjectIntoCalculator()
        }
        publishWidgetSnapshot()
        rescheduleHabitReminders()
    }

    /// Applies region-aware default attendance target once on first launch (75 IN / 80 US·UK).
    private func applyMarketDefaultAttendanceIfNeeded() {
        let key = "attendance.didApplyMarketDefault"
        guard defaults.bool(forKey: key) == false else { return }
        defaults.set(true, forKey: key)
        let target = StudentMarketStore.current.defaultRequiredAttendance
        calculator.applyDefaultRequiredPercentage(target)
    }

    /// Adds a subject when allowed. Requires a real name — we never auto-create "Subject 1".
    @discardableResult
    func addSubject(named customName: String? = nil) -> Bool {
        guard AdEntitlementsStore.shared.canAddSubject(currentCount: subjects.count) else {
            AnalyticsService.shared.log(.subjectLimitHit(totalSubjects: subjects.count))
            return false
        }
        guard let name = validatedSubjectName(customName) else {
            return false
        }

        let entity = SubjectEntity(context: context)
        entity.id = UUID()
        entity.name = name
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
        GuidedSetupStore.shared.subjectWasAdded()
        SchoolabeSyncService.shared.scheduleSync(subjectStore: self)
        return true
    }

    func deleteSubjects(at offsets: IndexSet) {
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
            SchoolabeSyncService.shared.scheduleSync(subjectStore: self)
        }
    }

    func deleteSubject(id: UUID) {
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
            SchoolabeSyncService.shared.scheduleSync(subjectStore: self)
        }
    }

    func selectSubject(_ subject: SubjectSummary) {
        guard selectedSubjectID != subject.id else { return }
        selectedSubjectID = subject.id
        AnalyticsService.shared.log(.subjectSelected)
        publishWidgetSnapshot()
    }

    func selectSubject(id: UUID) {
        guard subjects.contains(where: { $0.id == id }) else { return }
        guard selectedSubjectID != id else { return }
        selectedSubjectID = id
        AnalyticsService.shared.log(.subjectSelected)
        publishWidgetSnapshot()
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
        publishWidgetSnapshot()
    }

    func weeklySchedule(for subjectID: UUID) -> WeeklySchedule {
        guard let subject = subjects.first(where: { $0.id == subjectID }) else {
            return .empty
        }
        return subject.weeklySchedule
    }

    func togglePeriod(_ hour: Int, for subjectID: UUID, on date: Date = Date()) {
        var schedule = weeklySchedule(for: subjectID)
        schedule.toggleHour(hour, on: date)
        updateWeeklySchedule(for: subjectID, schedule: schedule)
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
        publishWidgetSnapshot()
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

    /// Subjects with timetable classes on `date`. Subjects with no days set still
    /// appear (so students can mark while they finish setup). If every subject has
    /// days and none fall on `date`, the list is empty — a real off day.
    func subjectsForMarkToday(on date: Date = Date()) -> [SubjectSummary] {
        let namedSort: (SubjectSummary, SubjectSummary) -> Bool = {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let withDays = subjects.filter { $0.weeklySchedule.totalPerWeek > 0 }
        let withoutDays = subjects.filter { $0.weeklySchedule.totalPerWeek == 0 }
        guard withDays.isEmpty == false else {
            return subjects.sorted(by: namedSort)
        }
        let scheduledToday = withDays.filter { classesScheduledToday(for: $0.id, on: date) > 0 }
        return (scheduledToday + withoutDays).sorted(by: namedSort)
    }

    /// Classes left this semester for a subject (timetable × weeks − holidays − planned bunks).
    func classesLeftThisSemester(
        for subject: SubjectSummary,
        weeks: Int = SemesterSettings.weeksRemaining(),
        holidayClassCount: Int = ForecastAssumptions.holidayClassCount,
        plannedBunks: Int = ForecastAssumptions.plannedBunks,
        fallbackClassesPerWeek: Int = ForecastAssumptions.fallbackClassesPerWeek
    ) -> Int {
        let hasTimetable = subject.weeklySchedule.totalPerWeek > 0
        return CalculationService.classesLeftThisSemester(
            schedule: subject.weeklySchedule,
            weeks: weeks,
            holidayClassCount: holidayClassCount,
            plannedBunks:  plannedBunks,
            fallbackClassesPerWeek: hasTimetable ? 0 : fallbackClassesPerWeek
        )
    }

    func publishWidgetSnapshot() {
        WidgetSnapshotStore.publish(from: subjects, selectedID: selectedSubjectID)
        rescheduleHabitReminders()
    }

    /// Repeating local reminders freeze copy at schedule time — refresh after data changes.
    func rescheduleHabitReminders(force: Bool = false) {
        let context = makeNotificationContext()
        if force == false, context.schedulingSignature == lastHabitReminderSignature {
            return
        }
        lastHabitReminderSignature = context.schedulingSignature
        NotificationService.reschedulePersonalityReminders(context: context)
        NotificationService.scheduleEveningMarkNudgeIfNeeded(
            hasMarkedToday: context.hasLoggedToday,
            hasSubjects: subjects.isEmpty == false,
            pendingMarkCount: subjectsForMarkToday(on: Date()).count
        )
        commitNotificationPercentSnapshot(from: context)
    }

    func makeNotificationContext(focus: SubjectSummary? = nil) -> NotificationContext {
        let market = StudentMarketStore.current
        let subject = focus ?? selectedSubject
        let calendar = Calendar.current
        let today = Date()
        let summary = weeklyAttendanceSummary(referenceDate: today)
        var classesByWeekday: [Int: Int] = [:]
        for weekday in 1...7 {
            classesByWeekday[weekday] = subjects.reduce(0) { total, subject in
                total + classesOnWeekday(subject.weeklySchedule, weekday: weekday)
            }
        }
        let points = selectedSubjectID.map { AttendanceTrendStore.load(subjectID: $0) } ?? []
        let trend: AttendanceTrendDirection
        if points.count >= 2 {
            let delta = points[points.count - 1].percentage - points[points.count - 2].percentage
            if delta > 0.3 {
                trend = .improving
            } else if delta < -0.3 {
                trend = .declining
            } else {
                trend = .stable
            }
        } else {
            trend = .stable
        }

        let hasData = (subject?.totalClasses ?? 0) > 0
        let firstName = NotificationPersonalization.firstName(defaults: defaults)
        let percent = subject?.currentPercentage ?? 0
        let subjectKey = subject?.id.uuidString ?? "none"
        let snapshotKey = "notif.lastKnownPercent.\(subjectKey)"
        let previousPercent = defaults.object(forKey: snapshotKey) as? Double
        let moved: Bool
        if let previous = previousPercent, hasData {
            moved = abs(previous - percent) >= 1.0
        } else {
            moved = false
        }

        return NotificationContext(
            attendancePercentage: percent,
            requiredPercentage: subject?.requiredPercentage ?? calculator.defaultRequiredPercentage,
            safeBunks: subject?.status == .safe ? (subject?.bunkAllowed ?? 0) : 0,
            recoveryNeeded: subject?.status == .risk ? (subject?.recoveryNeeded ?? 0) : 0,
            subjectName: subject?.name ?? "your class",
            firstName: firstName,
            skipVerb: market.skipVerb,
            skipNoun: market.skipNounPlural,
            classesToday: subjects.reduce(0) { $0 + classesScheduledToday(for: $1.id, on: today) },
            hasData: hasData,
            isSafe: (subject?.status ?? .safe) == .safe,
            hasLoggedToday: hasLoggedToday(date: today),
            isWeekend: calendar.isDateInWeekend(today),
            isWeeklyHoliday: AttendanceCalendar.isWeeklyHoliday(today, calendar: calendar),
            streakDays: attendanceStreakDays(referenceDate: today),
            trend: trend,
            weeklyMissed: summary.missedClasses,
            weeklyAttended: summary.attendedClasses,
            atRiskSubjects: dashboardSummary.riskSubjects,
            dayKey: NotificationCooldownStore.dayKey(today, calendar: calendar),
            classesByWeekday: classesByWeekday,
            attendanceMovedRecently: moved || trend != .stable
        )
    }

    /// Call after habit notifications are scheduled so “moved” curiosity stays true for that pass.
    func commitNotificationPercentSnapshot(from context: NotificationContext) {
        guard context.hasData else { return }
        let subjectKey = selectedSubject?.id.uuidString ?? "none"
        defaults.set(context.attendancePercentage, forKey: "notif.lastKnownPercent.\(subjectKey)")
    }

    /// The saved log entry for a subject on a specific day, if any.
    func logEntry(subjectID: UUID, date: Date) -> AttendanceLogEntry? {
        let day = Calendar.current.startOfDay(for: date)
        guard let entity = fetchRecordEntity(subjectID: subjectID, day: day) else { return nil }
        return logEntry(from: entity)
    }

    /// Every saved log entry across all subjects, oldest first.
    func allLogEntries() -> [AttendanceLogEntry] {
        let request = AttendanceRecordEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let fetched = (try? context.fetch(request)) ?? []
        return fetched.map(logEntry(from:))
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
        guard isSubjectLocked(subjectID) == false else { return }
        let day = Calendar.current.startOfDay(for: date)

        let subjectRequest = SubjectEntity.fetchRequest()
        subjectRequest.fetchLimit = 1
        subjectRequest.predicate = NSPredicate(format: "id == %@", subjectID as CVarArg)
        guard let subjectEntity = try? context.fetch(subjectRequest).first else { return }

        let boundedScheduled = max(0, scheduledCount)
        let boundedAttended = min(max(0, attendedCount), boundedScheduled)

        let record = fetchRecordEntity(subjectID: subjectID, day: day)
        let isNewEntry = record == nil
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
        AnalyticsUserProfile.sync(subjectStore: self)

        if isHoliday == false {
            let countsAsNewMark = isNewEntry || previousEntry?.isHoliday == true
            AppStoreReviewPromptCoordinator.shared.recordAttendanceMark(isNewEntry: countsAsNewMark)
            if countsAsNewMark,
               source == "mark_today" || source.hasPrefix("mark_today") {
                AdMobInterstitialService.shared.recordAttendanceMarkAndMaybeShow()
            }
        }

        SoftPaywallCoordinator.shared.recordAtRiskWeekIfNeeded(
            isAtRisk: dashboardSummary.riskSubjects > 0
        )
        if source == "mark_today" || source.hasPrefix("mark_today") {
            SoftPaywallCoordinator.shared.evaluateAfterDayMarked(
                streak: attendanceStreakDays()
            )
            SoftPaywallCoordinator.shared.evaluateHabitValuePaywall(
                daysSinceInstall: AnalyticsService.shared.daysSinceInstall,
                hasMarkedDay: true
            )
        }
        SchoolabeSyncService.shared.scheduleSync(subjectStore: self)
    }

    /// Removes a day's mark and reverses its contribution to the counters.
    func clearDay(subjectID: UUID, date: Date, source: String = "unknown") {
        guard isSubjectLocked(subjectID) == false else { return }
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
        SchoolabeSyncService.shared.scheduleSync(subjectStore: self)
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
        publishWidgetSnapshot()
    }

    private func nonHolidayAttendanceMarkCount() -> Int {
        let request = AttendanceRecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isHoliday == NO")
        return (try? context.count(for: request)) ?? 0
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

    private func classesOnWeekday(_ schedule: WeeklySchedule, weekday: Int) -> Int {
        switch weekday {
        case 1: return schedule.sunday
        case 2: return schedule.monday
        case 3: return schedule.tuesday
        case 4: return schedule.wednesday
        case 5: return schedule.thursday
        case 6: return schedule.friday
        case 7: return schedule.saturday
        default: return 0
        }
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
        publishWidgetSnapshot()
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

    /// Old builds auto-created "Subject 1" on launch. Drop unused ones so first-run can start.
    private func removeUnusedPlaceholderSubjectsIfNeeded() {
        let unused = subjects.filter { subject in
            subject.totalClasses == 0
                && subject.weeklySchedule.totalPerWeek == 0
                && Self.isPlaceholderName(subject.name)
        }
        guard unused.isEmpty == false else { return }
        guard unused.count == subjects.count else { return }

        let ids = unused.map(\.id) as [UUID]
        let request = SubjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        if let entities = try? context.fetch(request) {
            entities.forEach(context.delete)
            saveContext()
        }
    }

    private static func isPlaceholderName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("Subject ") else { return false }
        let suffix = trimmed.dropFirst("Subject ".count)
        return suffix.isEmpty == false && suffix.allSatisfy(\.isNumber)
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

        var context = makeNotificationContext()
        context.subjectName = subjectName
        context.attendancePercentage = currentPercentage
        context.requiredPercentage = requiredPercentage
        context.safeBunks = status == .safe ? bunkAllowed : 0
        context.recoveryNeeded = status == .risk ? recoveryNeeded : 0
        context.isSafe = status == .safe
        context.hasData = totalClasses > 0
        NotificationService.scheduleImmediatePersonalityAlert(context: context)
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

    #if DEBUG
    /// Replaces current papers with 3 named subjects and ~30 days of marks for App Store shots.
    func fillScreenshotDemoMonth() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let monthStart = calendar.date(byAdding: .day, value: -29, to: today) else { return }

        if let records = try? context.fetch(AttendanceRecordEntity.fetchRequest()) {
            records.forEach(context.delete)
        }
        if let existing = try? context.fetch(SubjectEntity.fetchRequest()) {
            existing.forEach(context.delete)
        }
        saveContext()

        struct Paper {
            let name: String
            let schedule: WeeklySchedule
            let missEvery: Int
        }

        let papers: [Paper] = [
            Paper(
                name: "Data Structures",
                schedule: screenshotSchedule(
                    monday: [9, 10], wednesday: [9], friday: [10], saturday: [9]
                ),
                missEvery: 11
            ),
            Paper(
                name: "Mathematics",
                schedule: screenshotSchedule(
                    tuesday: [11], thursday: [11, 12], saturday: [11]
                ),
                missEvery: 7
            ),
            Paper(
                name: "Physics",
                schedule: screenshotSchedule(
                    monday: [14], tuesday: [14], thursday: [14], saturday: [14]
                ),
                missEvery: 9
            )
        ]

        var firstID: UUID?
        let createdAt = calendar.date(byAdding: .day, value: -36, to: today) ?? today

        for paper in papers {
            let entity = SubjectEntity(context: context)
            let id = UUID()
            if firstID == nil { firstID = id }
            entity.id = id
            entity.name = paper.name
            entity.requiredPercentage = 75
            entity.scheduleData = Self.encodeSchedule(paper.schedule)
            entity.createdAt = createdAt
            entity.updatedAt = Date()

            var attended = 0
            var total = 0
            var trend: [AttendanceTrendPoint] = []
            var day = monthStart

            while day <= today {
                let scheduled = paper.schedule.classes(on: day)
                if scheduled > 0 {
                    let daysFromToday = calendar.dateComponents([.day], from: day, to: today).day ?? 0
                    let dayNumber = calendar.ordinality(of: .day, in: .year, for: day) ?? 0
                    let isHoliday = daysFromToday == 16
                    let isRecent = daysFromToday <= 8
                    let isMiss = isHoliday == false
                        && isRecent == false
                        && dayNumber % paper.missEvery == 0

                    let record = AttendanceRecordEntity(context: context)
                    record.id = UUID()
                    record.subjectID = id
                    record.date = day
                    record.isHoliday = isHoliday
                    record.updatedAt = day
                    if isHoliday {
                        record.scheduledClasses = 0
                        record.attendedClasses = 0
                    } else {
                        record.scheduledClasses = Int32(scheduled)
                        record.attendedClasses = Int32(isMiss ? 0 : scheduled)
                        total += scheduled
                        if isMiss == false { attended += scheduled }
                    }

                    let pct = CalculationService.currentPercentage(attended: attended, total: total)
                    if total > 0, trend.count < 20, dayNumber % 2 == 0 || day == today {
                        trend.append(AttendanceTrendPoint(timestamp: day, percentage: pct))
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }

            entity.totalClasses = Int32(total)
            entity.attendedClasses = Int32(attended)
            AttendanceTrendStore.replace(subjectID: id, points: trend)
        }

        saveContext()
        reloadSubjects()
        selectedSubjectID = firstID ?? subjects.first?.id
        loadSelectedSubjectIntoCalculator()
        publishWidgetSnapshot()

        UserDefaults.standard.set(true, forKey: "onboarding.didComplete")
        UserDefaults.standard.set(true, forKey: "analytics.didLogFirstMark")
        UserDefaults.standard.set(Date().addingTimeInterval(7 * 24 * 60 * 60), forKey: "review.v2.snoozeUntil")
        UserDefaults.standard.set(Date(), forKey: "paywall.lastShownAt")
        GuidedSetupStore.shared.markCompleteSilently()

        if StudentProfileStore.shared.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            StudentProfileStore.shared.save(
                StudentProfile(
                    name: "Aarav",
                    age: 19,
                    classOrDegree: "UG 2nd year",
                    institutionName: "NIT"
                ),
                skipped: false
            )
        }
    }

    /// ASO / Simulator: one below-the-line subject with a clear attend-needed number.
    func fillASORecoveryScreenshot() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let records = try? context.fetch(AttendanceRecordEntity.fetchRequest()) {
            records.forEach(context.delete)
        }
        if let existing = try? context.fetch(SubjectEntity.fetchRequest()) {
            existing.forEach(context.delete)
        }
        saveContext()

        let id = UUID()
        let entity = SubjectEntity(context: context)
        entity.id = id
        entity.name = "Operating Systems"
        entity.requiredPercentage = 75
        entity.scheduleData = Self.encodeSchedule(
            screenshotSchedule(monday: [9, 10], wednesday: [9], friday: [10], saturday: [9])
        )
        entity.createdAt = calendar.date(byAdding: .day, value: -40, to: today) ?? today
        entity.updatedAt = Date()

        // 12/20 = 60% → clearly below 75%; recoveryNeeded is several classes.
        let attended = 12
        let total = 20
        entity.attendedClasses = Int32(attended)
        entity.totalClasses = Int32(total)

        var trend: [AttendanceTrendPoint] = []
        for offset in stride(from: 18, through: 0, by: -2) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let a = max(1, attended - offset / 3)
            let tot = max(a, total - offset / 2)
            trend.append(
                AttendanceTrendPoint(
                    timestamp: day,
                    percentage: CalculationService.currentPercentage(attended: a, total: tot)
                )
            )
        }
        AttendanceTrendStore.replace(subjectID: id, points: trend)

        saveContext()
        reloadSubjects()
        selectedSubjectID = id
        loadSelectedSubjectIntoCalculator()
        publishWidgetSnapshot()

        UserDefaults.standard.set(true, forKey: "onboarding.didComplete")
        UserDefaults.standard.set(true, forKey: "analytics.didLogFirstMark")
        UserDefaults.standard.set(Date().addingTimeInterval(7 * 24 * 60 * 60), forKey: "review.v2.snoozeUntil")
        UserDefaults.standard.set(Date(), forKey: "paywall.lastShownAt")
        GuidedSetupStore.shared.markCompleteSilently()

        if StudentProfileStore.shared.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            StudentProfileStore.shared.save(
                StudentProfile(
                    name: "Aarav",
                    age: 19,
                    classOrDegree: "UG 2nd year",
                    institutionName: "NIT"
                ),
                skipped: false
            )
        }
    }

        private func screenshotSchedule(
        monday: [Int] = [],
        tuesday: [Int] = [],
        wednesday: [Int] = [],
        thursday: [Int] = [],
        friday: [Int] = [],
        saturday: [Int] = []
    ) -> WeeklySchedule {
        var schedule = WeeklySchedule.empty
        schedule.mondayHours = monday
        schedule.tuesdayHours = tuesday
        schedule.wednesdayHours = wednesday
        schedule.thursdayHours = thursday
        schedule.fridayHours = friday
        schedule.saturdayHours = saturday
        schedule.syncCountsFromHours()
        return schedule
    }
    #endif

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
