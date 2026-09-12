import Foundation
import Domain

extension LessonCatalogLoader {
    func validateActivities(_ manifest: LessonManifest) throws {
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw ContentFailure(.invalidStep, message) }
        }
        let materials = manifest.materials, activities = manifest.activities, entries = manifest.practiceEntries
        try require(!materials.isEmpty && materials.count <= 128 && !activities.isEmpty && activities.count <= 256 && !entries.isEmpty && entries.count <= 256, "Missing or excessive activity data")
        try uniqueIDs(materials.map(\.id)); try uniqueIDs(activities.map(\.id)); try uniqueIDs(entries.map(\.id))
        let shapes = manifest.fingerings
        try require(shapes.count <= 128, "Too many source shapes"); try uniqueIDs(shapes.map(\.id))
        let exercises = Dictionary(uniqueKeysWithValues: manifest.exercises.map { ($0.id, $0) })
        let shapeMap = Dictionary(uniqueKeysWithValues: shapes.map { ($0.id, $0) })
        let materialMap = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        for shape in shapes {
            try require(exercises[shape.exerciseID] != nil && !shape.fingering.positions.isEmpty, "Source shape needs an exercise and sounding positions: \(shape.id)")
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
                }
            case .fingering:
                try require(source.exerciseID == nil && source.eventIDs == nil && source.fingeringID.flatMap { shapeMap[$0] } != nil, "Unknown shape or unexpected source fields")
            }
            let ids = material.exerciseIDs(in: manifest)
            let contexts = ids.compactMap { exercises[$0] }
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
            guard exercise.assessmentMode == .monophonic else { throw ContentFailure(.unsupportedMode, "Practice entry needs a monophonic exercise") }
            try require(selected.contains { $0.kind == .note && $0.positions.count == 1 }, "Practice entry needs sounding monophonic events")
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
