import Foundation
import Testing
import Domain
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct LocalDataStoreTests {
    @Test func failedSaveDoesNotPublishAnUnsavedSelection() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root, writer: AtomicDocumentWriter { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        let store = LocalDataStore(repository: repository)
        await store.reload()
        await store.changeSource(.acousticPickup)
        #expect(store.preferences.instrument.source == .electricInterface)
        #expect(store.operationError == "storage.saveFailed")
        #expect(!store.isSaving)
    }

    @Test func sourceRestoresInANewUIStore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = LocalDataStore(repository: LocalRepository(root: root))
        await first.reload(); await first.changeSource(.acousticMicrophone)
        let second = LocalDataStore(repository: LocalRepository(root: root))
        await second.reload()
        #expect(second.preferences.instrument.source == .acousticMicrophone)
        #expect(second.operationError == nil)
    }

    @Test func futureSettingsDisableEditingUntilPreservingRecovery() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{\"schemaVersion\":100}".utf8).write(to: root.appendingPathComponent("instrument.json"))
        let store = LocalDataStore(repository: LocalRepository(root: root))
        await store.reload()
        #expect(store.preferencesIssue?.reason == .unsupported)
        #expect(!store.canEditPreferences)
        await store.changeSource(.acousticPickup)
        #expect(store.preferences.instrument.source == .electricInterface)
        await store.recoverPreferences()
        #expect(store.preferencesIssue == nil)
        #expect(store.canEditPreferences)
    }
}
