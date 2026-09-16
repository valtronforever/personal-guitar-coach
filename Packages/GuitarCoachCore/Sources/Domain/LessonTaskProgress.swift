import Foundation

/// A study response is not a performed attempt or an audio assessment.
public struct LessonTaskContext: Codable, Equatable, Sendable {
    public let lessonVersion: Int
    public let instrument: InstrumentProfile?
    public let position: PositionChoice?
    public let resolverVersion: String?
    public init(lessonVersion: Int, instrument: InstrumentProfile? = nil, position: PositionChoice? = nil, resolverVersion: String? = nil) {
        self.lessonVersion = lessonVersion; self.instrument = instrument; self.position = position; self.resolverVersion = resolverVersion
    }
}

public struct LessonTaskProgress: Codable, Equatable, Sendable {
    public let context: LessonTaskContext
    public var checkedIDs: Set<String>
    public var answerID: String?
    public init(context: LessonTaskContext, checkedIDs: Set<String> = [], answerID: String? = nil) {
        self.context = context; self.checkedIDs = checkedIDs; self.answerID = answerID
    }
    public var isValid: Bool {
        context.lessonVersion > 0 && checkedIDs.count <= 32 &&
        (Array(checkedIDs) + (answerID.map { [$0] } ?? [])).allSatisfy { !$0.isEmpty && $0.utf8.count <= 64 } &&
        (context.position?.firstFret.map { (0...24).contains($0) } ?? true) &&
        (context.resolverVersion.map { !$0.isEmpty && $0.utf8.count <= 64 } ?? true)
    }
}
