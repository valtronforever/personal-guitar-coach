import Foundation
import Testing
import Domain
import Learning
import Persistence
import Audio
@testable import PersonalGuitarCoach

@MainActor struct StarterCourseFlowTests {
    @Test func EachBundledLessonConnectsTextVisualsPracticeSavedResultAndRetry() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(library.issues.isEmpty && library.lessons.count == 12)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory), assessment = AssessmentStore(repository: repository)
        let data = LocalDataStore(repository: repository)
        let audio = AudioSessionStore(repository: nil), calibration = CalibrationStore(repository: nil)
        let practice = PracticeModel(audio: audio, calibration: calibration), navigation = AppNavigation()
        for lesson in library.lessons {
            let selection = LessonSelection(lesson: lesson)
            for step in lesson.manifest.steps {
                selection.selectStep(step.id)
                let board = selection.fretboard(instrument: InstrumentProfile(tuning: .dropD))
                let visual = try lesson.visual(stepID: step.id, instrument: .dropD)
                #expect(board.tuning == visual.tuning && board.expected == Set(visual.positions.map(\.position)))
                if let exercise = selection.exercise {
                    let timeline = try TimelineModel(exercise: exercise, instrument: .dropD)
                    #expect(timeline.events.map(\.id) == exercise.events.map(\.id))
                    #expect(Set(timeline.events.map(\.id)).isSuperset(of: selection.selectedIDs))
                }
                let before = selection.selectedIDs
                #expect(lesson.text(for: .en).steps[step.id] != nil && lesson.text(for: .uk).steps[step.id] != nil)
                #expect(selection.selectedIDs == before)
            }
            for id in lesson.manifest.practiceExerciseIDs {
                let request = try #require(PracticeRequest(lesson: lesson, exerciseID: id))
                navigation.openPractice(request); practice.configure(navigation.practiceRequest)
                #expect(practice.phase == .idle && !practice.isBusy && !practice.physicallyTuned)
                let endpoint = try CalibrationEndpoint(uid: "course-flow-stub", channel: 1, sampleRate: 48000, bufferFrames: 512)
                let configuration = try PracticeConfiguration(exercise: request.exercise, instrument: InstrumentProfile(tuning: try #require(request.exercise.requiredTuning)), bpm: practice.bpm,
                    route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "course-events-1"),
                    lesson: PracticeLessonReference(id: request.lessonID, version: request.lessonVersion))
                // Healthy silence is explicit synthetic evidence, not a device capture or a permission request.
                let evidence = try PracticeEvidence(id: UUID(), configuration: configuration, startedAt: Date(timeIntervalSince1970: 1),
                    finishedAt: Date(timeIntervalSince1970: 60), phase: .completed, reason: nil, signalConfirmed: true,
                    renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: [], clipping: [], analysisVersion: "course-events-1")
                #expect(await assessment.receive(evidence))
                let result = try #require(assessment.latest)
                #expect(result.validity == .uncalibrated && result.pitchScore == 0 && result.overallScore == nil)
                let advice = try #require(FeedbackEngine.recommendations(for: result).first { $0.kind == .missed })
                let retry = try #require(PracticeRequest(result: result, recommendation: advice))
                navigation.openPractice(retry); practice.configure(navigation.practiceRequest)
                #expect(practice.request?.exercise == request.exercise && practice.bpm == advice.bpm)
                #expect(retry.archivedTuning == request.exercise.requiredTuning)
                #expect(practice.firstBar == advice.firstBar && practice.lastBar == advice.lastBar)
                #expect(practice.selectedEventIDs.isSuperset(of: Set(advice.eventIDs)))
                #expect(!practice.physicallyTuned && !practice.isBusy && practice.phase == .idle)
                #expect(ResultPresentation.annotations(result).values.allSatisfy { $0 == .missing })
            }
            for exercise in lesson.manifest.exercises where exercise.assessmentMode == .displayOnly {
                #expect(PracticeRequest(lesson: lesson, exerciseID: exercise.id) == nil)
            }
        }
        await data.reload()
        #expect(data.records.count == 12 && data.historyIssues.isEmpty)
        for record in data.records {
            #expect(record.assessment != nil)
            #expect(ResultPresentation.title(record: record, lessons: library.lessons, language: .en) != nil)
            #expect(ResultPresentation.title(record: record, lessons: library.lessons, language: .uk) != nil)
        }
        let intro = try #require(library.lessons.first)
        let staleBookmark = LessonBookmark(lessonVersion: 1, stepID: "hear-high-e", readVersion: 1)
        let restored = LessonSelection(lesson: intro, bookmark: staleBookmark)
        #expect(restored.stepID == intro.manifest.steps.first?.id)
        #expect(staleBookmark.readVersion != intro.manifest.version)
    }
}
