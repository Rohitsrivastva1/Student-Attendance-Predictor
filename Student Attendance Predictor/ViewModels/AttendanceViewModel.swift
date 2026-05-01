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
                return
            }
            calculate()
        }
    }
    @Published var attendedClassesInput: String {
        didSet {
            let sanitized = sanitizeIntegerInput(attendedClassesInput)
            if attendedClassesInput != sanitized {
                attendedClassesInput = sanitized
                return
            }
            calculate()
        }
    }
    @Published var requiredPercentageInput: String {
        didSet {
            let sanitized = sanitizePercentageInput(requiredPercentageInput)
            if requiredPercentageInput != sanitized {
                requiredPercentageInput = sanitized
                return
            }
            calculate()
        }
    }
    @Published private(set) var result: AttendanceResult?
    @Published private(set) var validationMessage: String?
    @Published private(set) var reviewRequestToken: Int = 0

    private let defaults: UserDefaults
    private var lastSafeCountSignature: String?
    private var suppressReviewTracking = false

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
        calculate()
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
    }

    func applyRequiredPercentagePreset(_ value: Double) {
        requiredPercentageInput = Self.formattedPercentageString(for: min(max(value, 0), 100))
    }

    func resetInputs() {
        totalClassesInput = ""
        attendedClassesInput = ""
        requiredPercentageInput = Self.formattedPercentageString(for: defaultRequiredPercentage)
        validationMessage = nil
    }

    func loadSubject(totalClasses: Int, attendedClasses: Int, requiredPercentage: Double) {
        suppressReviewTracking = true
        totalClassesInput = totalClasses > 0 ? String(totalClasses) : ""
        attendedClassesInput = attendedClasses > 0 ? String(attendedClasses) : ""
        requiredPercentageInput = Self.formattedPercentageString(for: min(max(requiredPercentage, 0), 100))
        validationMessage = nil
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
    static let freeSubjectLimit = 3

    enum AddSubjectResult {
        case added
        case limitReached
    }

    @Published private(set) var subjects: [SubjectSummary] = []
    @Published private(set) var isProUnlocked: Bool
    @Published private(set) var isProGatingEnabled: Bool
    @Published var selectedSubjectID: UUID? {
        didSet {
            guard selectedSubjectID != oldValue else { return }
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

    var subjectLimitDescription: String {
        if isProUnlocked {
            return "Pro plan: unlimited subjects enabled."
        }
        if isProGatingEnabled {
            return "Free plan allows up to \(Self.freeSubjectLimit) subjects."
        }
        return "Unlimited subjects enabled."
    }

    var isAtSubjectLimit: Bool {
        canAddSubject == false
    }

    var canAddSubject: Bool {
        subjects.count < effectiveSubjectLimit
    }

    private var selectedSubject: SubjectSummary? {
        subjects.first(where: { $0.id == selectedSubjectID })
    }

    private let defaults: UserDefaults
    private let context: NSManagedObjectContext
    private let onUpgradeRequested: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let selectedSubjectID = "attendance.selectedSubjectID"
        static let didMigrateToCoreData = "attendance.didMigrateToCoreDataV1"
        static let legacyTotalClasses = "attendance.totalClasses"
        static let legacyAttendedClasses = "attendance.attendedClasses"
        static let legacyRequiredPercentage = "attendance.requiredPercentage"
        static let proUnlocked = "billing.proUnlocked"
        static let proGatingEnabled = "feature.proGatingEnabled"
        static let notificationsEnabled = "feature.notificationsEnabled"
    }

    private var effectiveSubjectLimit: Int {
        (isProGatingEnabled && isProUnlocked == false) ? Self.freeSubjectLimit : Int.max
    }

    init(
        defaults: UserDefaults = .standard,
        context: NSManagedObjectContext? = nil,
        onUpgradeRequested: (() -> Void)? = nil
    ) {
        self.defaults = defaults
        self.context = context ?? PersistenceController.shared.container.viewContext
        self.onUpgradeRequested = onUpgradeRequested
        self.calculator = AttendanceViewModel(defaults: defaults)
        self.isProUnlocked = defaults.bool(forKey: Keys.proUnlocked)
        // Release override: keep Pro gating disabled while Upgrade to Pro UI is hidden.
        self.isProGatingEnabled = false
        defaults.set(false, forKey: Keys.proGatingEnabled)

        loadSubjects()
        migrateLegacyUserDefaultsIfNeeded()
        ensureAtLeastOneSubject()
        loadSubjects()

        let storedSelectedID = defaults.string(forKey: Keys.selectedSubjectID).flatMap(UUID.init(uuidString:))
        if let storedSelectedID, subjects.contains(where: { $0.id == storedSelectedID }) {
            selectedSubjectID = storedSelectedID
        } else {
            selectedSubjectID = subjects.first?.id
        }
        loadSelectedSubjectIntoCalculator()
        bindCalculatorChanges()
        NotificationService.requestAuthorizationIfNeeded()
        NotificationService.scheduleClassReminder()
    }

    func addSubject(named customName: String? = nil) -> AddSubjectResult {
        guard canAddSubject else { return .limitReached }

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
        loadSubjects()
        selectedSubjectID = entity.id
        return .added
    }

    func deleteSubjects(at offsets: IndexSet) {
        guard subjects.count > 1 else { return }
        let idsToDelete = offsets.map { subjects[$0].id }

        let request = SubjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", idsToDelete)

        if let entities = try? context.fetch(request) {
            entities.forEach(context.delete)
            saveContext()
            loadSubjects()

            if let currentID = selectedSubjectID, subjects.contains(where: { $0.id == currentID }) == false {
                selectedSubjectID = subjects.first?.id
            }
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
            loadSubjects()

            if let currentID = selectedSubjectID, currentID == id {
                selectedSubjectID = subjects.first?.id
            }
        }
    }

    func selectSubject(_ subject: SubjectSummary) {
        selectedSubjectID = subject.id
    }

    func selectSubject(id: UUID) {
        guard subjects.contains(where: { $0.id == id }) else { return }
        selectedSubjectID = id
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
        loadSubjects()
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
        loadSubjects()
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
        loadSubjects()

        if selectedSubjectID == subjectID {
            loadSelectedSubjectIntoCalculator()
        }
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
        loadSubjects()

        if selectedSubjectID == subjectID {
            loadSelectedSubjectIntoCalculator()
        }
    }

    func subjectForecasts(weeks: Int, holidayClassCount: Int, expectedAbsences: Int) -> [SubjectForecast] {
        subjects.map { subject in
            let expectedClasses = CalculationService.projectedTotalClasses(
                schedule: subject.weeklySchedule,
                weeks: weeks,
                holidayClassCount: holidayClassCount
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
                riskLevel: projection.riskLevel
            )
        }
        .sorted { $0.subjectName.localizedCaseInsensitiveCompare($1.subjectName) == .orderedAscending }
    }

    func requestProUpgrade() {
        // Release override: hidden upsell flow.
    }

    // Hook points for future billing / remote config integrations.
    func setProUnlocked(_ unlocked: Bool) {
        isProUnlocked = unlocked
        defaults.set(unlocked, forKey: Keys.proUnlocked)
    }

    func setProGatingEnabled(_ enabled: Bool) {
        isProGatingEnabled = enabled
        defaults.set(enabled, forKey: Keys.proGatingEnabled)
    }

    private func bindCalculatorChanges() {
        Publishers.CombineLatest3(
            calculator.$totalClassesInput,
            calculator.$attendedClassesInput,
            calculator.$requiredPercentageInput
        )
        .dropFirst()
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

        entity.totalClasses = Int32(Int(totalInput) ?? 0)
        entity.attendedClasses = Int32(Int(attendedInput) ?? 0)
        entity.requiredPercentage = Double(requiredInput) ?? calculator.defaultRequiredPercentage
        entity.updatedAt = Date()

        saveContext()
        loadSubjects()
        scheduleNotificationIfNeeded(
            subjectName: entity.name,
            totalClasses: Int(entity.totalClasses),
            attendedClasses: Int(entity.attendedClasses),
            requiredPercentage: entity.requiredPercentage
        )
        recordTrendIfNeeded(
            subjectID: selectedID,
            totalClasses: Int(entity.totalClasses),
            attendedClasses: Int(entity.attendedClasses),
            requiredPercentage: entity.requiredPercentage
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

    private func loadSubjects() {
        let request = SubjectEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let fetched = (try? context.fetch(request)) ?? []
        subjects = fetched.map {
            SubjectSummary(
                id: $0.id,
                name: $0.name,
                totalClasses: Int($0.totalClasses),
                attendedClasses: Int($0.attendedClasses),
                requiredPercentage: $0.requiredPercentage,
                weeklySchedule: Self.decodeSchedule($0.scheduleData),
                createdAt: $0.createdAt
            )
        }
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

    private init() {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "AttendanceModel", managedObjectModel: model)
        if let description = container.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
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
        model.entities = [entity]

        return model
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
