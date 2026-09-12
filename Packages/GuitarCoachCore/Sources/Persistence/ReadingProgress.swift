import Foundation
import Domain

/// Reading is independent of performed attempts and their assessments.
public struct LessonBookmark: Codable, Equatable, Sendable {
    public var lessonVersion: Int
    public var stepID: String?
    public var readVersion: Int?
    public var activityChoices: [String: PositionChoice]
    public var activityConfirmations: [String: PositionSelfConfirmation]
    public init(lessonVersion: Int, stepID: String?, readVersion: Int? = nil,
                activityChoices: [String: PositionChoice] = [:], activityConfirmations: [String: PositionSelfConfirmation] = [:]) {
        self.lessonVersion = lessonVersion; self.stepID = stepID; self.readVersion = readVersion
        self.activityChoices = activityChoices; self.activityConfirmations = activityConfirmations
    }
    private enum CodingKeys: String, CodingKey { case lessonVersion, stepID, readVersion, activityChoices, activityConfirmations }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        self.init(lessonVersion: try v.decode(Int.self, forKey: .lessonVersion), stepID: try v.decodeIfPresent(String.self, forKey: .stepID),
            readVersion: try v.decodeIfPresent(Int.self, forKey: .readVersion),
            activityChoices: try v.decodeIfPresent([String: PositionChoice].self, forKey: .activityChoices) ?? [:],
            activityConfirmations: try v.decodeIfPresent([String: PositionSelfConfirmation].self, forKey: .activityConfirmations) ?? [:])
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
                  bookmark.activityChoices.count <= 256, bookmark.activityConfirmations.count <= 256,
                  (Array(bookmark.activityChoices.keys) + Array(bookmark.activityConfirmations.keys)).allSatisfy({ !$0.isEmpty && $0.utf8.count <= 64 }),
                  bookmark.activityChoices.values.allSatisfy({ $0.firstFret.map { (0...24).contains($0) } ?? true }),
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
