import Foundation
import Domain

public enum LessonDifficulty: String, Codable, CaseIterable, Sendable { case beginner, intermediate, advanced }
public enum LessonTopic: String, Codable, CaseIterable, Sendable { case basics, chromatic, rhythm, majorScale, pentatonic, arpeggios }
public enum LessonLanguage: String, CaseIterable, Sendable { case en, uk }
public enum StepVisualKind: String, Codable, Sendable { case none, events, fingering }

public struct LessonStep: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: StepVisualKind
    public let exerciseID: String?
    public let eventIDs: [String]
    public let fingering: Fingering?
    public init(id: String, kind: StepVisualKind, exerciseID: String? = nil, eventIDs: [String] = [], fingering: Fingering? = nil) {
        self.id = id; self.kind = kind; self.exerciseID = exerciseID; self.eventIDs = eventIDs; self.fingering = fingering
    }
}

public struct LessonManifest: Codable, Sendable, Equatable, Identifiable {
    public let schemaVersion: Int
    public let id: String
    public let version: Int
    public let difficulty: LessonDifficulty
    public let topic: LessonTopic
    public let steps: [LessonStep]
    public let exercises: [Exercise]
    public let practiceExerciseIDs: [String]
    public init(schemaVersion: Int = 1, id: String, version: Int = 1, difficulty: LessonDifficulty = .beginner,
                topic: LessonTopic = .basics, steps: [LessonStep], exercises: [Exercise], practiceExerciseIDs: [String]) {
        self.schemaVersion = schemaVersion; self.id = id; self.version = version; self.difficulty = difficulty; self.topic = topic
        self.steps = steps; self.exercises = exercises; self.practiceExerciseIDs = practiceExerciseIDs
    }
}

public struct LessonStepText: Codable, Sendable, Equatable {
    public let title: String
    public let body: String
    public init(title: String, body: String) { self.title = title; self.body = body }
}

public struct LessonText: Codable, Sendable, Equatable {
    public let lessonID: String
    public let lessonVersion: Int
    public let locale: String
    public let title: String
    public let summary: String
    public let goal: String
    public let body: String
    public let steps: [String: LessonStepText]
    public init(lessonID: String, lessonVersion: Int = 1, locale: String, title: String, summary: String, goal: String,
                body: String, steps: [String: LessonStepText]) {
        self.lessonID = lessonID; self.lessonVersion = lessonVersion; self.locale = locale; self.title = title
        self.summary = summary; self.goal = goal; self.body = body; self.steps = steps
    }
}

public struct LessonCatalogManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let lessons: [String]
    public init(schemaVersion: Int = 1, lessons: [String]) { self.schemaVersion = schemaVersion; self.lessons = lessons }
}

public struct HighlightedPosition: Sendable, Equatable {
    public let position: FretPosition
    public let pitch: Pitch
    public let finger: Int?
}

public struct LessonVisualSnapshot: Sendable {
    public let exerciseID: String?
    public let tuning: TuningProfile
    public let events: [ResolvedEvent]
    /// May include several frets on the same string when a step explains a sequence.
    public let positions: [HighlightedPosition]
    public let mutedStrings: [Int]
}

/// Only the validating loader can construct a lesson consumed by the UI.
public struct LoadedLesson: Identifiable, Sendable {
    public let manifest: LessonManifest
    public let english: LessonText
    public let ukrainian: LessonText
    public var id: String { manifest.id }
    public func text(for language: LessonLanguage) -> LessonText { language == .uk ? ukrainian : english }

    public func visual(stepID: String, instrument: TuningProfile) throws -> LessonVisualSnapshot {
        guard let step = manifest.steps.first(where: { $0.id == stepID }) else {
            throw ContentFailure(.unknownStep, "Unknown step: \(stepID)")
        }
        if step.kind == .none {
            return LessonVisualSnapshot(exerciseID: nil, tuning: instrument, events: [], positions: [], mutedStrings: [])
        }
        guard let exercise = manifest.exercises.first(where: { $0.id == step.exerciseID }) else {
            throw ContentFailure(.unknownExercise, "Unknown exercise for step: \(stepID)")
        }
        let tuning = exercise.requiredTuning ?? instrument
        if step.kind == .fingering, let fingering = step.fingering {
            let positions = try fingering.positions.map {
                try HighlightedPosition(position: $0, pitch: tuning.pitch(at: $0), finger: fingering.fingerNumbers[$0.string])
            }
            return LessonVisualSnapshot(exerciseID: exercise.id, tuning: tuning, events: [], positions: positions, mutedStrings: fingering.mutedStrings)
        }
        let selected = Set(step.eventIDs)
        let events = try exercise.resolvedEvents(instrument: instrument).filter { selected.contains($0.id) }
        var seen = Set<FretPosition>()
        let positions = events.flatMap { resolved in
            zip(resolved.event.positions, resolved.pitches).compactMap { position, pitch in
                seen.insert(position).inserted ? HighlightedPosition(position: position, pitch: pitch, finger: nil) : nil
            }
        }
        return LessonVisualSnapshot(exerciseID: exercise.id, tuning: tuning, events: events, positions: positions, mutedStrings: [])
    }
}

public enum ContentIssueCode: String, Sendable {
    case unsupportedSchema, missingFile, invalidJSON, invalidIdentifier, duplicateIdentifier, invalidMusicalData
    case unknownExercise, unknownEvent, unknownStep, invalidStep, missingTranslation, translationMismatch, invalidText, unavailableCatalog, unsupportedMode
}

public struct ContentFailure: Error, Sendable {
    public let code: ContentIssueCode
    public let detail: String
    public init(_ code: ContentIssueCode, _ detail: String) { self.code = code; self.detail = detail }
}

public struct ContentIssue: Identifiable, Sendable {
    public let id = UUID()
    public let lessonID: String?
    public let code: ContentIssueCode
    /// Diagnostic detail for authors; UI presents localized reason codes.
    public let detail: String
}

public struct LessonCatalogReport: Sendable {
    public let lessons: [LoadedLesson]
    public let issues: [ContentIssue]
}
