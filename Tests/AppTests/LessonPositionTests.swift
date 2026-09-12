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
        let seventh = PositionChoice.region(firstFret: 7)
        selection.selectChoice(seventh)
        let after = try #require(selection.exercise)
        #expect(selection.choice == seventh && selection.stepID == step && selection.selectedIDs == ids)
        #expect(after.events != before.events)
        let board = selection.fretboard(instrument: InstrumentProfile(tuning: .cStandard))
        #expect(!board.expected.isEmpty)
        #expect(board.expected.allSatisfy { (7...11).contains($0.fret) })
        let oldTimeline = try TimelineModel(exercise: before, instrument: .cStandard)
        let newTimeline = try TimelineModel(exercise: after, instrument: .cStandard)
        #expect(try StaffModel(timeline: oldTimeline, key: .neutral).symbols(in: 0).compactMap(\.pitch) == StaffModel(timeline: newTimeline, key: .neutral).symbols(in: 0).compactMap(\.pitch))
        selection.updateInstrument(InstrumentProfile(tuning: .dropBFlat, frets: .nineteen))
        #expect(selection.choice == seventh && selection.failure != nil && selection.exercise == nil)
        #expect(!selection.availableChoices.contains(seventh))
        selection.selectChoice(.region(firstFret: 3))
        #expect(selection.failure == nil && selection.selectedIDs == ids)
        selection.updateInstrument(InstrumentProfile(tuning: .cStandard)); selection.selectChoice(.original)
        #expect(selection.exercise == before && selection.choice == .original)
    }
    @Test func diskBookmarksRestorePositionAndReadProgressAndDecodeOldDocuments() async throws {
        let source = try #require(await library().sourceLesson(id: "c-major"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory), store = ReadingProgressStore(repository: LocalRepository(root: directory))
        await store.load()
        let version = source.manifest.version, seventh = PositionChoice.region(firstFret: 7)
        store.visit(lessonID: source.id, version: version, stepID: "upper-half", activityChoices: ["lesson": seventh])
        store.setRead(true, lessonID: source.id, version: version, stepID: "upper-half", activityChoices: ["lesson": seventh])
        await store.flush()
        let bookmark = try #require(await repository.loadReadingProgress().lessons[source.id])
        let restored = LessonSelection(lesson: source, bookmark: bookmark, tuning: .cStandard, frets: .nineteen)
        #expect(restored.choice == seventh && restored.stepID == "upper-half" && restored.failure == nil)
        #expect(bookmark.readVersion == version)
        let drop = LessonSelection(lesson: source, bookmark: bookmark, tuning: .dropBFlat)
        #expect(drop.choice == seventh && drop.failure != nil && drop.stepID == "upper-half")
        var outdated = bookmark; outdated.lessonVersion = 1
        #expect(LessonSelection(lesson: source, bookmark: outdated, tuning: .cStandard).choice == .original)
        let legacy = try JSONDecoder().decode(LessonBookmark.self, from: Data(#"{"lessonVersion":2,"stepID":"upper-half","readVersion":2}"#.utf8))
        #expect(legacy.activityChoices.isEmpty)
        store.visit(lessonID: source.id, version: version, stepID: "upper-half", activityChoices: [:])
        await store.flush()
        let reset = try #require(await repository.loadReadingProgress().lessons[source.id])
        #expect(reset.activityChoices.isEmpty && reset.readVersion == version)
    }
    @Test func practiceRefreshKeepsChosenRegionAndArchiveRetryFreezesItsExactFingering() async throws {
        let library = await library(), source = try #require(library.sourceLesson(id: "c-major"))
        let seventh = PositionChoice.region(firstFret: 7), instrument = InstrumentProfile(tuning: .cStandard, frets: .nineteen)
        let lesson = try source.resolveActivity(id: "lesson", instrument: instrument, choice: seventh)
        let request = try #require(PracticeRequest(lesson: source, snapshot: lesson, entryID: "c-major-practice"))
        let navigation = AppNavigation(); navigation.openPractice(request)
        #expect(request.freshSelection().activityReference?.choice == seventh)
        navigation.refreshPractice(instrument: InstrumentProfile(tuning: .dStandard), lessons: library.lessons)
        #expect(navigation.practiceRequest?.activityReference?.choice == seventh && navigation.practiceRequest?.exercise.requiredTuning == .dStandard)
        navigation.refreshPractice(instrument: InstrumentProfile(tuning: .dropC), lessons: library.lessons)
        #expect(navigation.practiceAdaptationFailed && navigation.practiceRequest?.activityReference?.choice == seventh)
        navigation.refreshPractice(instrument: instrument, lessons: library.lessons)
        #expect(!navigation.practiceAdaptationFailed && navigation.practiceRequest?.exercise == request.exercise)
        let endpoint = try CalibrationEndpoint(uid: "position-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "position-test-1")
        let config = try PracticeConfiguration(exercise: request.exercise, instrument: instrument, bpm: request.exercise.defaultBPM,
            route: route, lesson: PracticeLessonReference(id: source.id, version: lesson.lessonVersion, activity: request.activityReference))
        let wrongExercise = try source.resolveActivity(id: "lesson", instrument: instrument).exercises[0]
        #expect(throws: PracticeError.invalidEvidence) {
            try PracticeConfiguration(exercise: wrongExercise, instrument: instrument, bpm: wrongExercise.defaultBPM,
                route: route, lesson: PracticeLessonReference(id: source.id, version: lesson.lessonVersion, activity: request.activityReference))
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
        #expect(archived.evidence.configuration.lesson?.activity?.choice == seventh && archived.evidence.configuration == config)
        let recommendation = try #require(FeedbackEngine.recommendations(for: archived).first { $0.kind == .missed })
        let retry = try #require(PracticeRequest(result: archived, recommendation: recommendation))
        #expect(retry.activityReference?.choice == seventh && retry.exercise == request.exercise && retry.archivedTuning == .cStandard)
        navigation.openPractice(retry)
        navigation.refreshPractice(instrument: InstrumentProfile(tuning: .dropD), lessons: library.lessons)
        #expect(navigation.practiceRequest == retry && !navigation.practiceAdaptationFailed)
        let legacyReference = try JSONDecoder().decode(PracticeLessonReference.self, from: Data(#"{"id":"c-major","version":2}"#.utf8))
        #expect(legacyReference.position == nil)
    }
}

@MainActor struct ActivityWorkflowTests {
    private func demo() throws -> LoadedLesson {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try #require(LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons.first { $0.id == "same-notes-new-position" })
    }
    @Test func overlappingActivitiesKeepIndependentChoicesConfirmationsAndBookmarks() throws {
        let lesson = try demo(), instrument = InstrumentProfile(tuning: .cStandard, frets: .nineteen)
        let selection = LessonSelection(lesson: lesson, tuning: instrument.tuning, frets: instrument.frets)
        selection.selectStep("explore-scale"); selection.selectChoice(.region(firstFret: 7)); selection.setSelfConfirmed(true)
        let exploration = try #require(selection.snapshot), previewID = selection.previewContextID
        #expect(selection.selfConfirmed)
        selection.selectStep("play-original")
        #expect(selection.choice == .original && !selection.canChoosePosition && !selection.selfConfirmed)
        #expect(selection.previewContextID != previewID && selection.snapshot?.exercises != exploration.exercises)
        selection.selectChoice(.region(firstFret: 7))
        #expect(selection.choice == .original)
        selection.selectStep("play-seven")
        #expect(selection.choice == .region(firstFret: 7) && selection.snapshot?.exercises == exploration.exercises)
        #expect(!selection.selfConfirmed)
        selection.selectStep("explore-scale")
        #expect(selection.snapshot == exploration && selection.selfConfirmed)
        selection.selectStep("hear-note"); selection.selectChoice(.region(firstFret: 12))
        #expect(selection.exercise?.events.map(\.id) == ["up-5"] && selection.exercise?.events.first?.startTick == 0)
        let bookmark = LessonBookmark(lessonVersion: lesson.manifest.version, stepID: selection.stepID,
            activityChoices: selection.activityChoices, activityConfirmations: selection.activityConfirmations)
        let restored = LessonSelection(lesson: lesson, bookmark: try JSONDecoder().decode(LessonBookmark.self, from: JSONEncoder().encode(bookmark)), tuning: .cStandard, frets: .nineteen)
        #expect(restored.choice == .region(firstFret: 12))
        restored.selectStep("explore-scale")
        #expect(restored.choice == .region(firstFret: 7) && restored.selfConfirmed)
        restored.updateInstrument(InstrumentProfile(tuning: .dropBFlat, frets: .nineteen))
        #expect(!restored.selfConfirmed && restored.failure == nil) // Width six includes Drop's twelfth fret.
        restored.selectStep("reflect")
        #expect(restored.exercise == nil && restored.snapshot == nil && restored.practiceEntries.isEmpty)
    }
    @Test func identicalPitchesInDifferentActivitiesNeverBecomeComparableAttempts() throws {
        let lesson = try demo(), instrument = InstrumentProfile(tuning: .cStandard)
        let endpoint = try CalibrationEndpoint(uid: "comparison-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        func assessment(_ activity: String, confirmed: Bool = false) throws -> AssessedPractice {
            let snapshot = try lesson.resolveActivity(id: activity, instrument: instrument, choice: .region(firstFret: 7))
            let request = try #require(PracticeRequest(lesson: lesson, snapshot: snapshot, entryID: activity + "-practice",
                selfConfirmation: confirmed ? PositionSelfConfirmation(choice: snapshot.choice, tuning: .cStandard, frets: .twentyFour) : nil))
            let config = try PracticeConfiguration(exercise: request.exercise, instrument: instrument, bpm: 60, route: route,
                lesson: PracticeLessonReference(id: request.lessonID, version: request.lessonVersion, activity: request.activityReference))
            return try AssessmentEngine.evaluate(PracticeEvidence(id: UUID(), configuration: config,
                startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 60), phase: .completed, reason: nil,
                signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: [], clipping: [], analysisVersion: "fixture"))
        }
        let exploring = try assessment("explore"), fixed = try assessment("seven"), reported = try assessment("explore", confirmed: true)
        #expect(exploring.evidence.configuration.exercise == fixed.evidence.configuration.exercise)
        #expect(!PracticeComparison.compatible(exploring, fixed))
        #expect(PracticeComparison.compatible(exploring, reported) && exploring.pitchScore == reported.pitchScore)
    }
    @Test func invalidSavedChoiceIsExplicitAndCannotPoisonOtherActivities() throws {
        let lesson = try demo()
        let bookmark = LessonBookmark(lessonVersion: lesson.manifest.version, stepID: "explore-scale", activityChoices: ["explore": .region(firstFret: 24)])
        let selection = LessonSelection(lesson: lesson, bookmark: bookmark, tuning: .cStandard, frets: .nineteen)
        #expect(selection.failure == .forbiddenChoice && selection.snapshot == nil && selection.choice == .region(firstFret: 24))
        #expect(selection.text(stepID: "play-seven", language: .uk)?.body.contains("{{") == false)
        selection.selectStep("play-seven")
        #expect(selection.failure == nil && selection.exercise != nil)
        selection.selectStep("explore-scale"); selection.selectChoice(.region(firstFret: 7))
        #expect(selection.failure == nil)
    }
    @Test func fragmentAttemptFreezesSourceOffsetAndRetriesWithoutLiveContentOrSelfReport() throws {
        let lesson = try demo(), instrument = InstrumentProfile(tuning: .cStandard, frets: .nineteen)
        let snapshot = try lesson.resolveActivity(id: "note", instrument: instrument, choice: .region(firstFret: 12))
        let confirmation = PositionSelfConfirmation(choice: snapshot.choice, tuning: .cStandard, frets: .nineteen)
        let request = try #require(PracticeRequest(lesson: lesson, snapshot: snapshot, entryID: "note-practice", selfConfirmation: confirmation))
        let endpoint = try CalibrationEndpoint(uid: "fragment-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let config = try PracticeConfiguration(exercise: request.exercise, instrument: instrument, bpm: 60,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture"),
            lesson: PracticeLessonReference(id: request.lessonID, version: request.lessonVersion, activity: request.activityReference))
        #expect(config.range == 0..<960 && config.lesson?.activity?.source.startTick == 3840)
        #expect(config.lesson?.activity?.source.eventIDs == ["up-5"] && config.lesson?.activity?.selfConfirmation == confirmation)
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 60),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: [], clipping: [], analysisVersion: "fixture")
        let assessment = try AssessmentEngine.evaluate(evidence)
        let archived = try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(assessment))
        let advice = try #require(FeedbackEngine.recommendations(for: archived).first { $0.action == .repeatFragment })
        #expect(advice.eventIDs == ["up-5"])
        let retry = try #require(PracticeRequest(result: archived, recommendation: advice))
        #expect(retry.exercise == request.exercise && retry.initialRange == 0..<960 && retry.activityReference?.selfConfirmation == nil)
        #expect(retry.activityReference?.hasSameConditions(as: request.activityReference!) == true)
        let navigation = AppNavigation(); navigation.openPractice(retry)
        navigation.refreshPractice(instrument: InstrumentProfile(tuning: .dropD), lessons: [])
        #expect(navigation.practiceRequest == retry && !navigation.practiceAdaptationFailed)
        #expect(retry.activityReference?.activityTitles["uk"]?.contains("{{") == false)
        // Reading legacy evidence is independent of the new-only lesson API.
        let legacy = try JSONDecoder().decode(PracticeLessonReference.self, from: Data(#"{"id":"c-major","version":2,"position":{"firstFret":7}}"#.utf8))
        #expect(legacy.activity == nil && legacy.position?.firstFret == 7)
    }
}
