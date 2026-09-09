import Foundation
import Testing
import Persistence

struct ReadingProgressTests {
    @Test func readingRoundTripSurvivesClearingPracticeHistory() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root)
        #expect(try await repo.loadReadingProgress() == ReadingProgress())
        let value = ReadingProgress(lastLessonID: "lesson", lessons: ["lesson": LessonBookmark(lessonVersion: 2, stepID: "step", readVersion: 1)])
        try await repo.saveReadingProgress(value)
        try await repo.clearHistory()
        #expect(try await LocalRepository(root: root).loadReadingProgress() == value)
        #expect(try await repo.history().records.isEmpty)
    }

    @Test(arguments: ["{\"schemaVersion\":100}", "broken", "{\"schemaVersion\":1,\"payload\":{\"lessons\":{\"x\":{\"lessonVersion\":0}}}}"])
    func corruptOrFutureReadingIsPreserved(content: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("reading-progress.json")
        let bytes = Data(content.utf8)
        try bytes.write(to: url)
        let repo = LocalRepository(root: root)
        await #expect(throws: (any Error).self) { try await repo.loadReadingProgress() }
        await #expect(throws: (any Error).self) { try await repo.saveReadingProgress(ReadingProgress()) }
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func invalidBookmarksCannotBeCommitted() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root)
        await #expect(throws: StorageError.invalidRecord) { try await repo.saveReadingProgress(ReadingProgress(lastLessonID: "missing")) }
        await #expect(throws: StorageError.invalidRecord) {
            try await repo.saveReadingProgress(ReadingProgress(lessons: ["lesson": LessonBookmark(lessonVersion: 1, stepID: "", readVersion: 0)]))
        }
    }
}
