import Foundation
import Domain

extension LoadedLesson {
    public var activityDefinitions: [LessonActivity] { manifest.activities }
    public var materialDefinitions: [LessonMaterial] { manifest.materials }
    public var activityPracticeEntries: [LessonPracticeEntry] { manifest.practiceEntries }
    public func positioningPolicy(activityID: String) -> PositioningPolicy? {
        guard let activity = manifest.activities.first(where: { $0.id == activityID }) else { return nil }
        return manifest.materials.first { $0.id == activity.materialID }?.policy
    }
    public func availableChoices(activityID: String, instrument: InstrumentProfile) -> [PositionChoice] {
        guard let activity = activityDefinitions.first(where: { $0.id == activityID }), let policy = positioningPolicy(activityID: activityID) else { return [] }
        let choices = activity.positionSelection?.mode == .fixed ? [activity.positionSelection!.choice] : policy.choices
        return choices.filter { (try? resolveActivity(id: activityID, instrument: instrument, choice: $0)) != nil }
    }

    public func resolveActivity(id activityID: String, instrument: InstrumentProfile, choice requested: PositionChoice? = nil) throws -> ResolvedLessonActivity {
        guard let activity = activityDefinitions.first(where: { $0.id == activityID }) else { throw ContentFailure(.invalidStep, "Unknown activity: \(activityID)") }
        let choice = requested ?? activity.positionSelection?.choice ?? .original
        if activity.positionSelection?.mode == .fixed, choice != activity.positionSelection?.choice { throw PositioningError.forbiddenChoice }
        guard let policy = positioningPolicy(activityID: activityID) else { throw PositioningError.invalidPolicy }
        let region = try policy.region(for: choice)
        if let region, region.firstFret > instrument.fretCount { throw PositioningError.beyondFretCount }
        guard let material = manifest.materials.first(where: { $0.id == activity.materialID }) else { throw PositioningError.invalidPolicy }
        let sourceExercises = manifest.exercises.filter { material.exerciseIDs(in: manifest).contains($0.id) }
        guard let first = sourceExercises.first else { throw ContentFailure(.unknownExercise, "Material has no source exercise") }
        let tuning = manifest.adaptation == nil ? first.requiredTuning ?? instrument.tuning : instrument.tuning
        let shapes = manifest.fingerings.filter { material.shapeIDs(in: manifest).contains($0.id) }
        func resolvePositions(_ positions: [FretPosition], source: Exercise) throws -> [FretPosition] {
            if region == nil && manifest.adaptation?.policy != .transposeIntervals {
                guard positions.allSatisfy({ $0.fret <= instrument.fretCount }) else { throw PositioningError.beyondFretCount }
                return positions
            }
            let reference: TuningProfile
            let shift: Int
            if manifest.adaptation?.policy == .transposeIntervals {
                reference = source.requiredTuning ?? .standard
                shift = tuning.strings[0].openPitch.midi - reference.strings[0].openPitch.midi
            } else { reference = tuning; shift = 0 }
            do {
                return try LessonFingeringResolver.resolve(positions, sourceTuning: reference, tuning: tuning, shift: shift,
                    maximumFret: instrument.fretCount, region: region)
            } catch LessonAdaptationError.unplayable { throw PositioningError.regionUnplayable }
        }
        var sharedMapping: [FretPosition: FretPosition] = [:]
        let resolvedShapes = try shapes.map { shape -> LessonSourceFingering in
            guard let source = sourceExercises.first(where: { $0.id == shape.exerciseID }) else { throw PositioningError.incompatibleTuning }
            let positions = try resolvePositions(shape.fingering.positions, source: source)
            for (before, after) in zip(shape.fingering.positions, positions) {
                if let existing = sharedMapping[before], existing != after { throw PositioningError.regionUnplayable }
                sharedMapping[before] = after
            }
            let same = positions == shape.fingering.positions
            return try LessonSourceFingering(id: shape.id, exerciseID: shape.exerciseID,
                fingering: Fingering(positions: positions,
                    mutedStrings: same ? shape.fingering.mutedStrings : Array(Set(1...6).subtracting(positions.map(\.string))).sorted(),
                    fingerNumbers: same ? shape.fingering.fingerNumbers : [:]))
        }
        var mappings: [ExerciseSourceMapping] = []
        let exercises = try sourceExercises.map { source -> Exercise in
            let selected = source.events.filter { material.eventIDs(in: source).contains($0.id) }
            let offset = material.source.kind == .events ? selected.first?.startTick ?? 0 : 0
            mappings.append(ExerciseSourceMapping(exerciseID: source.id, exerciseVersion: source.version, startTick: offset, eventIDs: selected.map(\.id)))
            let events: [MusicalEvent]
            if material.source.kind == .fingering, let shape = resolvedShapes.first {
                events = [try MusicalEvent(id: shape.id, startTick: 0, durationTicks: source.timeSignature.ticksPerBar, kind: .note, positions: shape.fingering.positions)]
                mappings[mappings.count - 1] = ExerciseSourceMapping(exerciseID: source.id, exerciseVersion: source.version, startTick: 0, eventIDs: [])
            } else {
                events = try selected.map { event in
                    let positions: [FretPosition]
                    if event.positions.allSatisfy({ sharedMapping[$0] != nil }) { positions = event.positions.compactMap { sharedMapping[$0] } }
                    else { positions = try resolvePositions(event.positions, source: source) }
                    return try MusicalEvent(id: event.id, startTick: event.startTick - offset, durationTicks: event.durationTicks, kind: event.kind, positions: positions)
                }
            }
            return try Exercise(id: source.id, version: source.version, ppq: source.ppq, events: events,
                timeSignature: source.timeSignature, defaultBPM: source.defaultBPM, minimumBPM: source.minimumBPM, maximumBPM: source.maximumBPM,
                tuningPolicy: .fixedTuning, requiredTuning: tuning, assessmentMode: material.source.kind == .fingering || !events.contains(where: { $0.kind == .note }) ? .displayOnly : source.assessmentMode)
        }
        let steps = manifest.steps.filter { $0.activityID == activityID }.map { step in
            LessonStep(id: step.id, kind: step.kind, exerciseID: step.exerciseID, eventIDs: step.eventIDs,
                activityID: step.activityID, fingeringID: step.fingeringID)
        }
        let version = manifest.version
        let renderer = ActivityTextRenderer(lessonID: id, version: version, activityID: activityID, choice: choice, region: region,
            tuning: tuning, exercises: exercises, fingerings: resolvedShapes, steps: steps)
        return try ResolvedLessonActivity(lessonID: id, lessonVersion: version, activity: activity, material: material, choice: choice,
            instrument: instrument, exercises: exercises, fingerings: resolvedShapes, sourceMappings: mappings, steps: steps,
            english: renderer.render(english), ukrainian: renderer.render(ukrainian))
    }
}
