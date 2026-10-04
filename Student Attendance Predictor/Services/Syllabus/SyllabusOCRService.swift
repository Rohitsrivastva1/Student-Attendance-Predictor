//
//  SyllabusOCRService.swift
//  Student Attendance Predictor
//
//  On-device text recognition. Homework photos use box positions so
//  a two-column diary (subject | work) stays paired.
//

import CoreImage
import Foundation
import UIKit
import Vision

enum SyllabusOCRError: LocalizedError {
    case noText
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .noText: return "Couldn’t read text from that photo. Try a clearer shot or type it in."
        case .recognitionFailed: return "Text recognition failed. Try again or paste the syllabus."
        }
    }
}

struct DiaryOCRResult {
    var rawReadingOrder: String
    var diaryRows: String
}

private struct OCRBox {
    var text: String
    var minX: CGFloat
    var midX: CGFloat
    var midY: CGFloat
    var width: CGFloat
    var height: CGFloat
}

enum SyllabusOCRService {
    static func recognizeText(from image: UIImage) async throws -> String {
        let result = try await recognizeDiary(from: image)
        return result.rawReadingOrder
    }

    /// Homework diaries: contrast + unsharp, then rebuild rows from box positions.
    static func recognizeDiary(from image: UIImage) async throws -> DiaryOCRResult {
        let prepared = enhanceForHandwriting(image)
        guard let cgImage = rasterCGImage(from: prepared) else {
            throw SyllabusOCRError.recognitionFailed
        }

        var boxes = try await recognizeBoxes(in: cgImage, languageCorrection: false)
        if letterCount(in: boxes) < 12 {
            let corrected = try await recognizeBoxes(in: cgImage, languageCorrection: true)
            if letterCount(in: corrected) > letterCount(in: boxes) {
                boxes = corrected
            }
        }

        let raw = boxes
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
        guard raw.isEmpty == false else { throw SyllabusOCRError.noText }

        let rows = layoutDiaryRows(boxes)
        return DiaryOCRResult(
            rawReadingOrder: String(raw.prefix(12_000)),
            diaryRows: String((rows.isEmpty ? raw : rows).prefix(12_000))
        )
    }

    private static func letterCount(in boxes: [OCRBox]) -> Int {
        boxes.reduce(0) { $0 + $1.text.filter(\.isLetter).count }
    }

    private static func recognizeBoxes(
        in cgImage: CGImage,
        languageCorrection: Bool
    ) async throws -> [OCRBox] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let boxes: [OCRBox] = observations.compactMap { observation in
                    let candidates = observation.topCandidates(4).map(\.string)
                    let text = pickHandwritingCandidate(candidates)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard text.isEmpty == false else { return nil }
                    let box = observation.boundingBox
                    guard box.height >= 0.008, box.width >= 0.012 else { return nil }
                    return OCRBox(
                        text: String(text.prefix(160)),
                        minX: box.minX,
                        midX: box.midX,
                        midY: box.midY,
                        width: box.width,
                        height: box.height
                    )
                }
                continuation.resume(returning: boxes)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = languageCorrection
            request.minimumTextHeight = 0.01
            request.recognitionLanguages = ["en-US", "en-GB", "hi-IN"]

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: .up,
                options: [:]
            )
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Prefer a candidate that still looks like a school word over punctuation junk.
    private static func pickHandwritingCandidate(_ candidates: [String]) -> String {
        let trimmed = candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard let first = trimmed.first else { return "" }
        let scored = trimmed.max { lhs, rhs in
            scoreCandidate(lhs) < scoreCandidate(rhs)
        }
        return scored ?? first
    }

    private static func scoreCandidate(_ text: String) -> Int {
        let letters = text.filter(\.isLetter).count
        let digits = text.filter(\.isNumber).count
        let junk = text.filter { ".$|/\\~`".contains($0) }.count
        return letters * 3 + digits - junk * 2
    }

    private static func layoutDiaryRows(_ boxes: [OCRBox]) -> String {
        let useful = boxes.filter { isPageChrome($0.text) == false }
        guard useful.count >= 2 else {
            return useful.map(\.text).joined(separator: "\n")
        }

        let named = layoutNamedSubjects(useful)
        if named.pairedCount >= 3 {
            return named.text
        }
        let twoColumn = layoutTwoColumns(useful)
        if twoColumn.pairedCount >= 3 {
            return twoColumn.text
        }
        return layoutBySharedY(useful).text
    }

    private struct LayoutScore {
        var text: String
        var pairedCount: Int
    }

    /// Subject names found in the photo are the left column; everything else is homework.
    private static func layoutNamedSubjects(_ boxes: [OCRBox]) -> LayoutScore {
        let subjects = boxes
            .filter { isSubjectNameToken($0.text) }
            .sorted { $0.midY > $1.midY }
        guard subjects.count >= 3 else {
            return LayoutScore(text: "", pairedCount: 0)
        }
        let work = boxes.filter { box in
            subjects.contains(where: { $0.minX == box.minX && $0.midY == box.midY && $0.text == box.text }) == false
        }
        return pairSubjects(subjects, withWork: work)
    }

    private static func pairSubjects(_ subjects: [OCRBox], withWork work: [OCRBox]) -> LayoutScore {
        var lines: [String] = []
        var paired = 0
        for (index, subject) in subjects.enumerated() {
            let upper = index == 0
                ? 1.1
                : (subjects[index - 1].midY + subject.midY) / 2
            let lower = index + 1 < subjects.count
                ? (subject.midY + subjects[index + 1].midY) / 2
                : -0.1
            let works = work
                .filter { $0.midY <= upper && $0.midY > lower }
                .sorted { lhs, rhs in
                    if abs(lhs.midY - rhs.midY) > 0.018 {
                        return lhs.midY > rhs.midY
                    }
                    return lhs.minX < rhs.minX
                }
            if works.isEmpty {
                lines.append(subject.text)
            } else {
                paired += 1
                lines.append("\(subject.text): \(works.map(\.text).joined(separator: " "))")
            }
        }
        return LayoutScore(text: lines.joined(separator: "\n"), pairedCount: paired)
    }

    /// Split the page into left (subjects) and right (homework), then match by vertical band.
    private static func layoutTwoColumns(_ boxes: [OCRBox]) -> LayoutScore {
        let split = columnSplitX(boxes)
        var left: [OCRBox] = []
        var right: [OCRBox] = []
        for box in boxes {
            if looksLikeHomeworkWork(box.text) {
                right.append(box)
            } else if box.width >= 0.58 {
                right.append(box)
            } else if box.minX < split {
                left.append(box)
            } else {
                right.append(box)
            }
        }
        let rejected = left.filter { isLikelySubjectLabel($0.text) == false }
        left = left.filter { isLikelySubjectLabel($0.text) }
        right.append(contentsOf: rejected)
        left.sort { $0.midY > $1.midY }
        right.sort { $0.midY > $1.midY }
        guard left.count >= 3, right.count >= 2 else {
            return LayoutScore(text: "", pairedCount: 0)
        }
        return pairSubjects(left, withWork: right)
    }

    /// Largest horizontal gap in the left-middle of the page (subject | homework).
    private static func columnSplitX(_ boxes: [OCRBox]) -> CGFloat {
        let xs = boxes.map(\.minX).sorted()
        guard xs.count >= 4 else { return 0.38 }
        var bestGap: CGFloat = 0
        var split: CGFloat = 0.38
        for index in 1..<xs.count {
            let gap = xs[index] - xs[index - 1]
            let mid = (xs[index] + xs[index - 1]) / 2
            guard mid > 0.16, mid < 0.58 else { continue }
            if gap > bestGap {
                bestGap = gap
                split = mid
            }
        }
        return bestGap >= 0.05 ? split : 0.38
    }

    /// Tokens that share a Y band are one diary row (subject then work, left to right).
    private static func layoutBySharedY(_ boxes: [OCRBox]) -> LayoutScore {
        let sorted = boxes.sorted { $0.midY > $1.midY }
        let medianHeight = sorted.map(\.height).sorted()[sorted.count / 2]
        let band = max(0.02, medianHeight * 1.4)
        var rows: [[OCRBox]] = []
        for box in sorted {
            if var last = rows.last, let first = last.first, abs(first.midY - box.midY) <= band {
                last.append(box)
                rows[rows.count - 1] = last
            } else {
                rows.append([box])
            }
        }

        var paired = 0
        let lines: [String] = rows.map { row in
            let ordered = row.sorted { $0.minX < $1.minX }
            if ordered.count >= 2, isLikelySubjectLabel(ordered[0].text) || isSubjectNameToken(ordered[0].text) {
                paired += 1
                let subject = ordered[0].text
                let work = ordered.dropFirst().map(\.text).joined(separator: " ")
                return "\(subject): \(work)"
            }
            return ordered.map(\.text).joined(separator: " ")
        }
        return LayoutScore(text: lines.joined(separator: "\n"), pairedCount: paired)
    }

    private static func isSubjectNameToken(_ text: String) -> Bool {
        let cleaned = text
            .lowercased()
            .replacingOccurrences(of: #"^\d+\.?\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count >= 3, cleaned.count <= 22 else { return false }
        let hints = [
            "islamiat", "islamiyat", "islamial", "isamiat", "islam",
            "english", "science", "maths", "math", "mathematics",
            "urdu", "hindi", "punjabi", "sst", "social", "studies",
            "computer", "physics", "chemistry", "biology",
            "history", "geography", "drawing"
        ]
        return hints.contains { hint in
            cleaned == hint
                || cleaned.hasPrefix(hint)
                || (hint.count >= 4 && cleaned.contains(hint))
        }
    }

    private static func isLikelySubjectLabel(_ text: String) -> Bool {
        if isSubjectNameToken(text) { return true }
        if looksLikeHomeworkWork(text) { return false }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(whereSeparator: { $0.isWhitespace })
        guard words.count <= 2, cleaned.count >= 3, cleaned.count <= 22 else { return false }
        if cleaned.filter(\.isNumber).isEmpty == false { return false }
        let lower = cleaned.lowercased()
        let workWords = ["learn", "write", "draw", "reading", "activity", "classwork", "homework", "map"]
        return workWords.contains { lower.contains($0) } == false
    }

    private static func looksLikeHomeworkWork(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("pg") || lower.contains("page") { return true }
        if lower.contains("q#") || lower.contains("q.") { return true }
        if lower.contains("h.work") || lower.contains("h.w") { return true }
        if lower.contains("c.w") || lower.contains("c/w") { return true }
        if lower.contains("unit") || lower.contains("ex.") { return true }
        return false
    }

    private static func isPageChrome(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let chrome = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
                      "date", "day", "diary", "school diary", "homework diary"]
        return chrome.contains(lower)
    }

    private static func enhanceForHandwriting(_ image: UIImage) -> UIImage {
        guard let cgImage = rasterCGImage(from: image) else { return image }
        var ci = CIImage(cgImage: cgImage)

        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(ci, forKey: kCIInputImageKey)
            controls.setValue(1.45, forKey: kCIInputContrastKey)
            controls.setValue(0.06, forKey: kCIInputBrightnessKey)
            controls.setValue(0.0, forKey: kCIInputSaturationKey)
            if let out = controls.outputImage {
                ci = out
            }
        }
        if let sharpen = CIFilter(name: "CIUnsharpMask") {
            sharpen.setValue(ci, forKey: kCIInputImageKey)
            sharpen.setValue(0.6, forKey: kCIInputIntensityKey)
            sharpen.setValue(1.2, forKey: kCIInputRadiusKey)
            if let out = sharpen.outputImage {
                ci = out
            }
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let rendered = context.createCGImage(ci, from: ci.extent) else { return image }
        return UIImage(cgImage: rendered, scale: 1, orientation: .up)
    }

    private static func rasterCGImage(from image: UIImage) -> CGImage? {
        let maxSide: CGFloat = 2200
        var drawSize = image.size
        guard drawSize.width > 1, drawSize.height > 1 else { return image.cgImage }
        let longest = max(drawSize.width, drawSize.height)
        let needsScale = longest > maxSide
        if needsScale {
            let scale = maxSide / longest
            drawSize = CGSize(
                width: (drawSize.width * scale).rounded(),
                height: (drawSize.height * scale).rounded()
            )
        }
        if needsScale == false, image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: drawSize, format: format)
        let flattened = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: drawSize))
        }
        return flattened.cgImage
    }
}
