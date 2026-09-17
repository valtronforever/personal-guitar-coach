import Foundation
import Domain

struct ActivityTextRenderer {
    let lessonID: String
    let version: Int
    let activityID: String
    let choice: PositionChoice
    let region: FretRegion?
    let tuning: TuningProfile
    let tonalRoot: Pitch?
    let exercises: [Exercise]
    let fingerings: [LessonSourceFingering]
    let steps: [LessonStep]
    static let tokens: Set<String> = ["tuning", "reference", "openExample", "openStrings", "root", "first", "highest", "sequence", "positions", "notes", "positionLabel"]

    static func fill(_ text: String, values: [String: String]) throws -> String {
        let parts = text.components(separatedBy: "{{")
        guard let first = parts.first, !first.contains("}}") else { throw LessonAdaptationError.invalidTemplate }
        var result = first
        for part in parts.dropFirst() {
            guard let end = part.range(of: "}}"), let value = values[String(part[..<end.lowerBound])] else { throw LessonAdaptationError.invalidTemplate }
            let suffix = part[end.upperBound...]
            guard !suffix.contains("}}") else { throw LessonAdaptationError.invalidTemplate }
            result += value + suffix
        }
        return result
    }
    static func tokenNames(_ text: String) -> [String] {
        text.components(separatedBy: "{{").dropFirst().compactMap { $0.components(separatedBy: "}}").first }.sorted()
    }
    static func validate(_ text: LessonText) throws {
        guard [text.title, text.summary, text.goal, text.body].allSatisfy({ !$0.contains("{{") && !$0.contains("}}") }) else { throw ContentFailure(.invalidText, "Schema 3 teaching fields cannot contain instrument tokens") }
        let strings = text.steps.values.flatMap { [$0.title, $0.body] } + text.activities.values.flatMap { [$0.title, $0.body] }
            + (text.historicalTitle.map { [$0] } ?? [])
        let values = Dictionary(uniqueKeysWithValues: tokens.map { ($0, "value") })
        for string in strings { _ = try fill(string, values: values) }
    }
    func render(_ text: LessonText) throws -> LessonText {
        let targets = try exercises.flatMap(\.events).flatMap { try $0.visualTargets(in: tuning) }
        let pitches = targets.filter { $0.role != .harmonicBase }.map(\.pitch)
        let names = pitches.map { $0.name(spelling: tuning.preferredSpelling) }
        let positionLabel: String
        if let region { positionLabel = text.locale == "uk" ? "ділянку від \(region.firstFret)-го ладу (до \(region.windowFrets) ладів)" : "the region from fret \(region.firstFret) (up to \(region.windowFrets) frets)" }
        else { positionLabel = text.locale == "uk" ? "початкову аплікатуру" : "the original fingering" }
        var values: [String: String] = [:]
        values["tuning"] = tuning.name
        values["reference"] = String(format: "%.1f", locale: Locale(identifier: text.locale), tuning.referenceA4)
        values["openExample"] = tuning.strings[5].openPitch.name(spelling: tuning.preferredSpelling)
        values["openStrings"] = tuning.strings.reversed().map { $0.openPitch.name(spelling: tuning.preferredSpelling) }.joined(separator: " · ")
        let rootName = tonalRoot?.name(spelling: tuning.preferredSpelling) ?? names.first
        values["root"] = rootName.map { String($0.prefix { !$0.isNumber && $0 != "-" }) } ?? ""
        values["first"] = names.first ?? ""
        values["highest"] = pitches.max(by: { $0.midi < $1.midi })?.name(spelling: tuning.preferredSpelling) ?? ""
        values["sequence"] = names.joined(separator: " – ")
        values["positionLabel"] = positionLabel
        func positionValues(_ targets: [EventFretTarget]) -> [String: String] {
            let notes = targets.filter { $0.role != .harmonicBase }.map { $0.pitch.name(spelling: tuning.preferredSpelling) }
            let positions = targets.map { target in
                let note = target.pitch.name(spelling: tuning.preferredSpelling), p = target.position
                let role = target.role == .harmonicTouch ? (text.locale == "uk" ? ", дотик" : ", touch") : target.role == .harmonicBase ? (text.locale == "uk" ? ", затисни" : ", stop") : ""
                return "\(note) (\(p.string)/\(p.fret)\(role))"
            }
            return ["notes": notes.joined(separator: " – "), "positions": positions.joined(separator: "; ")]
        }
        values.merge(positionValues(targets)) { _, new in new }
        guard let activityText = text.activities[activityID] else { throw ContentFailure(.translationMismatch, "Missing activity text: \(activityID)") }
        let activity = try LessonActivityText(title: Self.fill(activityText.title, values: values), body: Self.fill(activityText.body, values: values))
        var copies: [String: LessonStepText] = [:]
        for step in steps {
            guard let copy = text.steps[step.id] else { throw ContentFailure(.translationMismatch, "Missing step text") }
            var scoped = values
            if step.kind != .none {
                let scopedTargets: [EventFretTarget]
                if let shape = fingerings.first(where: { $0.id == step.fingeringID })?.fingering {
                    scopedTargets = try shape.positions.map { try EventFretTarget(position: $0, pitch: tuning.pitch(at: $0)) }
                } else {
                    scopedTargets = try exercises.first { $0.id == step.exerciseID }?.events.filter { step.eventIDs.contains($0.id) }.flatMap { try $0.visualTargets(in: tuning) } ?? []
                }
                scoped.merge(positionValues(scopedTargets)) { _, new in new }
            }
            copies[step.id] = try LessonStepText(title: Self.fill(copy.title, values: scoped), body: Self.fill(copy.body, values: scoped))
        }
        return try LessonText(lessonID: lessonID, lessonVersion: version, locale: text.locale, title: text.title,
            summary: text.summary, goal: text.goal, body: text.body, steps: copies,
            historicalTitle: text.historicalTitle.map { try Self.fill($0, values: values) }, activities: [activityID: activity], learningTasks: text.learningTasks)
    }
}
