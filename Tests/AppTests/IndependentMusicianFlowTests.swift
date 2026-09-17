import Foundation
import Testing
import Domain
import Audio
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct IndependentMusicianFlowTests {
    private let expected = ["transcribe-riff-solo","reading-music-formats","write-a-riff","arrange-two-guitars",
        "play-with-rhythm-section","prepare-composition","performance-recording","personal-practice-plan"]
    private func library() async -> LessonLibraryStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonLibraryStore(directory: root.appendingPathComponent("Resources/Lessons"))
        await library.load(); return library
    }
    @Test func finalModuleIsDiscoverableInBothLanguagesWithHonestLearningModes() async throws {
        let library = await library()
        #expect(library.catalogLessons.count == 128)
        for language in [LessonLanguage.en,.uk] {
            func results(_ mode: LessonLearningMode? = nil, query: String = "") -> [LoadedLesson] {
                LessonFilter(query: query,moduleID: "independent-musician",mode: mode)
                    .results(library.catalogLessons,language: language,progress: ReadingProgress(),modules: library.modules)
            }
            #expect(results().map(\.id) == expected)
            #expect(results(.selfPractice).map(\.id) == expected)
            #expect(results(.listening).map(\.id) == ["transcribe-riff-solo","personal-practice-plan"])
            #expect(results(.scored).map(\.id) == ["transcribe-riff-solo","reading-music-formats","prepare-composition","performance-recording","personal-practice-plan"])
            #expect(results(.quiz).isEmpty)
            #expect(results(query: "бас drums").map(\.id) == ["play-with-rhythm-section"])
            #expect(library.groups(for: results(),sort: .course).map(\.id) == ["independent-musician"])
        }
    }
    @Test func hiddenResponsesRemainHiddenAndRecordingContextsFreezeTheResolvedInstrument() async throws {
        let library = await library()
        var recordingCases = 0, hiddenCases = 0
        for id in expected {
            let lesson = try #require(library.sourceLesson(id: id))
            for tuning in TuningProfile.presets {
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning,frets: frets)
                    let selection = LessonSelection(lesson: lesson,tuning: tuning,frets: frets)
                    for step in lesson.manifest.steps where step.activityID != nil {
                        selection.selectStep(step.id)
                        let snapshot = try #require(selection.snapshot)
                        if selection.isListeningPractice {
                            hiddenCases += 1
                            #expect(!selection.showsMusicalVisuals && selection.exercise == nil && selection.selectedIDs.isEmpty)
                            #expect(selection.fretboard(instrument: instrument).expected.isEmpty)
                            let entry = try #require(selection.practiceEntries.first)
                            let request = try #require(PracticeRequest(lesson: lesson,snapshot: snapshot,entryID: entry.id))
                            #expect(request.activityReference?.presentation == .listenAndRepeat)
                            #expect(snapshot.activity.recording == nil)
                        } else if snapshot.activity.recording == .selfPractice {
                            recordingCases += 1
                            let exercise = try #require(selection.exercise)
                            let recording = try SelfPracticeRecordingContext(snapshot: snapshot,exercise: exercise)
                            let transport = try recording.transport(bpm: 60)
                            #expect(selection.showsMusicalVisuals && selection.practiceEntries.isEmpty)
                            #expect(transport.mode == .practice && transport.toneVolume == 0 && transport.countInBars == 1)
                            #expect(transport.exercise.assessmentMode == .displayOnly && transport.exercise.durationTicks % 3840 == 0)
                            _ = try TimelineModel(exercise: exercise,instrument: tuning)
                            selection.updateInstrument(InstrumentProfile(tuning: .standard,frets: .twentyFour))
                            #expect(recording.snapshot.instrument == instrument && recording.exercise == exercise)
                            selection.updateInstrument(instrument)
                        }
                    }
                }
            }
        }
        #expect(recordingCases == 400 && hiddenCases == 240)
    }
}
