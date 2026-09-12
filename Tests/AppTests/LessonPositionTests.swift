import Foundation
import Testing
import Domain
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct LessonPositionIntegrationTests {
    private func library() async -> LessonLibraryStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonLibraryStore(directory: root.appendingPathComponent("Resources/Lessons"))
        await library.load(); return library
    }
    @Test func positionUpdatesBoardTabAndTextWithoutChangingStepOrStaffPitches() async throws {
        let source = try #require(await library().sourceLesson(id: "c-major"))
        let selection = LessonSelection(lesson: source, tuning: .cStandard)
        selection.selectStep("lower-half")
        selection.selectEvent("up-2", exerciseID: "c-major-practice", extending: true)
        let before = try #require(selection.exercise), ids = selection.selectedIDs, step = selection.stepID
        let seventh = try LessonPosition(firstFret: 7)
        selection.selectPosition(seventh, instrument: InstrumentProfile(tuning: .cStandard))
        let after = try #require(selection.exercise)
        #expect(selection.position == seventh && selection.stepID == step && selection.selectedIDs == ids)
        #expect(after.events != before.events)
        let board = selection.fretboard(instrument: InstrumentProfile(tuning: .cStandard))
        #expect(!board.expected.isEmpty)
        #expect(board.expected.allSatisfy { seventh.contains($0, maximumFret: 24) })
        let oldTimeline = try TimelineModel(exercise: before, instrument: .cStandard)
        let newTimeline = try TimelineModel(exercise: after, instrument: .cStandard)
        #expect(try StaffModel(timeline: oldTimeline, key: .neutral).symbols(in: 0).compactMap(\.pitch) == StaffModel(timeline: newTimeline, key: .neutral).symbols(in: 0).compactMap(\.pitch))
        selection.adapt(to: .dropBFlat, frets: .nineteen)
        #expect(selection.position == seventh && selection.adaptationFailed && selection.exercise == nil)
        #expect(!selection.availablePositions.contains(seventh))
        selection.selectPosition(try LessonPosition(firstFret: 3), instrument: InstrumentProfile(tuning: .dropBFlat, frets: .nineteen))
        #expect(!selection.adaptationFailed && selection.selectedIDs == ids)
        selection.selectPosition(nil, instrument: InstrumentProfile(tuning: .cStandard))
        #expect(selection.exercise == before && selection.position == nil)
    }
    @Test func diskBookmarksRestorePositionAndReadProgressAndDecodeOldDocuments() async throws {
        let source = try #require(await library().sourceLesson(id: "c-major"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory), store = ReadingProgressStore(repository: LocalRepository(root: directory))
        await store.load()
        let version = try #require(source.manifest.adaptation?.lessonVersion), seventh = try LessonPosition(firstFret: 7)
        store.visit(lessonID: source.id, version: version, stepID: "upper-half", position: seventh)
        store.setRead(true, lessonID: source.id, version: version, stepID: "upper-half", position: seventh)
        await store.flush()
        let bookmark = try #require(await repository.loadReadingProgress().lessons[source.id])
        let restored = LessonSelection(lesson: source, bookmark: bookmark, tuning: .cStandard, frets: .nineteen)
        #expect(restored.position == seventh && restored.stepID == "upper-half" && !restored.adaptationFailed)
        #expect(bookmark.readVersion == version)
        let drop = LessonSelection(lesson: source, bookmark: bookmark, tuning: .dropBFlat)
        #expect(drop.position == seventh && drop.adaptationFailed && drop.stepID == "upper-half")
        var outdated = bookmark; outdated.lessonVersion = 1
        #expect(LessonSelection(lesson: source, bookmark: outdated, tuning: .cStandard).position == nil)
        let legacy = try JSONDecoder().decode(LessonBookmark.self, from: Data(#"{"lessonVersion":2,"stepID":"upper-half","readVersion":2}"#.utf8))
        #expect(legacy.position == nil)
        store.visit(lessonID: source.id, version: version, stepID: "upper-half", position: nil)
        await store.flush()
        let reset = try #require(await repository.loadReadingProgress().lessons[source.id])
        #expect(reset.position == nil && reset.readVersion == version)
    }
    @Test func practiceRefreshKeepsChosenRegionAndArchiveRetryFreezesItsExactFingering() async throws {
        let library = await library(), source = try #require(library.sourceLesson(id: "c-major"))
        let seventh = try LessonPosition(firstFret: 7), instrument = InstrumentProfile(tuning: .cStandard, frets: .nineteen)
        let lesson = try source.adapted(to: instrument, position: seventh)
        let request = try #require(PracticeRequest(lesson: lesson, exerciseID: "c-major-practice", adaptsWithInstrument: true, frets: instrument.frets, position: seventh))
        let navigation = AppNavigation(); navigation.openPractice(request)
        #expect(request.freshSelection().position == seventh)
        navigation.refreshPractice(instrument: InstrumentProfile(tuning: .dStandard), lessons: library.lessons)
        #expect(navigation.practiceRequest?.position == seventh && navigation.practiceRequest?.exercise.requiredTuning == .dStandard)
        navigation.refreshPractice(instrument: InstrumentProfile(tuning: .dropC), lessons: library.lessons)
        #expect(navigation.practiceAdaptationFailed && navigation.practiceRequest?.position == seventh)
        navigation.refreshPractice(instrument: instrument, lessons: library.lessons)
        #expect(!navigation.practiceAdaptationFailed && navigation.practiceRequest?.exercise == request.exercise)
        let endpoint = try CalibrationEndpoint(uid: "position-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "position-test-1")
        let config = try PracticeConfiguration(exercise: request.exercise, instrument: instrument, bpm: request.exercise.defaultBPM,
            route: route, lesson: PracticeLessonReference(id: source.id, version: lesson.manifest.version, position: seventh))
        let wrongExercise = try source.adapted(to: instrument).manifest.exercises[0]
        #expect(throws: MusicError.invalidFret) {
            try PracticeConfiguration(exercise: wrongExercise, instrument: instrument, bpm: wrongExercise.defaultBPM,
                route: route, lesson: PracticeLessonReference(id: source.id, version: lesson.manifest.version, position: seventh))
        }
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 60), phase: .completed, reason: nil, signalConfirmed: true,
            renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: [], clipping: [], analysisVersion: "synthetic-events")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory), store = AssessmentStore(repository: LocalRepository(root: directory))
        #expect(await store.receive(evidence))
        let record = try #require(await repository.history().records.first)
        let archived = try #require(record.assessment?.payload)
        #expect(archived.evidence.configuration.lesson?.position == seventh && archived.evidence.configuration == config)
        let recommendation = try #require(FeedbackEngine.recommendations(for: archived).first { $0.kind == .missed })
        let retry = try #require(PracticeRequest(result: archived, recommendation: recommendation))
        #expect(retry.position == seventh && retry.exercise == request.exercise && retry.archivedTuning == .cStandard)
        navigation.openPractice(retry)
        navigation.refreshPractice(instrument: InstrumentProfile(tuning: .dropD), lessons: library.lessons)
        #expect(navigation.practiceRequest == retry && !navigation.practiceAdaptationFailed)
        let legacyReference = try JSONDecoder().decode(PracticeLessonReference.self, from: Data(#"{"id":"c-major","version":2}"#.utf8))
        #expect(legacyReference.position == nil)
    }
}
