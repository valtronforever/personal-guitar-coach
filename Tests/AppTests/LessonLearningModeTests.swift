import Foundation
import Testing
import Domain
import Audio
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct LessonLearningModeTests {
    private func lesson(_ id: String) throws -> LoadedLesson {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first { $0.id == id })
    }
    @Test func theoryHasNoMusicalPanelAndListeningHasNoVisualAnswerOrGrading() throws {
        let theory = LessonSelection(lesson: try lesson("guitar-foundations"))
        #expect(theory.exercise == nil && theory.snapshot == nil && !theory.showsMusicalVisuals)
        #expect(theory.tasks.first?.kind == .checklist)
        theory.selectStep("check-understanding")
        #expect(theory.tasks.first?.kind == .quiz && !theory.isListeningQuestion)
        let hearing = LessonSelection(lesson: try lesson("hear-pitch-direction"), tuning: .cStandard)
        hearing.selectStep("listen")
        #expect(hearing.isListeningQuestion && !hearing.showsMusicalVisuals && hearing.practiceEntries.isEmpty)
        #expect(hearing.exercise?.id == "hear-pitch-direction-practice")
        #expect(hearing.exercise?.requiredTuning == .cStandard && hearing.selectedIDs.isEmpty)
        let task = try #require(hearing.tasks.first)
        let before = hearing.taskContext(task), preview = hearing.previewContext
        hearing.updateInstrument(InstrumentProfile(tuning: .dropD, frets: .nineteen))
        #expect(before != hearing.taskContext(task) && preview != hearing.previewContext)
        #expect(hearing.exercise?.requiredTuning == .dropD)
        #expect(PracticeRequest(lesson: hearing.sourceLesson, snapshot: try #require(hearing.snapshot), entryID: task.id) == nil)
    }

    @Test func listeningResponseKeepsExpectedMaterialOutOfReadingAndCarriesPresentationToPractice() throws {
        for id in ["find-heard-note", "hear-pitch-direction", "repeat-a-rhythm", "transcribe-short-melody"] {
            let source = try lesson(id), selection = LessonSelection(lesson: try lesson(id), tuning: .dropA)
            for entry in source.manifest.practiceEntries {
                let step = try #require(source.manifest.steps.first { $0.activityID == entry.activityID })
                selection.selectStep(step.id)
                #expect(selection.isListeningPractice && !selection.isListeningQuestion && !selection.showsMusicalVisuals)
                #expect(selection.exercise == nil && selection.selectedIDs.isEmpty && !selection.canChoosePosition)
                let snapshot = try #require(selection.snapshot)
                let request = try #require(PracticeRequest(lesson: source, snapshot: snapshot, entryID: entry.id))
                #expect(request.activityReference?.presentation == .listenAndRepeat)
                #expect(request.exercise.requiredTuning == .dropA)
                #expect(selection.fretboard(instrument: InstrumentProfile(tuning: .dropA)).expected.isEmpty)
                for language in [LessonLanguage.en, .uk] {
                    let text = try #require(selection.text(stepID: step.id, language: language))
                    #expect(!text.body.contains("{{") && !text.body.contains("fret=") && !text.body.contains("MIDI"))
                }
            }
        }
    }
    @Test func selfReportedChordCanBeVisualizedAndPlayedButCannotBecomeAnAssessment() throws {
        let source = try lesson("power-chord-self-practice")
        let selection = LessonSelection(lesson: source, tuning: .cStandard)
        #expect(selection.showsMusicalVisuals && selection.exercise?.assessmentMode == .displayOnly)
        #expect(selection.practiceEntries.isEmpty && selection.tasks.first?.kind == .selfPractice)
        let board = selection.fretboard(instrument: InstrumentProfile(tuning: .cStandard))
        #expect(board.expected.count == 2)
        let request = try TransportRequest(exercise: #require(selection.exercise), tuning: .cStandard, bpm: 60,
            range: 0..<3840, countInBars: 1, loops: true)
        #expect(request.exercise.events[0].positions.count == 2)
    }

    @Test func taskProgressSurvivesNavigationReadChangesAndRestartWithoutCreatingScores() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = LocalRepository(root: directory), reading = ReadingProgressStore(repository: LocalRepository(root: directory))
        await reading.load()
        let lesson = try lesson("guitar-foundations"), selection = LessonSelection(lesson: lesson)
        let task = try #require(selection.tasks.first), context = selection.taskContext(task)
        reading.visit(lessonID: lesson.id, version: lesson.manifest.version, stepID: selection.stepID)
        let value = LessonTaskProgress(context: context, checkedIDs: Set(task.itemIDs))
        reading.setTask(value, taskID: task.id, lessonID: lesson.id)
        reading.setRead(true, lessonID: lesson.id, version: lesson.manifest.version, stepID: "check-understanding")
        reading.visit(lessonID: lesson.id, version: lesson.manifest.version, stepID: "prepare")
        for _ in 0..<1000 {
            await reading.flush()
            if !reading.isSaving { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(!reading.isSaving && !reading.saveFailed)
        let restored = ReadingProgressStore(repository: LocalRepository(root: directory)); await restored.load()
        #expect(restored.progress.lessons[lesson.id]?.learningTasks[task.id] == value)
        #expect(restored.progress.lessons[lesson.id]?.readVersion == lesson.manifest.version)
        #expect(try await repo.history().records.isEmpty)
        selection.updateInstrument(InstrumentProfile(tuning: .bStandard, frets: .nineteen))
        #expect(task.isComplete(value, context: selection.taskContext(task))) // Theory is independent of the instrument.
        reading.visit(lessonID: lesson.id, version: lesson.manifest.version + 1, stepID: "prepare")
        #expect(reading.progress.lessons[lesson.id]?.learningTasks[task.id] == value) // Keep old evidence, but not current completion.
        #expect(!task.isComplete(value, context: LessonTaskContext(lessonVersion: lesson.manifest.version + 1)))
    }

    @Test func selfAssessmentBecomesStaleAfterTuningFretsOrPositionChange() throws {
        let selection = LessonSelection(lesson: try lesson("power-chord-self-practice"))
        let task = try #require(selection.tasks.first)
        let value = LessonTaskProgress(context: selection.taskContext(task), checkedIDs: Set(task.itemIDs))
        #expect(task.isComplete(value, context: selection.taskContext(task)))
        selection.updateInstrument(InstrumentProfile(tuning: .standard, frets: .nineteen))
        #expect(!task.isComplete(value, context: selection.taskContext(task)))
        selection.updateInstrument(InstrumentProfile(tuning: .cStandard))
        #expect(!task.isComplete(value, context: selection.taskContext(task)))
        let relocated = LessonTaskContext(lessonVersion: value.context.lessonVersion, instrument: value.context.instrument,
            position: .region(firstFret: 7), resolverVersion: value.context.resolverVersion)
        #expect(!task.isComplete(value, context: relocated))
    }
}
