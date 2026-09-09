import Foundation
import Testing
import Domain
@testable import Persistence

struct RepositoryTests {
    private func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("guitar-coach-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func record(id: UUID = UUID(), bpm: Double = 60) throws -> PracticeRecord {
        let events = try [MusicalEvent(id: "first", startTick: 0, durationTicks: 960, kind: .note,
                                      positions: [FretPosition(string: 6, fret: 0)]),
                          MusicalEvent(id: "second", startTick: 960, durationTicks: 960, kind: .note,
                                      positions: [FretPosition(string: 6, fret: 2)])]
        return try PracticeRecord(id: id, startedAt: Date(timeIntervalSince1970: 1_000_000_000),
                                  finishedAt: Date(timeIntervalSince1970: 1_000_000_004),
                                  exercise: Exercise(id: "test-exercise", events: events),
                                  instrument: InstrumentProfile(tuning: .dropD), bpm: bpm,
                                  result: AssessmentSnapshot(algorithmVersion: "fixture-v1", validity: .uncalibrated,
                                                             pitchScore: 80, expectedCount: 2, matchedCount: 2,
                                                             missedCount: 0, extraCount: 0))
    }

    @Test func roundTripAndSettingsChangesCannotRewriteHistory() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root)
        let attempt = try record()
        #expect(try await repository.save(attempt).isEmpty)
        let custom = try TuningProfile(id: "custom", revision: 2, name: "My renamed tuning", strings: TuningProfile.standard.strings)
        let preferences = try InstrumentPreferences(instrument: InstrumentProfile(tuning: custom, orientation: .leftHanded,
                                                                                 source: .acousticPickup),
                                                    customTunings: [custom], practiceBPM: 120)
        try await repository.savePreferences(preferences)
        let reopened = LocalRepository(root: root)
        let history = try await reopened.history()
        #expect(history.records == [attempt])
        #expect(history.records[0].bpm == 60)
        #expect(history.records[0].instrument.tuning == .dropD)
        guard case let .available(restored, migrated) = await reopened.loadPreferences() else { Issue.record("preferences missing"); return }
        #expect(restored == preferences)
        #expect(!migrated)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Audio").path))
    }

    @Test func atomicFailureKeepsOldPreferencesAndDoesNotInventAttempt() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try await LocalRepository(root: root).savePreferences(.defaults)
        let path = root.appendingPathComponent("instrument.json")
        let original = try Data(contentsOf: path)
        let failing = LocalRepository(root: root, writer: AtomicDocumentWriter { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        await #expect(throws: CocoaError.self) { try await failing.savePreferences(InstrumentPreferences(practiceBPM: 90)) }
        #expect(try Data(contentsOf: path) == original)
        await #expect(throws: CocoaError.self) { try await failing.save(record()) }
        #expect(try await LocalRepository(root: root).history().records.isEmpty)
    }

    @Test func corruptAndFutureFilesArePreservedWhileIndexIsRebuilt() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root)
        let attempt = try record(); try await repository.save(attempt)
        let sessions = root.appendingPathComponent("Sessions")
        let corrupt = sessions.appendingPathComponent(UUID().uuidString + ".json")
        let future = sessions.appendingPathComponent(UUID().uuidString + ".json")
        try Data("broken".utf8).write(to: corrupt)
        let futureBytes = Data("{\"schemaVersion\":99,\"payload\":{}}".utf8)
        try futureBytes.write(to: future)
        try Data("broken index".utf8).write(to: root.appendingPathComponent("history-index.json"))
        let history = try await repository.history()
        #expect(history.records == [attempt])
        #expect(Set(history.issues.map(\.reason)) == [.corrupt, .unsupported])
        #expect(try Data(contentsOf: future) == futureBytes)
        #expect(try Data(contentsOf: corrupt) == Data("broken".utf8))
        let index = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("history-index.json"))) as? [String: Any]
        #expect((index?["payload"] as? [[String: Any]])?.count == 1)
    }

    @Test func immutableIdentityIsIdempotentButRejectsNewFacts() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root)
        let attempt = try record(); try await repository.save(attempt)
        try await repository.save(attempt)
        await #expect(throws: StorageError.identifierConflict) { try await repository.save(record(id: attempt.id, bpm: 80)) }
        #expect(try await repository.history().records == [attempt])
    }

    @Test func migrationIsExplicitAndDoesNotRewriteOnRead() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try #require(Bundle.module.url(forResource: "instrument-v1", withExtension: "json", subdirectory: "Fixtures"))
        let bytes = try Data(contentsOf: fixture)
        let path = root.appendingPathComponent("instrument.json"); try bytes.write(to: path)
        let repository = LocalRepository(root: root)
        guard case let .available(value, migrated) = await repository.loadPreferences() else { Issue.record("migration failed"); return }
        #expect(migrated)
        #expect(value.instrument.source == .electricInterface)
        #expect(value.instrument.orientation == .leftHanded)
        #expect(value.practiceBPM == 80)
        #expect(try Data(contentsOf: path) == bytes)
        try await repository.savePreferences(value)
        guard case let .available(roundtrip, migratedAgain) = await repository.loadPreferences() else { Issue.record("reload failed"); return }
        #expect(roundtrip == value)
        #expect(!migratedAgain)
    }

    @Test func unknownPreferencesRequireRecoveryAndRetainOriginal() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let original = Data("{\"schemaVersion\":200,\"payload\":{\"unknown\":true}}".utf8)
        let path = root.appendingPathComponent("instrument.json"); try original.write(to: path)
        let repository = LocalRepository(root: root)
        guard case let .needsRecovery(issue) = await repository.loadPreferences() else { Issue.record("future schema accepted"); return }
        #expect(issue.reason == .unsupported)
        await #expect(throws: StorageError.preferencesNeedRecovery) { try await repository.savePreferences(.defaults) }
        try await repository.restoreDefaultPreferencesPreservingCopy()
        let copies = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Recovery"), includingPropertiesForKeys: nil)
        #expect(copies.count == 1)
        #expect(try Data(contentsOf: copies[0]) == original)
        guard case let .available(value, _) = await repository.loadPreferences() else { Issue.record("recovery failed"); return }
        #expect(value == .defaults)
    }

    @Test func committedAttemptSurvivesIndexFailure() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root, writer: AtomicDocumentWriter { data, url in
            if url.lastPathComponent == "history-index.json" { throw CocoaError(.fileWriteNoPermission) }
            try data.write(to: url, options: .atomic)
        })
        let attempt = try record()
        let warnings = try await repository.save(attempt)
        #expect(warnings.map(\.reason) == [.indexUnavailable])
        #expect(try await LocalRepository(root: root).history().records == [attempt])
    }

    @Test func invalidPayloadCannotBecomeAGrade() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root)
        let attempt = try record(); try await repository.save(attempt)
        let path = root.appendingPathComponent("Sessions/\(attempt.id.uuidString).json")
        var document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        var payload = try #require(document["payload"] as? [String: Any])
        var result = try #require(payload["result"] as? [String: Any])
        var summary = try #require(result["payload"] as? [String: Any])
        summary["overallScore"] = 100 // uncalibrated must never have an overall grade
        result["payload"] = summary; payload["result"] = result; document["payload"] = payload
        try JSONSerialization.data(withJSONObject: document).write(to: path)
        let loaded = try await repository.history()
        #expect(loaded.records.isEmpty)
        #expect(loaded.issues.map(\.reason) == [.corrupt])
    }

    @Test func clearHistoryPreservesInstrumentAndSerializesConcurrentSaves() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root)
        try await repository.savePreferences(.defaults)
        let attempts = try (0..<8).map { _ in try record() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for attempt in attempts { group.addTask { _ = try await repository.save(attempt) } }
            try await group.waitForAll()
        }
        #expect(try await repository.history().records.count == 8)
        try await repository.clearHistory()
        #expect(try await repository.history().records.isEmpty)
        guard case .available = await repository.loadPreferences() else { Issue.record("instrument deleted"); return }
    }

    @Test func realFileSystemFailureIsReported() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("regular-file")
        try Data("keep".utf8).write(to: file)
        let repository = LocalRepository(root: file)
        await #expect(throws: (any Error).self) { try await repository.savePreferences(.defaults) }
        #expect(try Data(contentsOf: file) == Data("keep".utf8))
    }

    @Test func clearDoesNotRecursivelyDeleteAnUnexpectedDirectory() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Sessions/\(UUID().uuidString).json")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: file)
        let repository = LocalRepository(root: root)
        await #expect(throws: StorageError.corruptDocument) { try await repository.clearHistory() }
        #expect(try Data(contentsOf: file) == Data("keep".utf8))
    }

    @Test func futureResultSchemaIsPreservedWithoutReinterpretingIt() async throws {
        let root = try temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root)
        let attempt = try record(); try await repository.save(attempt)
        let path = root.appendingPathComponent("Sessions/\(attempt.id.uuidString).json")
        var document = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        var payload = try #require(document["payload"] as? [String: Any])
        var result = try #require(payload["result"] as? [String: Any])
        result["schemaVersion"] = 999; result["payload"] = ["futureStructure": true]
        payload["result"] = result; document["payload"] = payload
        let bytes = try JSONSerialization.data(withJSONObject: document); try bytes.write(to: path)
        let loaded = try await repository.history()
        #expect(loaded.records.isEmpty)
        #expect(loaded.issues.map(\.reason) == [.unsupported])
        #expect(try Data(contentsOf: path) == bytes)
    }
}
