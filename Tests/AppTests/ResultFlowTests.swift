import Foundation
import Testing
import Domain
import Learning
import Persistence
import Audio
@testable import PersonalGuitarCoach

@MainActor struct ResultFlowTests {
    private func lesson() throws -> LoadedLesson {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try #require(LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons.first)
    }
    private func result(tuning: TuningProfile = .standard) throws -> AssessedPractice {
        let lesson = try lesson()
        var events: [MusicalEvent] = []
        for index in 0..<24 {
            events.append(try MusicalEvent(id: "saved-\(index)", startTick: Int64(index) * 960, durationTicks: 960,
                kind: .note, positions: [FretPosition(string: 6, fret: index % 4)]))
        }
        let exercise = try Exercise(id: "archived-exercise", version: 3, events: events)
        let endpoint = try CalibrationEndpoint(uid: "result-flow-stub", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let config = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(tuning: tuning), bpm: 80,
            range: 3840..<23040, route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture"),
            lesson: PracticeLessonReference(id: lesson.id, version: lesson.manifest.version))
        let start = try config.expectedStart(renderEpochSeconds: 100)
        var attacks: [PracticeAttack] = []
        for event in config.selectedEvents where event.id != "saved-20" && event.id != "saved-21" {
            let time = start + Double(event.startTick - config.range.lowerBound) / 960 * 60 / config.bpm
            attacks.append(try PracticeAttack(id: UInt64(attacks.count + 1), normalizedOnset: time,
                frequency: tuning.frequency(at: event.positions[0]), clarity: 0.99, reliable: true))
        }
        return try AssessmentEngine.evaluate(PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 60), phase: .completed, reason: nil, signalConfirmed: true,
            renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: attacks, clipping: [], analysisVersion: "fixture-1"))
    }
    @Test func RetryPreservesArchivedExerciseFragmentAndStartsIdleWithNewSelection() throws {
        let result = try result(tuning: .dropD)
        let advice = try #require(FeedbackEngine.recommendations(for: result).first { $0.kind == .missed })
        let first = try #require(PracticeRequest(result: result, recommendation: advice))
        let second = first.freshSelection()
        #expect(first != second && first.exercise == result.evidence.configuration.exercise)
        #expect(first.lessonID == result.evidence.configuration.lesson?.id && first.initialBPM == 65)
        let audio = AudioSessionStore(repository: nil), model = PracticeModel(audio: audio, calibration: CalibrationStore(repository: nil))
        let navigation = AppNavigation(); navigation.openPractice(first); model.configure(navigation.practiceRequest)
        #expect(navigation.destination == .practice && model.phase == .idle && !model.isBusy && !model.physicallyTuned)
        #expect(model.firstBar == advice.firstBar && model.lastBar == advice.lastBar && model.bpm == 65)
        #expect(model.selectedEventIDs.contains("saved-20") && model.selectedEventIDs.contains("saved-21"))
        #expect(throws: MusicError.tuningMismatch) { try first.retryInstrument(from: InstrumentProfile()) }
        model.physicallyTuned = true; model.start(instrument: InstrumentProfile())
        #expect(model.errorKey == "result.retryTuningMismatch" && !model.isBusy && !model.physicallyTuned)
        let target = try first.retryInstrument(from: InstrumentProfile(tuning: .dropD, orientation: .leftHanded, source: .acousticPickup))
        #expect(target.tuning == .dropD && target.source == .acousticPickup && target.orientation == .leftHanded)
        model.physicallyTuned = true; model.setRepeat(true); model.configure(second)
        #expect(!model.physicallyTuned && !model.repeatEnabled && model.phase == .idle)
        let other = try self.result()
        #expect(PracticeRequest(result: other, recommendation: advice) == nil)
    }
    @Test func ArchivedPitchRestorationPreservesNewerCustomProfileAndA4() async throws {
        let old = try TuningProfile(id: "custom", revision: 2, name: "Practice tuning", strings: TuningProfile.standard.strings, referenceA4: 432)
        let newer = try old.revised(name: "Changed tuning", strings: TuningProfile.dropD.strings, referenceA4: 440)
        let preferences = try InstrumentPreferences(instrument: InstrumentProfile(tuning: newer), customTunings: [newer])
        let restored = try preferences.restoringPitches(from: old)
        #expect(restored.customTunings.contains(newer) && restored.customTunings.count == 2)
        #expect(restored.instrument.tuning.id != old.id && restored.instrument.tuning.hasSamePitches(as: old))
        #expect(try restored.restoringPitches(from: old) == restored)
        let report = try result(tuning: old), advice = try #require(FeedbackEngine.recommendations(for: report).first { $0.action == .repeatFragment })
        let request = try #require(PracticeRequest(result: report, recommendation: advice))
        #expect(throws: MusicError.tuningMismatch) { try request.retryInstrument(from: InstrumentProfile()) }
        #expect(try request.retryInstrument(from: restored.instrument).tuning == old)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory); try await repository.savePreferences(preferences)
        let store = LocalDataStore(repository: repository); await store.reload(); await store.restoreArchivedTuning(old)
        #expect(store.operationError == nil && store.preferences.customTunings.contains(newer))
        #expect(store.preferences.instrument.tuning.hasSamePitches(as: old))
    }
    @Test func HistoryReloadAndLanguageDoNotChangeStoredResultOrInventLegacyEvidence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory), report = try result(), record = try PracticeRecord(assessment: report)
        try await repository.save(record)
        let store = LocalDataStore(repository: repository); await store.reload()
        let reloaded = try #require(store.records.first)
        #expect(reloaded.assessment?.payload == report)
        let en = ResultPresentation.title(record: reloaded, lessons: [try lesson()], language: .en)
        let uk = ResultPresentation.title(record: reloaded, lessons: [try lesson()], language: .uk)
        #expect(en != nil && uk != nil && en != uk && store.records.first == reloaded)
        #expect(ResultPresentation.title(record: reloaded, lessons: [], language: .en) == nil)
        let legacy = try PracticeRecord(startedAt: record.startedAt, finishedAt: record.finishedAt, exercise: record.exercise,
            instrument: record.instrument, bpm: record.bpm, startTick: record.startTick, endTick: record.endTick, result: record.result.payload)
        let loadedLesson = try lesson()
        #expect(legacy.assessment == nil && ResultPresentation.title(record: legacy, lessons: [loadedLesson], language: .uk) == nil)
        await store.clearHistory()
        #expect(store.records.isEmpty)
    }
    @Test func AnnotationsDistinguishUncertainMissingAndMatchedWithoutJudgingPartialPlaying() throws {
        let report = try result(), marks = ResultPresentation.annotations(report)
        #expect(marks["saved-20"] == .missing && marks["saved-4"] == .matched && marks["saved-0"] == nil)
        for state in ["valid", "uncalibrated", "insufficientSignal", "interrupted"] {
            let value = try AssessmentFixtureView.result(state), annotations = ResultPresentation.annotations(value)
            #expect(annotations.count == 8)
            if state == "insufficientSignal" { #expect(annotations.values.allSatisfy { $0 == .uncertain }) }
            if state == "interrupted" { #expect(annotations.values.allSatisfy { $0 == .matched }) }
            if state == "uncalibrated" { #expect(!annotations.values.contains(.early) && !annotations.values.contains(.late)) }
        }
    }
}
