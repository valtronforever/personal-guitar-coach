import Foundation
import Testing
import Domain
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct AutomaticLessonTuningTests {
    private func library() async -> LessonLibraryStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonLibraryStore(directory: root.appendingPathComponent("Resources/Lessons"))
        await library.load(); return library
    }
    @Test func oneCatalogAndLegacyBookmarksReachTheSameAdaptiveCourse() async throws {
        let library = await library()
        #expect(library.catalogLessons.count == 6 && library.lessons.count == 12)
        #expect(library.sourceLesson(id: "ab-major-c-standard")?.id == "c-major")
        let source = try #require(library.sourceLesson(id: "c-major"))
        let selection = LessonSelection(lesson: source, tuning: .standard)
        selection.selectStep("lower-half")
        selection.selectEvent("up-2", exerciseID: "c-major-practice", extending: true)
        let ids = selection.selectedIDs, step = selection.stepID
        selection.adapt(to: .cStandard)
        #expect(!selection.adaptationFailed && selection.selectedIDs == ids && selection.stepID == step)
        #expect(selection.lesson.english.title == "A♭ major across the strings")
        let board = selection.fretboard(instrument: InstrumentProfile(tuning: .cStandard))
        #expect(board.tuning == .cStandard)
        let exercise = try #require(selection.exercise), timeline = try TimelineModel(exercise: exercise, instrument: .standard)
        #expect(try StaffModel(timeline: timeline, key: .neutral).symbols(in: 0).compactMap(\.pitch).map(\.name) == ["A♭3", "B♭3", "C4", "D♭4"])
        let bookmark = LessonBookmark(lessonVersion: selection.lesson.manifest.version, stepID: step, readVersion: nil)
        let restored = LessonSelection(lesson: source, bookmark: bookmark, tuning: .dropD)
        #expect(restored.stepID == step && restored.lesson.english.title == "C major across the strings")
    }
    @Test func everyPresetLessonCanBeAssessedSavedAndRetriedWithoutRetuningItsHistory() async throws {
        let library = await library()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory), store = AssessmentStore(repository: repository)
        for tuning in TuningProfile.presets {
            for source in library.catalogLessons {
                let lesson = try source.adapted(to: tuning)
                let exerciseID = try #require(lesson.manifest.practiceExerciseIDs.first)
                let request = try #require(PracticeRequest(lesson: lesson, exerciseID: exerciseID, adaptsWithInstrument: true))
                let endpoint = try CalibrationEndpoint(uid: "adaptive-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512)
                let config = try PracticeConfiguration(exercise: request.exercise, instrument: InstrumentProfile(tuning: tuning), bpm: request.exercise.defaultBPM,
                    route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "adaptive-test-1"),
                    lesson: PracticeLessonReference(id: lesson.id, version: lesson.manifest.version))
                let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
                    finishedAt: Date(timeIntervalSince1970: 60), phase: .completed, reason: nil, signalConfirmed: true,
                    renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: [], clipping: [], analysisVersion: "synthetic-events")
                #expect(await store.receive(evidence))
                let result = try #require(store.latest)
                #expect(result.validity == .uncalibrated && result.pitchScore == 0 && result.overallScore == nil)
                let recommendation = try #require(FeedbackEngine.recommendations(for: result).first { $0.kind == .missed })
                let retry = try #require(PracticeRequest(result: result, recommendation: recommendation))
                let navigation = AppNavigation(); navigation.openPractice(retry)
                navigation.refreshPractice(tuning: .dropD, lessons: library.lessons)
                #expect(navigation.practiceRequest == retry && retry.archivedTuning == tuning && !retry.adaptsWithInstrument)
                for language in [LessonLanguage.en, .uk] {
                    #expect(ResultPresentation.lessonTitle(id: lesson.id, version: lesson.manifest.version, tuning: tuning,
                        lessons: library.lessons, language: language) == lesson.text(for: language).title)
                }
            }
        }
        let data = LocalDataStore(repository: repository); await data.reload()
        #expect(data.records.count == 24 && data.historyIssues.isEmpty)
        #expect(data.records.allSatisfy { ResultPresentation.title(record: $0, lessons: library.lessons, language: .uk) != nil })
    }
    @Test func freshPracticeRetunesAndUnplayableTuningRecoversWithoutChangingArchivedRequests() async throws {
        let library = await library(), navigation = AppNavigation()
        let source = try #require(library.sourceLesson(id: "em-arpeggio"))
        let lesson = try source.adapted(to: .standard)
        navigation.openPractice(try #require(PracticeRequest(lesson: lesson, exerciseID: "em-arpeggio-practice", adaptsWithInstrument: true)))
        let old = navigation.practiceRequest
        navigation.refreshPractice(tuning: .dropD, lessons: library.lessons)
        #expect(navigation.practiceRequest != old && navigation.practiceRequest?.exercise.requiredTuning == .dropD)
        #expect(navigation.practiceRequest?.exercise.events.first?.positions.first?.fret == 2)
        let impossible = try TuningProfile(id: "extreme", name: "Extreme", strings: (1...6).map { try TunedString(number: $0, openPitch: Pitch(midi: $0 == 1 ? 100 : 0)) })
        navigation.refreshPractice(tuning: impossible, lessons: library.lessons)
        #expect(navigation.practiceAdaptationFailed)
        navigation.refreshPractice(tuning: .cStandard, lessons: library.lessons)
        #expect(!navigation.practiceAdaptationFailed && navigation.practiceRequest?.exercise.requiredTuning == .cStandard)
        let selection = LessonSelection(lesson: source, tuning: .standard); selection.selectStep("top-and-turn")
        selection.adapt(to: impossible)
        #expect(selection.adaptationFailed && selection.exercise == nil)
        #expect(selection.fretboard(instrument: InstrumentProfile(tuning: impossible)).expected.isEmpty)
        selection.adapt(to: .cStandard)
        #expect(!selection.adaptationFailed && selection.stepID == "top-and-turn")
    }
}
