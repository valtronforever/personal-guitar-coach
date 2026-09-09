import Foundation
import Testing
import Domain
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct LessonSelectionTests {
    private func lesson() throws -> LoadedLesson {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("test-lesson")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func write<T: Encodable>(_ value: T, _ path: URL) throws { try JSONEncoder().encode(value).write(to: path) }
        let events = try [MusicalEvent(id: "low", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)]),
            MusicalEvent(id: "rest", startTick: 960, durationTicks: 960, kind: .rest),
            MusicalEvent(id: "high", startTick: 1920, durationTicks: 960, kind: .note, positions: [FretPosition(string: 1, fret: 0)])]
        let fixed = try Exercise(id: "fixed", events: events, tuningPolicy: .fixedTuning, requiredTuning: .standard)
        let follows = try Exercise(id: "follows", events: events)
        let shape = try Fingering(positions: [FretPosition(string: 1, fret: 0), FretPosition(string: 4, fret: 2)], mutedStrings: [6], fingerNumbers: [4: 2])
        let display = try Exercise(id: "display", events: [MusicalEvent(id: "chord", startTick: 0, durationTicks: 960, kind: .note, positions: shape.positions)], assessmentMode: .displayOnly)
        let steps = [LessonStep(id: "intro", kind: .none),
            LessonStep(id: "single", kind: .events, exerciseID: "fixed", eventIDs: ["low"]),
            LessonStep(id: "group", kind: .events, exerciseID: "fixed", eventIDs: ["low", "high"]),
            LessonStep(id: "rest-step", kind: .events, exerciseID: "fixed", eventIDs: ["rest"]),
            LessonStep(id: "alternative", kind: .events, exerciseID: "follows", eventIDs: ["low"]),
            LessonStep(id: "shape", kind: .fingering, exerciseID: "display", fingering: shape)]
        try write(LessonCatalogManifest(lessons: ["test-lesson"]), root.appendingPathComponent("catalog.json"))
        try write(LessonManifest(id: "test-lesson", steps: steps, exercises: [fixed, follows, display], practiceExerciseIDs: ["fixed", "follows"]), directory.appendingPathComponent("lesson.json"))
        for locale in ["en", "uk"] {
            try write(LessonText(lessonID: "test-lesson", locale: locale, title: locale == "uk" ? "Відкриті струни" : "Open strings", summary: "Summary", goal: "Goal", body: "Body",
                steps: Dictionary(uniqueKeysWithValues: steps.map { ($0.id, LessonStepText(title: $0.id, body: "Text")) })), directory.appendingPathComponent("\(locale).json"))
        }
        let report = LessonCatalogLoader().load(directory: root)
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first)
    }

    @Test func eventSelectionKeepsMatchingStepOtherwiseChoosesFirstAndScopesIDs() throws {
        let state = LessonSelection(lesson: try lesson())
        state.selectStep("group")
        state.selectEvent("low", exerciseID: "fixed", extending: false)
        #expect(state.stepID == "group" && state.selectedIDs == ["low"])
        state.selectStep("intro")
        state.selectEvent("low", exerciseID: "fixed", extending: false)
        #expect(state.stepID == "single")
        state.selectEvent("low", exerciseID: "follows", extending: false)
        #expect(state.stepID == "alternative" && state.exerciseID == "follows")
        state.selectEvent("unknown", exerciseID: "fixed", extending: false)
        #expect(state.stepID == "alternative" && state.exerciseID == "follows")
    }

    @Test func explicitStepRestoresFullSelectionAndRestOrTextClearStaleMarkers() throws {
        let state = LessonSelection(lesson: try lesson())
        state.selectStep("group")
        #expect(state.selectedIDs == ["low", "high"])
        state.selectEvent("high", exerciseID: "fixed", extending: true)
        #expect(state.selectedIDs == ["low", "rest", "high"])
        state.selectStep("group")
        #expect(state.selectedIDs == ["low", "high"] && state.range.ids.isEmpty)
        state.selectStep("rest-step")
        #expect(state.fretboard(instrument: InstrumentProfile()).expected.isEmpty)
        state.selectStep("shape")
        let board = state.fretboard(instrument: InstrumentProfile())
        #expect(board.expected.count == 2 && board.mutedStrings == [6] && board.fingers == [4: 2])
        state.selectEvent("chord", exerciseID: "display", extending: false)
        #expect(state.stepID == nil && state.selectedIDs == ["chord"])
        #expect(state.fretboard(instrument: InstrumentProfile()).mutedStrings.isEmpty)
        state.selectStep("intro")
        #expect(state.exercise == nil && state.selectedIDs.isEmpty && state.fretboard(instrument: InstrumentProfile()).expected.isEmpty)
    }

    @Test func bookmarkVersionAndLanguageDoNotChangeMusicalIdentity() throws {
        let lesson = try lesson()
        let restored = LessonSelection(lesson: lesson, bookmark: LessonBookmark(lessonVersion: 1, stepID: "group"))
        #expect(restored.stepID == "group")
        #expect(lesson.text(for: .en).title != lesson.text(for: .uk).title)
        #expect(restored.selectedIDs == ["low", "high"])
        #expect(LessonSelection(lesson: lesson, bookmark: LessonBookmark(lessonVersion: 2, stepID: "group")).stepID == "intro")
        #expect(LessonSelection(lesson: lesson, bookmark: LessonBookmark(lessonVersion: 1, stepID: "removed")).stepID == "intro")
    }

    @Test func catalogFiltersUseLocalizedCopyAndCombineWithMetadata() throws {
        let lesson = try lesson()
        #expect(LessonFilter(query: "OPEN", difficulty: .beginner, topic: .basics).matches(lesson, language: .en))
        #expect(LessonFilter(query: "струни").matches(lesson, language: .uk))
        #expect(!LessonFilter(query: "струни").matches(lesson, language: .en))
        #expect(!LessonFilter(difficulty: .advanced).matches(lesson, language: .en))
        #expect(!LessonFilter(topic: .rhythm).matches(lesson, language: .en))
        #expect(LessonFilter(query: "  \n").matches(lesson, language: .en))
    }

    @Test func practiceHandoffPreservesExerciseAndTuningAndRejectsDisplayOnly() throws {
        let lesson = try lesson()
        let fixed = try #require(PracticeRequest(lesson: lesson, exerciseID: "fixed"))
        let follows = try #require(PracticeRequest(lesson: lesson, exerciseID: "follows"))
        #expect(fixed.exercise == lesson.manifest.exercises[0])
        #expect(fixed.exercise.requiredTuning == .standard)
        #expect(follows.exercise.tuningPolicy == .followsInstrument && follows.exercise.requiredTuning == nil)
        #expect(PracticeRequest(lesson: lesson, exerciseID: "display") == nil)
        let navigation = AppNavigation(); navigation.openPractice(fixed)
        #expect(navigation.destination == .practice && navigation.practiceRequest == fixed)
        let state = LessonSelection(lesson: lesson)
        state.selectStep("single")
        #expect(state.fretboard(instrument: InstrumentProfile(tuning: .dropD)).tuning == .standard)
        state.selectStep("alternative")
        #expect(state.fretboard(instrument: InstrumentProfile(tuning: .dropD)).tuning == .dropD)
    }
}

@MainActor struct LessonLibraryStateTests {
    @Test func missingAndEmptyCatalogsFinishLoadingWithDistinctStates() async throws {
        let missing = LessonLibraryStore(directory: nil)
        await missing.load()
        #expect(missing.hasLoaded && missing.missingBundle && missing.lessons.isEmpty)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(LessonCatalogManifest(lessons: [])).write(to: root.appendingPathComponent("catalog.json"))
        let empty = LessonLibraryStore(directory: root); await empty.load()
        #expect(empty.hasLoaded && empty.issues.isEmpty && empty.lessons.isEmpty && !empty.missingBundle)
        try Data("{broken".utf8).write(to: root.appendingPathComponent("catalog.json"))
        await empty.load(force: true)
        #expect(empty.hasLoaded && !empty.isLoading && !empty.issues.isEmpty && empty.lessons.isEmpty)
    }
}
