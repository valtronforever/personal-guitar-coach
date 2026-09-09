import Foundation
import Testing
import Persistence
@testable import PersonalGuitarCoach

private actor ReadingStub: ReadingRepository {
    var value = ReadingProgress()
    var failLoad = false
    var failSave = false
    var delayFirstSave = false
    var writes: [ReadingProgress] = []
    var gate: CheckedContinuation<Void, Never>?
    func configure(loadFailure: Bool = false, saveFailure: Bool = false, delay: Bool = false) {
        failLoad = loadFailure; failSave = saveFailure; delayFirstSave = delay
    }
    func loadReadingProgress() throws -> ReadingProgress {
        if failLoad { throw StorageError.corruptDocument }; return value
    }
    func saveReadingProgress(_ progress: ReadingProgress) async throws {
        if failSave { throw CocoaError(.fileWriteOutOfSpace) }
        if delayFirstSave {
            delayFirstSave = false
            await withCheckedContinuation { gate = $0 }
        }
        writes.append(progress); value = progress
    }
    func release() { gate?.resume(); gate = nil }
    func isWaiting() -> Bool { gate != nil }
}

@MainActor struct ReadingProgressStoreTests {
    private func settle(_ store: ReadingProgressStore) async throws {
        for _ in 0..<1000 {
            await Task.yield()
            if !store.isSaving { await store.flush(); if !store.isSaving { return } }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Reading writer did not settle")
    }

    @Test func rapidChangesDrainLatestSnapshotWithoutOverwritingReadVersion() async throws {
        let repo = ReadingStub(); await repo.configure(delay: true)
        let store = ReadingProgressStore(repository: repo); await store.load()
        store.visit(lessonID: "lesson", version: 1, stepID: "first")
        for _ in 0..<1000 {
            if await repo.isWaiting() { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(await repo.isWaiting())
        store.visit(lessonID: "lesson", version: 1, stepID: "last")
        store.setRead(true, lessonID: "lesson", version: 1, stepID: "last")
        await repo.release(); try await settle(store)
        #expect(await repo.value.lessons["lesson"]?.stepID == "last")
        #expect(await repo.value.lessons["lesson"]?.readVersion == 1)
        store.visit(lessonID: "lesson", version: 2, stepID: "new")
        try await settle(store)
        #expect(await repo.value.lessons["lesson"]?.lessonVersion == 2)
        #expect(await repo.value.lessons["lesson"]?.readVersion == 1)
        let restored = ReadingProgressStore(repository: repo); await restored.load()
        #expect(restored.progress == store.progress)
    }

    @Test func saveFailureRetainsLatestSelectionAndRetryCommitsIt() async throws {
        let repo = ReadingStub(); await repo.configure(saveFailure: true)
        let store = ReadingProgressStore(repository: repo); await store.load()
        store.visit(lessonID: "lesson", version: 1, stepID: "step")
        try await settle(store)
        #expect(store.saveFailed && store.progress.lastLessonID == "lesson")
        #expect(await repo.value.lessons.isEmpty)
        await repo.configure(); await store.flush()
        #expect(!store.saveFailed)
        #expect(await repo.value == store.progress)
    }

    @Test func loadFailureKeepsReadingAvailableWithoutReplacingSavedData() async throws {
        let repo = ReadingStub(); await repo.configure(loadFailure: true)
        let store = ReadingProgressStore(repository: repo); await store.load()
        #expect(store.hasLoaded && store.loadFailed && !store.canEdit)
        store.visit(lessonID: "lesson", version: 1, stepID: "step")
        await store.flush()
        #expect(await repo.writes.isEmpty)
        await repo.configure(); await store.load()
        #expect(store.canEdit)
    }
}
