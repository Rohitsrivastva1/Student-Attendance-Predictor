//
//  AttendanceViewModel.swift
//  Student Attendance Predictor
//

import Combine
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
            persistInputs()
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
            persistInputs()
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
            persistInputs()
            calculate()
        }
    }
    @Published private(set) var result: AttendanceResult?
    @Published private(set) var validationMessage: String?

    private let defaults: UserDefaults
    private enum Keys {
        static let totalClasses = "attendance.totalClasses"
        static let attendedClasses = "attendance.attendedClasses"
        static let requiredPercentage = "attendance.requiredPercentage"
        static let defaultRequiredPercentage = "attendance.defaultRequiredPercentage"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultRequired = Self.sanitizedPercentageInput(defaults.string(forKey: Keys.defaultRequiredPercentage) ?? "75")
        self.totalClassesInput = Self.sanitizedIntegerInput(defaults.string(forKey: Keys.totalClasses) ?? "")
        self.attendedClassesInput = Self.sanitizedIntegerInput(defaults.string(forKey: Keys.attendedClasses) ?? "")
        self.requiredPercentageInput = Self.sanitizedPercentageInput(defaults.string(forKey: Keys.requiredPercentage) ?? defaultRequired)
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
        result = makeResult(from: input)
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

    func resetInputs() {
        totalClassesInput = ""
        attendedClassesInput = ""
        requiredPercentageInput = Self.formattedPercentageString(for: defaultRequiredPercentage)
        validationMessage = nil
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

    private func persistInputs() {
        defaults.set(totalClassesInput, forKey: Keys.totalClasses)
        defaults.set(attendedClassesInput, forKey: Keys.attendedClasses)
        defaults.set(requiredPercentageInput, forKey: Keys.requiredPercentage)
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
