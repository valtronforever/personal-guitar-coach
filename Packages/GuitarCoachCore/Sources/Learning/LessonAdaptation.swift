import Foundation

public enum LessonAdaptationPolicy: String, Codable, Sendable { case fretPattern, transposeIntervals }

/// Tuning adaptation determines pitches; material policies independently permit relocation.
public struct LessonAdaptationDefinition: Codable, Equatable, Sendable {
    public let policy: LessonAdaptationPolicy
    public init(policy: LessonAdaptationPolicy) { self.policy = policy }
}
public enum LessonAdaptationError: Error { case unplayable, invalidTemplate }
