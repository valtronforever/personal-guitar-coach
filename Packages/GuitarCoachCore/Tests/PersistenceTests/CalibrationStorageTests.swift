import Foundation
import Testing
import Domain
@testable import Persistence

struct CalibrationStorageTests {
    private func profile(offset: Double = 0) throws -> CalibrationProfile {
        let endpoint = try CalibrationEndpoint(uid: "usb", channel: 1, sampleRate: 48000, bufferFrames: 512)
        return try CalibrationProfile(route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test"),
                                      method: .manual, residualOffsetSeconds: offset, uncertaintySeconds: 0.2)
    }
    @Test func restoreReplaceAndForgetPreserveOtherDocuments() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root), first = try profile(), next = try profile(offset: 0.05)
        try await repo.saveCalibration(first, replacing: nil)
        #expect(try await LocalRepository(root: root).loadCalibrationProfiles() == [first])
        await #expect(throws: StorageError.identifierConflict) { try await repo.saveCalibration(next, replacing: UUID()) }
        try await repo.saveCalibration(next, replacing: first.id)
        #expect(try await repo.loadCalibrationProfiles() == [next])
        try await repo.saveAudioSelection(.unselected)
        try await repo.removeCalibration(id: next.id)
        #expect(try await repo.loadCalibrationProfiles().isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("audio-selection.json").path))
    }
    @Test func futureAndFailedWritesNeverPublishAProfile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let failing = LocalRepository(root: root, writer: AtomicDocumentWriter { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        await #expect(throws: CocoaError.self) { try await failing.saveCalibration(profile(), replacing: nil) }
        #expect(try await failing.loadCalibrationProfiles().isEmpty)
        let url = root.appendingPathComponent("calibration-profiles.json"), bytes = Data("{\"schemaVersion\":20}".utf8)
        try bytes.write(to: url)
        let repo = LocalRepository(root: root)
        await #expect(throws: StorageError.unsupportedVersion(20)) { try await repo.saveCalibration(profile(), replacing: nil) }
        #expect(try Data(contentsOf: url) == bytes)
    }
}
