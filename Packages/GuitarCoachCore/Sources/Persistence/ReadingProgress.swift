import Foundation

/// Reading is independent of performed attempts and their assessments.
public struct LessonBookmark: Codable, Equatable, Sendable {
    public var lessonVersion: Int
    public var stepID: String?
    public var readVersion: Int?
    public init(lessonVersion: Int, stepID: String?, readVersion: Int? = nil) {
        self.lessonVersion = lessonVersion; self.stepID = stepID; self.readVersion = readVersion
    }
}

public struct ReadingProgress: Codable, Equatable, Sendable {
    public var lastLessonID: String?
    public var lessons: [String: LessonBookmark]
    public init(lastLessonID: String? = nil, lessons: [String: LessonBookmark] = [:]) {
        self.lastLessonID = lastLessonID; self.lessons = lessons
    }
    public func validate() throws {
        guard lastLessonID == nil || lessons[lastLessonID!] != nil else { throw StorageError.invalidRecord }
        for (id, bookmark) in lessons {
            guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  bookmark.lessonVersion > 0, bookmark.readVersion.map({ $0 > 0 }) ?? true,
                  bookmark.stepID.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true else {
                throw StorageError.invalidRecord
            }
        }
    }
}

public protocol ReadingRepository: Sendable {
    func loadReadingProgress() async throws -> ReadingProgress
    func saveReadingProgress(_ value: ReadingProgress) async throws
}
