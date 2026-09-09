import Foundation
import Testing
import Audio
import Domain
import Persistence
@testable import PersonalGuitarCoach

private struct EmptyAudioRuntime: AudioRuntime {
    func devices() async throws -> [AudioDeviceDescriptor] { [] }
    func capabilities(device: AudioDeviceDescriptor, channel: Int) async throws -> AudioDeviceCapabilities { throw AudioBackendError.unavailableDevice }
    func startInput(device: AudioDeviceDescriptor, channel: Int) async throws -> AudioStreamFormat { throw AudioBackendError.unavailableDevice }
    func stopInput() async {}
    func readInput() async -> CaptureSnapshot? { nil }
    func startClick(device: AudioDeviceDescriptor, channel: Int) async throws { throw AudioBackendError.unavailableDevice }
    func stopClick() async {}
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) async throws {}
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) async throws {}
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) async throws {}
}
private struct UnrequestedPermission: AudioPermissionProviding {
    func status() async -> AudioPermissionStatus { .notDetermined }
    func request() async -> Bool { Issue.record("Selection must never request audio permission"); return false }
}

@MainActor struct AudioSessionStoreTests {
    private func coordinator() -> AudioSessionCoordinator { AudioSessionCoordinator(runtime: EmptyAudioRuntime(), permissions: UnrequestedPermission()) }
    @Test func savedMissingUIDsRemainSelectedAndExplicitNoneClearsThem() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root)
        let store = AudioSessionStore(repository: repo, coordinator: coordinator())
        await store.load()
        await store.select(inputUID: "missing-usb", outputUID: "missing-output")
        await store.select(inputChannel: 2, outputChannel: 2)
        #expect(store.selection.inputUID == "missing-usb" && store.selection.inputChannel == 2)
        #expect(store.selectedInput == nil && store.selectedOutput == nil)
        let restored = AudioSessionStore(repository: repo, coordinator: coordinator()); await restored.load()
        #expect(restored.selection == store.selection)
        await restored.refresh()
        #expect(restored.selection.inputUID == "missing-usb")
        await restored.select(inputUID: "", outputUID: "")
        #expect(restored.selection == .unselected)
        #expect(try await repo.loadAudioSelection() == .unselected)
    }
    @Test func writeFailureStopsCaptureButDoesNotPublishUnsavedSettings() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root, writer: AtomicDocumentWriter { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        let store = AudioSessionStore(repository: repo, coordinator: coordinator()); await store.load()
        await store.select(inputUID: "usb")
        #expect(store.selection == .unselected)
        #expect(store.storageError == "audio.storageSaveFailed")
        #expect(!store.isBusy)
    }
    @Test func corruptPreferencesDisableEditsAndPreserveTheOriginal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("audio-selection.json")
        try Data("{\"schemaVersion\":20}".utf8).write(to: file)
        let store = AudioSessionStore(repository: LocalRepository(root: root), coordinator: coordinator()); await store.load()
        #expect(store.hasLoaded && store.loadFailed && !store.canEdit)
        await store.select(inputUID: "usb")
        #expect(try String(contentsOf: file, encoding: .utf8) == "{\"schemaVersion\":20}")
    }
}
