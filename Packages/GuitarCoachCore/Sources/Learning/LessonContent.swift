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
    public let activityID: String?
    public let fingeringID: String?
    public init(id: String, kind: StepVisualKind, exerciseID: String? = nil, eventIDs: [String] = [], activityID: String? = nil, fingeringID: String? = nil) {
        self.id = id; self.kind = kind; self.exerciseID = exerciseID; self.eventIDs = eventIDs
        self.activityID = activityID; self.fingeringID = fingeringID
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
    public let adaptation: LessonAdaptationDefinition?
    public let materials: [LessonMaterial]
    public let activities: [LessonActivity]
    public let practiceEntries: [LessonPracticeEntry]
    public let fingerings: [LessonSourceFingering]
    public init(schemaVersion: Int = 2, id: String, version: Int = 1, difficulty: LessonDifficulty = .beginner,
                topic: LessonTopic = .basics, steps: [LessonStep], exercises: [Exercise], adaptation: LessonAdaptationDefinition? = nil,
                materials: [LessonMaterial], activities: [LessonActivity], practiceEntries: [LessonPracticeEntry], fingerings: [LessonSourceFingering] = []) {
        self.schemaVersion = schemaVersion; self.id = id; self.version = version; self.difficulty = difficulty; self.topic = topic
        self.steps = steps; self.exercises = exercises; self.adaptation = adaptation
        self.materials = materials; self.activities = activities; self.practiceEntries = practiceEntries; self.fingerings = fingerings
    }
}

public struct LessonStepText: Codable, Sendable, Equatable {
    public let title: String
    public let body: String
    public init(title: String, body: String) { self.title = title; self.body = body }
}

/// Instrument-specific example, rendered from the same musical snapshot as the exercise.
public struct LessonActivityText: Codable, Sendable, Equatable {
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
    /// Optional original heading retained for historical result presentation after an editorial rename.
    public let historicalTitle: String?
    public let activities: [String: LessonActivityText]
    public init(lessonID: String, lessonVersion: Int = 1, locale: String, title: String, summary: String, goal: String,
                body: String, steps: [String: LessonStepText], historicalTitle: String? = nil, activities: [String: LessonActivityText]) {
        self.lessonID = lessonID; self.lessonVersion = lessonVersion; self.locale = locale; self.title = title
        self.summary = summary; self.goal = goal; self.body = body; self.steps = steps
        self.historicalTitle = historicalTitle; self.activities = activities
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
public struct LoadedLesson: Identifiable, Sendable, Equatable {
    public let manifest: LessonManifest
    public let english: LessonText
    public let ukrainian: LessonText
    init(manifest: LessonManifest, english: LessonText, ukrainian: LessonText) {
        self.manifest = manifest; self.english = english; self.ukrainian = ukrainian
    }
    public var id: String { manifest.id }
    public func text(for language: LessonLanguage) -> LessonText { language == .uk ? ukrainian : english }
}

public enum ContentIssueCode: String, Sendable {
    case unsupportedSchema, missingFile, invalidYAML, invalidIdentifier, duplicateIdentifier, invalidMusicalData
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
