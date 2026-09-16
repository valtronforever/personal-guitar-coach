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
    @Test func legacyProfilesMigrateOnWriteWithoutInventingPersonalEvidence() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let first = try profile(), url = root.appendingPathComponent("calibration-profiles.json")
        try JSONEncoder().encode(DocumentEnvelope(schemaVersion: 1, payload: [first])).write(to: url)
        let repository = LocalRepository(root: root)
        #expect(try await repository.loadCalibrationProfiles() == [first])
        let sync = try PersonalSyncEvidence(instrument: InstrumentProfile(), string: 3, offsets: [0.1, 0.1], spreads: [0, 0], drifts: [0, 0])
        let personal = try CalibrationProfile(route: first.route, method: .personal, residualOffsetSeconds: sync.offset,
                                             uncertaintySeconds: sync.uncertainty, personalEvidence: sync)
        try await repository.saveCalibration(personal, replacing: first.id)
        #expect(try await repository.loadCalibrationProfiles() == [personal])
        let document = try JSONDecoder().decode(DocumentEnvelope<[CalibrationProfile]>.self, from: Data(contentsOf: url))
        #expect(document.schemaVersion == 3 && document.payload[0].method == .personal)
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

extension CalibrationStorageTests {
    @Test func independentOutputDefaultsToZeroReplacesAndResetsWithoutTouchingInstrument() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root), old = try profile()
        #expect(try await repo.loadOutputAlignments().isEmpty)
        try await repo.removeOutputAlignment(id: UUID()) // Reset is idempotent before any settings directory exists.
        try await repo.saveCalibration(old, replacing: nil)
        let first = try OutputAlignmentProfile(output: old.route.output, evidence: SyncPassEvidence(offset: 0.2, spread: 0, drift: 0))
        let second = try OutputAlignmentProfile(output: old.route.output, evidence: SyncPassEvidence(offset: 0.1, spread: 0, drift: 0))
        try await repo.saveOutputAlignment(first); try await repo.saveOutputAlignment(second)
        #expect(try await LocalRepository(root: root).loadOutputAlignments() == [second])
        let evidence = try InstrumentSyncEvidence(instrument: InstrumentProfile(), string: 3, outputSetting: second, guitar: SyncPassEvidence(offset: 0.05, spread: 0, drift: 0))
        let instrument = try CalibrationProfile(route: old.route, method: .personal, residualOffsetSeconds: evidence.offset, uncertaintySeconds: evidence.uncertainty, instrumentEvidence: evidence)
        try await repo.saveCalibration(instrument, replacing: old.id)
        try await repo.removeOutputAlignment(id: second.id)
        #expect(try await repo.loadOutputAlignments().isEmpty)
        #expect(try await repo.loadCalibrationProfiles() == [instrument])
    }
    @Test func outputWriteFailureAndFutureSchemaPreserveExistingBytes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LocalRepository(root: root)
        let first = try OutputAlignmentProfile(output: profile().route.output, evidence: SyncPassEvidence(offset: 0.2, spread: 0, drift: 0))
        try await repo.saveOutputAlignment(first)
        let url = root.appendingPathComponent("output-alignment.json"), original = try Data(contentsOf: url)
        let failing = LocalRepository(root: root, writer: AtomicDocumentWriter { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        await #expect(throws: CocoaError.self) { try await failing.removeOutputAlignment(id: first.id) }
        #expect(try Data(contentsOf: url) == original)
        let future = Data("{\"schemaVersion\":99}".utf8); try future.write(to: url)
        await #expect(throws: StorageError.unsupportedVersion(99)) { try await repo.saveOutputAlignment(first) }
        #expect(try Data(contentsOf: url) == future)
    }
}
