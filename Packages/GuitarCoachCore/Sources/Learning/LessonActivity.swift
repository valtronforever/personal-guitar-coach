import Foundation
import Domain

public struct LessonMaterialSource: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case lesson, exercise, events, fingering }
    public let kind: Kind
    public let exerciseID: String?
    public let eventIDs: [String]?
    public let fingeringID: String?
    public init(kind: Kind, exerciseID: String? = nil, eventIDs: [String]? = nil, fingeringID: String? = nil) {
        self.kind = kind; self.exerciseID = exerciseID; self.eventIDs = eventIDs; self.fingeringID = fingeringID
    }
}
public struct LessonMaterial: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let source: LessonMaterialSource
    public let positioning: PositioningPolicy?
    /// Harmonic root in the source tuning, independent of inversion or event order.
    public let tonalRoot: Pitch?
    public var policy: PositioningPolicy { positioning ?? .disabled }
    public init(id: String, source: LessonMaterialSource, positioning: PositioningPolicy? = nil, tonalRoot: Pitch? = nil) {
        self.id = id; self.source = source; self.positioning = positioning; self.tonalRoot = tonalRoot
    }
}
public struct ActivityPositionSelection: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Sendable { case learner, fixed }
    public let mode: Mode
    public let defaultChoice: PositionChoice?
    public let value: PositionChoice?
    public var choice: PositionChoice { value ?? defaultChoice ?? .original }
    public init(mode: Mode, defaultChoice: PositionChoice? = nil, value: PositionChoice? = nil) {
        self.mode = mode; self.defaultChoice = defaultChoice; self.value = value
    }
    private enum CodingKeys: String, CodingKey { case mode, defaultChoice = "default", value }
}
public enum LessonRecordingMode: String, Codable, Sendable { case selfPractice }

public struct LessonActivity: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let materialID: String
    public let positionSelection: ActivityPositionSelection?
    public let recording: LessonRecordingMode?
    public init(id: String, materialID: String, positionSelection: ActivityPositionSelection? = nil, recording: LessonRecordingMode? = nil) {
        self.id = id; self.materialID = materialID; self.positionSelection = positionSelection; self.recording = recording
    }
}
public struct LessonSourceFingering: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let exerciseID: String
    public let fingering: Fingering
    public init(id: String, exerciseID: String, fingering: Fingering) {
        self.id = id; self.exerciseID = exerciseID; self.fingering = fingering
    }
}
public struct LessonPracticeEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let activityID: String
    public let exerciseID: String
    public let presentation: PracticePresentation?
    public init(id: String, activityID: String, exerciseID: String, presentation: PracticePresentation? = nil) {
        self.id = id; self.activityID = activityID; self.exerciseID = exerciseID; self.presentation = presentation
    }
}

public struct ResolvedLessonActivity: Equatable, Sendable {
    public static let resolverVersion = "lesson-activity-1"
    public let lessonID: String
    public let lessonVersion: Int
    public let activity: LessonActivity
    public let material: LessonMaterial
    public let choice: PositionChoice
    public let instrument: InstrumentProfile
    public let exercises: [Exercise]
    public let fingerings: [LessonSourceFingering]
    public let sourceMappings: [ExerciseSourceMapping]
    public let steps: [LessonStep]
    public let english: LessonText
    public let ukrainian: LessonText
    public func text(for language: LessonLanguage) -> LessonText { language == .uk ? ukrainian : english }
    public func visual(stepID: String) throws -> LessonVisualSnapshot {
        guard let step = steps.first(where: { $0.id == stepID }) else { throw ContentFailure(.unknownStep, "Unknown activity step") }
        if step.kind == .none { return LessonVisualSnapshot(exerciseID: nil, tuning: instrument.tuning, events: [], positions: [], mutedStrings: []) }
        guard let exercise = exercises.first(where: { $0.id == step.exerciseID }) else { throw ContentFailure(.unknownExercise, "Unknown activity exercise") }
        let tuning = exercise.requiredTuning ?? instrument.tuning
        if step.kind == .fingering, let shape = fingerings.first(where: { $0.id == step.fingeringID })?.fingering {
            return try LessonVisualSnapshot(exerciseID: exercise.id, tuning: tuning, events: [],
                positions: shape.positions.map { try HighlightedPosition(position: $0, pitch: tuning.pitch(at: $0), finger: shape.fingerNumbers[$0.string]) }, mutedStrings: shape.mutedStrings)
        }
        let events = try exercise.resolvedEvents(instrument: tuning).filter { step.eventIDs.contains($0.id) }
        var seen = Set<EventFretTarget>()
        var positions: [HighlightedPosition] = []
        for event in events {
            for target in try event.event.visualTargets(in: tuning) where seen.insert(target).inserted {
                positions.append(HighlightedPosition(position: target.position, pitch: target.pitch, finger: nil, role: target.role))
            }
        }
        return LessonVisualSnapshot(exerciseID: exercise.id, tuning: tuning, events: events, positions: positions, mutedStrings: Array(Set(events.flatMap { $0.event.mutedAttack?.strings ?? [] })).sorted())
    }
}
