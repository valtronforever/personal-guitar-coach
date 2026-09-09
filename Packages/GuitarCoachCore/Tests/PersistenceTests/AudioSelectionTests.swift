import Foundation
import Testing
import Domain
import Persistence

struct AudioSelectionTests {
    @Test func deviceUIDsAndChannelsSurviveRepositoryReloadAndHistoryClearing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root)
        #expect(try await repo.loadAudioSelection() == .unselected)
        let selection = try AudioRouteSelection(inputUID: "usb-input", inputChannel: 2, outputUID: "usb-output", outputChannel: 4)
        try await repo.saveAudioSelection(selection); try await repo.clearHistory()
        #expect(try await LocalRepository(root: root).loadAudioSelection() == selection)
        #expect(throws: MusicError.invalidAudioRoute) { try AudioRouteSelection(inputChannel: 0) }
        #expect(throws: MusicError.invalidAudioRoute) { try AudioRouteSelection(outputChannel: 257) }
        #expect(throws: MusicError.invalidAudioRoute) { try AudioRouteSelection(inputUID: " ") }
    }
    @Test(arguments: ["broken", "{\"schemaVersion\":99}"])
    func unreadableAudioSelectionIsPreserved(content: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("audio-selection.json")
        try Data(content.utf8).write(to: file)
        let repo = LocalRepository(root: root)
        await #expect(throws: (any Error).self) { try await repo.loadAudioSelection() }
        await #expect(throws: (any Error).self) { try await repo.saveAudioSelection(.unselected) }
        #expect(try String(contentsOf: file, encoding: .utf8) == content)
    }
}
