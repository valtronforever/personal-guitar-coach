import Foundation
import Testing
import Domain
import Learning
import Persistence
@testable import PersonalGuitarCoach

private actor AssessmentRepositoryStub: PracticeRepository {
    var fail = true
    var records: [PracticeRecord] = []
    func history() -> HistoryLoad { HistoryLoad(records: records, issues: []) }
    func save(_ record: PracticeRecord) throws -> [StorageIssue] {
        if fail { throw StorageError.corruptDocument }
        if !records.contains(where: { $0.id == record.id }) { records.append(record) }
        return []
    }
    func clearHistory() { records = [] }
    func allowWrites() { fail = false }
}

@MainActor struct AssessmentStoreTests {
    private func input() throws -> PracticeEvidence {
        let endpoint = try CalibrationEndpoint(uid: "test", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let config = try PracticeConfiguration(exercise: Exercise(id: "store-test", events: [MusicalEvent(id: "first", startTick: 0,
            durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)])]), instrument: InstrumentProfile(), bpm: 60,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test"),
            lesson: PracticeLessonReference(id: "original-lesson", version: 2))
        let time = try config.expectedStart(renderEpochSeconds: 100)
        return try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 10), phase: .completed, reason: nil, signalConfirmed: true,
            renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: [PracticeAttack(id: 1, normalizedOnset: time, frequency: Pitch(midi: 40).frequency(referenceA4: 440), clarity: 0.99, reliable: true)],
            clipping: [], analysisVersion: "fixture-1")
    }
    @Test func failedSaveRetainsExactAttemptAndRetryDoesNotDuplicateOrOverwriteIt() async throws {
        let repository = AssessmentRepositoryStub(), store = AssessmentStore(repository: repository), first = try input()
        #expect(await !store.receive(first))
        #expect(store.needsRetry && store.pending == first && store.errorKey == "assessment.saveFailed")
        #expect(store.latest?.pitchScore == 100 && store.latest?.overallScore == nil)
        #expect(await !store.receive(try input()))
        #expect(store.pending == first)
        await repository.allowWrites()
        #expect(await store.retry())
        #expect(store.pending == nil && store.errorKey == nil)
        #expect(await store.retry())
        let records = await repository.history().records
        #expect(records.count == 1 && records[0].assessment?.payload.evidence == first)
    }
    @Test func fullVersionedInputsRoundTripBesideLegacyHistoryWithoutRegrading() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LocalRepository(root: root), store = AssessmentStore(repository: repository), evidence = try input()
        #expect(await store.receive(evidence))
        let assessment = try #require(store.latest), current = try PracticeRecord(assessment: assessment)
        let legacy = try PracticeRecord(startedAt: evidence.startedAt, finishedAt: evidence.finishedAt,
            exercise: evidence.configuration.exercise, instrument: evidence.configuration.instrument, bpm: 60,
            result: AssessmentSnapshot(algorithmVersion: "old-v1", validity: .uncalibrated, pitchScore: 25,
                expectedCount: 1, matchedCount: 1, missedCount: 0, extraCount: 0))
        try await repository.save(legacy)
        let reopened = LocalRepository(root: root), history = try await reopened.history()
        #expect(history.issues.isEmpty && history.records.count == 2)
        #expect(history.records.contains(current) && history.records.contains(legacy))
        #expect(history.records.first { $0.id == legacy.id }?.result.payload.pitchScore == 25)
        let path = root.appendingPathComponent("Sessions/" + current.id.uuidString + ".json")
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        #expect(json["schemaVersion"] as? Int == 2)
        var payload = try #require(json["payload"] as? [String: Any])
        var detail = try #require(payload["assessment"] as? [String: Any])
        detail["schemaVersion"] = 99; payload["assessment"] = detail; json["payload"] = payload
        let future = try JSONSerialization.data(withJSONObject: json)
        try future.write(to: path)
        let recovered = try await reopened.history()
        #expect(recovered.records == [legacy] && recovered.issues.first?.reason == .unsupported)
        #expect(try Data(contentsOf: path) == future)
        await #expect(throws: StorageError.unsupportedVersion(99)) { try await reopened.save(current) }
        #expect(try Data(contentsOf: path) == future)
    }
    @Test func syntheticPresentationCasesHaveExplicitValidityAndNeverStoreHistory() throws {
        for validity in [AssessmentValidity.valid, .uncalibrated, .insufficientSignal, .interrupted] {
            let result = try AssessmentFixtureView.result(validity.rawValue)
            #expect(result.validity == validity)
            #expect((result.overallScore != nil) == (validity == .valid))
            #expect(result.evidence.analysisVersion == "synthetic-fixture")
        }
    }

}
