import Foundation
import Domain

extension LessonCatalogLoader {
    func validateActivities(_ manifest: LessonManifest) throws {
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw ContentFailure(.invalidStep, message) }
        }
        let materials = manifest.materials, activities = manifest.activities, entries = manifest.practiceEntries
        try require(materials.count <= 128 && activities.count <= 256 && entries.count <= 256, "Missing or excessive activity data")
        try uniqueIDs(materials.map(\.id)); try uniqueIDs(activities.map(\.id)); try uniqueIDs(entries.map(\.id))
        let shapes = manifest.fingerings
        try require(shapes.count <= 128, "Too many source shapes"); try uniqueIDs(shapes.map(\.id))
        let exercises = Dictionary(uniqueKeysWithValues: manifest.exercises.map { ($0.id, $0) })
        let shapeMap = Dictionary(uniqueKeysWithValues: shapes.map { ($0.id, $0) })
        let materialMap = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        for shape in shapes {
            try require(exercises[shape.exerciseID]?.hasHeldVoices != true, "Held voices cannot be projected into an ordinary fingering")
            try require(exercises[shape.exerciseID] != nil && !shape.fingering.positions.isEmpty, "Source shape needs an exercise and sounding positions: \(shape.id)")
            try require(exercises[shape.exerciseID]?.events.contains(where: { $0.mutedAttack != nil }) != true, "Muted attacks require explicit string roles; ordinary named fingerings cannot represent them")
            try require(exercises[shape.exerciseID]?.events.contains(where: { $0.harmonic != nil }) != true, "Harmonic events require explicit node roles; ordinary named fingerings cannot represent them")
        }
        for material in materials {
            try material.policy.validate()
            let source = material.source
            switch source.kind {
            case .lesson:
                try require(source.exerciseID == nil && source.eventIDs == nil && source.fingeringID == nil, "Lesson source has unexpected fields")
            case .exercise, .events:
                guard let exerciseID = source.exerciseID, let exercise = exercises[exerciseID] else { throw ContentFailure(.unknownExercise, "Unknown material exercise: \(material.id)") }
                try require(source.fingeringID == nil, "Exercise material cannot reference a shape")
                if source.kind == .exercise { try require(source.eventIDs == nil, "Whole exercise cannot select events") }
                else {
                    guard let ids = source.eventIDs, !ids.isEmpty else { throw ContentFailure(.unknownEvent, "Empty event material") }
                    try uniqueIDs(ids)
                    let selected = exercise.events.enumerated().filter { ids.contains($0.element.id) }
                    try require(selected.map(\.element.id) == ids, "Unknown/out-of-order material events")
                    try require(selected.last!.offset - selected.first!.offset + 1 == selected.count, "Material events must be contiguous, including rests")
                    if exercise.metronome != nil {
                        try require(selected.first!.element.startTick % exercise.timeSignature.pulseTicks == 0 && selected.last!.element.endTick % exercise.timeSignature.pulseTicks == 0,
                            "Materials with metronome omissions must contain whole pulses")
                    }
                    if exercise.beatGrouping != nil || ![TimeSignature.threeFour, .fourFour].contains(exercise.timeSignature) {
                        try require(selected.first!.element.startTick % exercise.timeSignature.ticksPerBar == 0 && selected.last!.element.endTick % exercise.timeSignature.ticksPerBar == 0,
                            "Materials with pulse/group patterns must contain whole bars")
                    }
                    let selectedIDs = Set(ids)
                    let groups = exercise.triplets.filter { $0.eventIDs.contains(where: selectedIDs.contains) }
                    try require(groups.allSatisfy { Set($0.eventIDs).isSubset(of: selectedIDs) }, "Event materials must include complete triplet groups")
                    try require(groups.isEmpty || selected.first!.element.startTick % MusicalTime.ppq == 0,
                        "Materials with triplets must begin at a quarter-beat boundary")
                }
            case .fingering:
                try require(source.exerciseID == nil && source.eventIDs == nil && source.fingeringID.flatMap { shapeMap[$0] } != nil, "Unknown shape or unexpected source fields")
            }
            let ids = material.exerciseIDs(in: manifest)
            let contexts = ids.compactMap { exercises[$0] }
            try require(!contexts.isEmpty, "Material needs a source exercise")
            if contexts.contains(where: \.hasHeldVoices) {
                try require(!material.policy.enabled && source.kind != .events && source.kind != .fingering,
                    "Held voices require whole exercises and fixed physical strings")
            }
            if material.tonalRoot != nil {
                try require(manifest.adaptation?.policy == .transposeIntervals && contexts.allSatisfy { $0.requiredTuning != nil },
                    "Explicit tonal root requires interval-preserving adaptation and a source tuning")
            }
            if material.policy.enabled && source.kind != .fingering {
                try require(contexts.contains { exercise in
                    exercise.events.contains { material.eventIDs(in: exercise).contains($0.id) && !$0.positions.isEmpty }
                }, "Positioning needs a sounding material")
            }
            if let first = contexts.first {
                try require(contexts.allSatisfy { exercise in
                    let sameTuning: Bool
                    switch (exercise.requiredTuning, first.requiredTuning) {
                    case (nil, nil): sameTuning = true
                    case let (a?, b?): sameTuning = a.hasSamePitches(as: b)
                    default: sameTuning = false
                    }
                    return exercise.tuningPolicy == first.tuningPolicy && sameTuning
                }, "Material combines incompatible source tuning contexts")
            }
        }
        for activity in activities {
            guard let material = materialMap[activity.materialID] else { throw ContentFailure(.invalidStep, "Unknown activity material") }
            if activity.recording != nil {
                guard material.source.kind == .exercise, let id = material.source.exerciseID, let exercise = exercises[id] else {
                    throw ContentFailure(.invalidStep, "Self-practice recording needs one whole exercise")
                }
                try require(exercise.assessmentMode == .displayOnly && !entries.contains(where: { $0.activityID == activity.id }), "Self-practice recording cannot create a graded entry")
                try require(!manifest.tasks.contains(where: { $0.stimulusExerciseID == id }), "Private listening stimuli cannot expose a recording activity")
                try require(try MusicalTime.seconds(forTicks: exercise.durationTicks, bpm: exercise.maximumBPM, pulseTicks: exercise.timeSignature.pulseTicks) <= 120, "Recording must fit 120 seconds at an available tempo")
                try require(try MusicalTime.seconds(forTicks: exercise.durationTicks + exercise.timeSignature.ticksPerBar, bpm: exercise.maximumBPM, pulseTicks: exercise.timeSignature.pulseTicks) <= 130, "Recording plus count-in must fit 130 seconds")
            }
            if material.policy.enabled {
                guard let selection = activity.positionSelection else { throw ContentFailure(.invalidStep, "Enabled material needs an explicit activity choice") }
                try require(selection.mode == .learner ? selection.defaultChoice != nil && selection.value == nil : selection.value != nil && selection.defaultChoice == nil, "Invalid learner/fixed choice fields")
                try require(material.policy.permits(selection.choice), "Activity default/fixed choice is forbidden by the author policy")
            } else { try require(activity.positionSelection == nil, "Disabled material cannot have a position selection") }
        }
        for step in manifest.steps {
            let activity = step.activityID.flatMap { activityMap[$0] }
            if step.kind == .none {
                try require(step.exerciseID == nil && step.eventIDs.isEmpty && step.fingeringID == nil, "Text-only step has visual data")
                try require(step.activityID == nil || activity != nil, "Unknown text-step activity")
                continue
            }
            guard let activity, let material = materialMap[activity.materialID] else { throw ContentFailure(.invalidStep, "Visual step needs an activity") }
            guard let exerciseID = step.exerciseID, let exercise = exercises[exerciseID], material.exerciseIDs(in: manifest).contains(exerciseID) else { throw ContentFailure(.unknownExercise, "Step exercise is outside the activity material") }
            switch step.kind {
            case .events:
                try require(step.fingeringID == nil && !step.eventIDs.isEmpty && material.source.kind != .fingering, "Invalid event step")
                try uniqueIDs(step.eventIDs)
                guard Set(step.eventIDs).isSubset(of: Set(exercise.events.map(\.id))) else { throw ContentFailure(.unknownEvent, "Unknown step event") }
                let allowed = material.eventIDs(in: exercise)
                try require(exercise.events.filter { step.eventIDs.contains($0.id) }.map(\.id) == step.eventIDs && Set(step.eventIDs).isSubset(of: Set(allowed)), "Step events are outside the material")
            case .fingering:
                guard let id = step.fingeringID, let shape = shapeMap[id] else { throw ContentFailure(.invalidStep, "Unknown step shape") }
                try require(step.eventIDs.isEmpty && shape.exerciseID == exerciseID && material.shapeIDs(in: manifest).contains(id), "Shape step is outside the material")
            case .none: break
            }
        }
        for entry in entries {
            guard let activity = activityMap[entry.activityID], let material = materialMap[activity.materialID], let exercise = exercises[entry.exerciseID] else { throw ContentFailure(.unknownExercise, "Unknown practice activity/exercise") }
            try require(material.source.kind != .fingering && material.exerciseIDs(in: manifest).contains(exercise.id), "Practice exercise is outside the material")
            let selected = exercise.events.filter { material.eventIDs(in: exercise).contains($0.id) }
            guard exercise.assessmentMode != .displayOnly else { throw ContentFailure(.unsupportedMode, "Practice entry needs an assessable exercise") }
            try require(selected.contains { $0.kind == .note && $0.positions.count == 1 }, "Practice entry needs sounding monophonic events")
            if entry.presentation == .listenAndRepeat {
                try require(exercise.assessmentMode == .monophonic, "Hidden responses require note-and-pitch assessment")
                let steps = manifest.steps.filter { $0.activityID == activity.id }
                try require(exercise.events.first?.startTick == 0 && zip(exercise.events, exercise.events.dropFirst()).allSatisfy { $0.endTick == $1.startTick },
                    "Listening responses need explicit rests so revealed notation has no gaps")
                try require(material.source.kind == .exercise && material.source.exerciseID == exercise.id && !material.policy.enabled,
                    "Listen-and-repeat needs a complete, non-positionable private exercise")
                try require(steps.count == 1 && steps[0].kind == .none && !manifest.tasks.contains { $0.stepID == steps[0].id },
                    "Listen-and-repeat needs a dedicated text-only step without answer tasks")
                try require(activities.filter { $0.materialID == material.id }.count == 1 && entries.filter { $0.activityID == activity.id }.count == 1,
                    "Listening activity cannot share its material or practice entry")
                try require(!materials.contains { $0.id != material.id && $0.exerciseIDs(in: manifest).contains(exercise.id) }
                    && !shapes.contains { $0.exerciseID == exercise.id }, "A listening target cannot be exposed through another material or shape")
                try require(manifest.adaptation?.policy == .transposeIntervals, "Listening responses must preserve intervals across tunings")
            }
        }
    }
}

extension LessonMaterial {
    func exerciseIDs(in manifest: LessonManifest) -> [String] {
        switch source.kind {
        case .lesson: return manifest.exercises.map(\.id)
        case .exercise, .events: return source.exerciseID.map { [$0] } ?? []
        case .fingering: return manifest.fingerings.first { $0.id == source.fingeringID }.map { [$0.exerciseID] } ?? []
        }
    }
    func eventIDs(in exercise: Exercise) -> [String] { source.kind == .events ? source.eventIDs ?? [] : exercise.events.map(\.id) }
    func shapeIDs(in manifest: LessonManifest) -> [String] {
        if source.kind == .lesson { return manifest.fingerings.map(\.id) }
        if source.kind == .fingering { return source.fingeringID.map { [$0] } ?? [] }
        return []
    }
}


extension LessonCatalogLoader {
    func validateListeningText(_ text: LessonText, manifest: LessonManifest) throws {
        let activities = Set(manifest.practiceEntries.filter { $0.presentation == .listenAndRepeat }.map(\.activityID))
        let stepIDs = Set(manifest.steps.filter { $0.activityID.map(activities.contains) == true }.map(\.id))
        let strings = text.activities.filter { activities.contains($0.key) }.values.flatMap { [$0.title, $0.body] }
            + text.steps.filter { stepIDs.contains($0.key) }.values.flatMap { [$0.title, $0.body] }
        guard !strings.contains(where: { $0.contains("{{") || $0.contains("}}") }) else {
            throw ContentFailure(.invalidText, "Listening instructions cannot reveal musical context tokens")
        }
    }
}
