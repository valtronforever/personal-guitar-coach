import Foundation
import Domain

public enum LessonAdaptationPolicy: String, Codable, Sendable { case fretPattern, transposeIntervals }

/// Author-owned versions separate newly generated lessons/attempts from immutable legacy content.
public struct LessonAdaptationDefinition: Codable, Equatable, Sendable {
    public let policy: LessonAdaptationPolicy
    public let lessonVersion: Int
    public let exerciseVersion: Int
    public init(policy: LessonAdaptationPolicy, lessonVersion: Int, exerciseVersion: Int) {
        self.policy = policy; self.lessonVersion = lessonVersion; self.exerciseVersion = exerciseVersion
    }
}
public enum LessonAdaptationError: Error { case unplayable, invalidTemplate }

struct AdaptiveLessonText: Sendable, Equatable {
    let english: LessonText
    let ukrainian: LessonText
}

extension LoadedLesson {
    public func adapted(to instrument: InstrumentProfile) throws -> LoadedLesson {
        try adapted(to: instrument.tuning, frets: instrument.frets)
    }

    /// String 1 defines the transposition; nonuniform changes are compensated in the fingering.
    /// Basic physical-string lessons deliberately retain their original string/fret pattern.
    public func adapted(to tuning: TuningProfile, frets: GuitarFretCount = .twentyFour) throws -> LoadedLesson {
        guard let definition = manifest.adaptation, let templates else {
            guard manifest.exercises.flatMap(\.events).flatMap(\.positions).allSatisfy({ $0.fret <= frets.rawValue }),
                  manifest.steps.compactMap(\.fingering).flatMap(\.positions).allSatisfy({ $0.fret <= frets.rawValue }) else { throw LessonAdaptationError.unplayable }
            return self
        }
        var shapeMappings: [TuningProfile: [FretPosition: FretPosition]] = [:]
        for step in manifest.steps {
            guard let shape = step.fingering, let source = manifest.exercises.first(where: { $0.id == step.exerciseID }) else { continue }
            let positions = try adaptedPositions(shape.positions, source: source, tuning: tuning, policy: definition.policy, maximumFret: frets.rawValue)
            shapeMappings[source.requiredTuning ?? .standard] = Dictionary(uniqueKeysWithValues: zip(shape.positions, positions))
        }
        func positions(_ original: [FretPosition], source: Exercise) throws -> [FretPosition] {
            if let mapping = shapeMappings[source.requiredTuning ?? .standard], original.allSatisfy({ mapping[$0] != nil }) {
                return original.compactMap { mapping[$0] }
            }
            return try adaptedPositions(original, source: source, tuning: tuning, policy: definition.policy, maximumFret: frets.rawValue)
        }
        let exercises = try manifest.exercises.map { source in
            let events = try source.events.map { event in
                try MusicalEvent(id: event.id, startTick: event.startTick, durationTicks: event.durationTicks,
                    kind: event.kind, positions: positions(event.positions, source: source))
            }
            return try Exercise(id: source.id, version: definition.exerciseVersion, ppq: source.ppq, events: events,
                timeSignature: source.timeSignature, defaultBPM: source.defaultBPM, minimumBPM: source.minimumBPM,
                maximumBPM: source.maximumBPM, tuningPolicy: .fixedTuning, requiredTuning: tuning, assessmentMode: source.assessmentMode)
        }
        let steps = try manifest.steps.map { step in
            guard let shape = step.fingering, let source = manifest.exercises.first(where: { $0.id == step.exerciseID }) else { return step }
            let positions = try adaptedPositions(shape.positions, source: source, tuning: tuning, policy: definition.policy, maximumFret: frets.rawValue)
            let unchanged = Set(positions) == Set(shape.positions)
            let fingering = try Fingering(positions: positions, mutedStrings: Array(Set(1...6).subtracting(positions.map(\.string))).sorted(),
                fingerNumbers: unchanged ? shape.fingerNumbers : [:])
            return LessonStep(id: step.id, kind: step.kind, exerciseID: step.exerciseID, eventIDs: step.eventIDs, fingering: fingering)
        }
        let resolved = LessonManifest(id: id, version: definition.lessonVersion, difficulty: manifest.difficulty,
            topic: manifest.topic, steps: steps, exercises: exercises, practiceExerciseIDs: manifest.practiceExerciseIDs)
        try LessonCatalogLoader().validate(resolved)
        return try LoadedLesson(manifest: resolved,
            english: render(templates.english, resolved: resolved, tuning: tuning),
            ukrainian: render(templates.ukrainian, resolved: resolved, tuning: tuning))
    }

    private func adaptedPositions(_ positions: [FretPosition], source: Exercise, tuning: TuningProfile,
                                  policy: LessonAdaptationPolicy, maximumFret: Int) throws -> [FretPosition] {
        guard policy == .transposeIntervals, !positions.isEmpty else {
            guard positions.allSatisfy({ $0.fret <= maximumFret }) else { throw LessonAdaptationError.unplayable }
            return positions
        }
        let reference = source.requiredTuning ?? .standard
        let shift = tuning.strings[0].openPitch.midi - reference.strings[0].openPitch.midi
        let candidates = try positions.map { position -> [FretPosition] in
            let midi = try reference.pitch(at: position).midi + shift
            return tuning.strings.compactMap { string in
                try? FretPosition(string: string.number, fret: midi - string.openPitch.midi)
            }.filter { $0.fret <= maximumFret }.sorted {
                let a = abs($0.string - position.string) * 12 + abs($0.fret - position.fret)
                let b = abs($1.string - position.string) * 12 + abs($1.fret - position.fret)
                return a == b ? $0.string < $1.string : a < b
            }
        }
        guard candidates.allSatisfy({ !$0.isEmpty }) else { throw LessonAdaptationError.unplayable }
        if positions.count == 1 { return [candidates[0][0]] }
        // At most six voices × six string choices. Never assign two chord voices to one string.
        var best: [FretPosition]?, bestCost = Int.max
        func search(_ chosen: [FretPosition], cost: Int) {
            guard cost < bestCost else { return }
            if chosen.count == positions.count {
                let fretted = chosen.filter { $0.fret > 0 }.map(\.fret)
                guard (fretted.max() ?? 0) - (fretted.min() ?? 0) <= 4 else { return }
                best = chosen; bestCost = cost; return
            }
            let index = chosen.count, original = positions[index]
            for candidate in candidates[index] where !chosen.contains(where: { $0.string == candidate.string }) {
                search(chosen + [candidate], cost: cost + abs(candidate.string - original.string) * 12 + abs(candidate.fret - original.fret))
            }
        }
        search([], cost: 0)
        guard let best else { throw LessonAdaptationError.unplayable }
        return best
    }

    private func render(_ template: LessonText, resolved: LessonManifest, tuning: TuningProfile) throws -> LessonText {
        guard let practice = resolved.exercises.first(where: { resolved.practiceExerciseIDs.contains($0.id) }) else { throw LessonAdaptationError.invalidTemplate }
        let events = try practice.resolvedEvents(instrument: tuning)
        guard !events.flatMap(\.pitches).isEmpty else { throw LessonAdaptationError.invalidTemplate }
        let names = events.flatMap(\.pitches).map { $0.name(spelling: tuning.preferredSpelling) }
        let root = names.first.map { String($0.prefix { !$0.isNumber && $0 != "-" }) } ?? ""
        let referenceText = String(format: "%.1f", locale: Locale(identifier: template.locale), tuning.referenceA4)
        let values = ["tuning": tuning.name, "reference": referenceText,
            "openExample": tuning.strings[5].openPitch.name(spelling: tuning.preferredSpelling),
            "openStrings": tuning.strings.reversed().map { $0.openPitch.name(spelling: tuning.preferredSpelling) }.joined(separator: " · "),
            "root": root, "first": names.first ?? "", "highest": events.flatMap(\.pitches).max(by: { $0.midi < $1.midi })?.name(spelling: tuning.preferredSpelling) ?? "",
            "sequence": names.joined(separator: " – ")]
        func fill(_ text: String, values: [String: String]) throws -> String {
            let parts = text.components(separatedBy: "{{")
            guard let first = parts.first, !first.contains("}}") else { throw LessonAdaptationError.invalidTemplate }
            var result = first
            for part in parts.dropFirst() {
                guard let end = part.range(of: "}}"), let value = values[String(part[..<end.lowerBound])] else {
                    throw LessonAdaptationError.invalidTemplate
                }
                let suffix = part[end.upperBound...]
                guard !suffix.contains("}}") else { throw LessonAdaptationError.invalidTemplate }
                result += value + suffix
            }
            return result
        }
        var texts: [String: LessonStepText] = [:]
        for step in resolved.steps {
            guard let copy = template.steps[step.id] else { throw LessonAdaptationError.invalidTemplate }
            var stepValues = values
            if step.kind != .none {
                guard let exercise = resolved.exercises.first(where: { $0.id == step.exerciseID }) else { throw LessonAdaptationError.invalidTemplate }
                let positions = step.fingering?.positions ?? exercise.events.filter { step.eventIDs.contains($0.id) }.flatMap(\.positions)
                let descriptions = try positions.map { position in
                    let note = try tuning.pitch(at: position).name(spelling: tuning.preferredSpelling)
                    return "\(note) (\(position.string)/\(position.fret))"
                }
                stepValues["positions"] = descriptions.joined(separator: "; ")
                stepValues["notes"] = try positions.map { try tuning.pitch(at: $0).name(spelling: tuning.preferredSpelling) }.joined(separator: " – ")
            }
            texts[step.id] = try LessonStepText(title: fill(copy.title, values: stepValues), body: fill(copy.body, values: stepValues))
        }
        return try LessonText(lessonID: id, lessonVersion: resolved.version, locale: template.locale,
            title: fill(template.title, values: values), summary: fill(template.summary, values: values),
            goal: fill(template.goal, values: values), body: fill(template.body, values: values), steps: texts,
            variant: template.variant.map { try LessonVariantText(title: fill($0.title, values: values), body: fill($0.body, values: values)) },
            historicalTitle: template.historicalTitle.map { try fill($0, values: values) })
    }
}
