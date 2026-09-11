import Foundation
import Testing
import Domain
import Learning

struct StarterCourseTests {
    private func load() throws -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return report.lessons
    }
    private let expected: [(String, [Int], Int64, Int)] = [
        ("open-strings-intro", [40, 64], 3840, 60),
        ("first-frets", [40, 41, 42, 43, 43, 42, 41, 40], 7680, 60),
        ("steady-pulse", Array(repeating: 40, count: 8), 7680, 60),
        ("c-major", [48, 50, 52, 53, 55, 57, 59, 60, 59, 57, 55, 53, 52, 50, 48], 15360, 60),
        ("a-minor-pentatonic", [45, 48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72, 69, 67, 64, 62, 60, 57, 55, 52, 50, 48, 45], 23040, 50),
        ("em-arpeggio", [40, 47, 52, 55, 59, 64, 59, 55, 52, 47, 40], 11520, 60),
        ("c-standard-open-strings", [36, 60], 3840, 60),
        ("c-standard-first-frets", [36, 37, 38, 39, 39, 38, 37, 36], 7680, 60),
        ("c-standard-steady-pulse", Array(repeating: 36, count: 8), 7680, 60),
        ("ab-major-c-standard", [44, 46, 48, 49, 51, 53, 55, 56, 55, 53, 51, 49, 48, 46, 44], 15360, 60),
        ("f-minor-pentatonic-c-standard", [41, 44, 46, 48, 51, 53, 56, 58, 60, 63, 65, 68, 65, 63, 60, 58, 56, 53, 51, 48, 46, 44, 41], 23040, 50),
        ("cm-arpeggio-c-standard", [36, 43, 48, 51, 55, 60, 55, 51, 48, 43, 36], 11520, 60)
    ]
    @Test func TwelveBilingualLessonsMatchIndependentMusicalSequencesAndDeclaredTempos() throws {
        let lessons = try load()
        #expect(lessons.map(\.id) == expected.map(\.0))
        for (lesson, reference) in zip(lessons, expected) {
            let id = try #require(lesson.manifest.practiceExerciseIDs.first)
            let exercise = try #require(lesson.manifest.exercises.first { $0.id == id })
            let pitches = try exercise.resolvedEvents(instrument: .dropD).flatMap(\.pitches).map(\.midi)
            #expect(pitches == reference.1 && exercise.durationTicks == reference.2 && Int(exercise.defaultBPM) == reference.3)
            let tuning: TuningProfile = lesson.id.contains("c-standard") ? .cStandard : .standard
            #expect(exercise.tuningPolicy == .fixedTuning && exercise.requiredTuning == tuning)
            for bpm in [exercise.minimumBPM, exercise.defaultBPM, exercise.maximumBPM] {
                #expect(try MonophonicCapability.limitations(exercise: exercise, instrument: tuning, bpm: bpm).isEmpty)
                try exercise.validateForPractice(instrument: tuning, bpm: bpm)
            }
            #expect(throws: MusicError.tuningMismatch) { try exercise.validateForPractice(instrument: .dropD, bpm: exercise.defaultBPM) }
            let referenced = Set(lesson.manifest.steps.filter { $0.exerciseID == exercise.id }.flatMap(\.eventIDs))
            #expect(referenced == Set(exercise.events.map(\.id)))
            for language in [LessonLanguage.en, .uk] {
                let text = lesson.text(for: language)
                #expect(!text.goal.isEmpty && !text.body.isEmpty && text.steps.count == lesson.manifest.steps.count)
                #expect(text.lessonVersion == lesson.manifest.version)
            }
            for step in lesson.manifest.steps {
                let visual = try lesson.visual(stepID: step.id, instrument: .dropD)
                #expect(visual.tuning == tuning)
                if step.kind == .events {
                    let notes = visual.events.flatMap(\.event.positions)
                    #expect(Set(visual.positions.map(\.position)) == Set(notes))
                    #expect(visual.events.map(\.id) == step.eventIDs)
                }
            }
        }
        #expect(lessons[0].manifest.version == 2 && lessons[0].manifest.exercises[0].version == 1)
    }
    @Test func cStandardVariantsPreserveFingeringsButKeepIndependentTargetsAndHistoryIDs() throws {
        let lessons = try load()
        for (original, variant) in zip(lessons.prefix(6), lessons.suffix(6)) {
            #expect(original.id != variant.id && variant.manifest.version == 1)
            for (source, adapted) in zip(original.manifest.exercises, variant.manifest.exercises) {
                #expect(source.id != adapted.id && source.events == adapted.events)
                #expect(source.requiredTuning == .standard && adapted.requiredTuning == .cStandard)
                if adapted.assessmentMode == .monophonic {
                    #expect(throws: MusicError.tuningMismatch) { try adapted.validateForPractice(instrument: .standard, bpm: 60) }
                    #expect(throws: MusicError.tuningMismatch) { try source.validateForPractice(instrument: .cStandard, bpm: 60) }
                } else {
                    let tones = try adapted.resolvedEvents(instrument: .standard).flatMap(\.pitches).map(\.midi)
                    #expect(tones == [36, 43, 48, 51, 55, 60])
                    #expect(throws: MusicError.displayOnlyExercise) { try adapted.validateForPractice(instrument: .cStandard, bpm: 60) }
                }
            }
            for language in [LessonLanguage.en, .uk] {
                let text = variant.text(for: language)
                #expect(text.title.contains("C Standard") && text.body.contains("A4 = 440"))
            }
        }
    }
    @Test func PulseRestsAndEmChordCannotSilentlyBecomeDifferentPractice() throws {
        let lessons = try load()
        let rhythm = try #require(lessons.first { $0.id == "steady-pulse" }?.manifest.exercises.first)
        #expect(rhythm.events.filter { $0.kind == .note }.map(\.startTick) == [0, 1920, 2880, 3840, 4320, 5280, 5760, 6720])
        #expect(rhythm.events.filter { $0.kind == .rest }.map(\.startTick) == [960, 4800, 6240, 7200])
        #expect(Set(rhythm.events.map(\.durationTicks)) == [480, 960])
        let em = try #require(lessons.first { $0.id == "em-arpeggio" })
        let shape = try #require(em.manifest.exercises.first { $0.assessmentMode == .displayOnly })
        let tones = try shape.resolvedEvents(instrument: .standard).flatMap(\.pitches).map { $0.midi % 12 }
        #expect(Set(tones) == [4, 7, 11] && tones.count == 6)
        #expect(!em.manifest.practiceExerciseIDs.contains(shape.id))
        #expect(throws: MusicError.displayOnlyExercise) { try shape.validateForPractice(instrument: .standard, bpm: 60) }
        let fingering = try #require(em.manifest.steps.first?.fingering)
        #expect(Dictionary(uniqueKeysWithValues: fingering.positions.map { ($0.string, $0.fret) }) == [6: 0, 5: 2, 4: 2, 3: 0, 2: 0, 1: 0])
        #expect(fingering.fingerNumbers == [5: 2, 4: 3] && fingering.mutedStrings.isEmpty)
    }
    @Test func EveryPracticeProducesDeterministicPerfectAndMissedEvidenceAtBothSampleRates() throws {
        for lesson in try load() {
            for exercise in lesson.manifest.exercises where lesson.manifest.practiceExerciseIDs.contains(exercise.id) {
                for rate in [44100.0, 48000.0] {
                    let endpoint = try CalibrationEndpoint(uid: "course-fixture", channel: 1, sampleRate: rate, bufferFrames: 512,
                        deviceLatencyFrames: 0, streamLatencyFrames: 0)
                    let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "course-events-1")
                    let profile = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0.05, uncertaintySeconds: 0.015,
                        evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                            durationSeconds: 40, residualP95Seconds: 0.005, driftSeconds: 0))
                    let tuning = try #require(exercise.requiredTuning)
                    let config = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(tuning: tuning), bpm: exercise.defaultBPM,
                        route: route, calibration: profile, lesson: PracticeLessonReference(id: lesson.id, version: lesson.manifest.version))
                    var attacks: [PracticeAttack] = []
                    for event in config.selectedEvents where event.kind == .note {
                        let seconds = config.countInSeconds + Double(event.startTick) / 960 * 60 / config.bpm
                        let time = try route.expectedTime(renderEpochSeconds: 100, sampleFrame: Int64((seconds * rate).rounded())) + 0.05
                        let frequency = try tuning.frequency(at: event.positions[0])
                        attacks.append(try PracticeAttack(id: UInt64(attacks.count + 1), normalizedOnset: time, frequency: frequency, clarity: 0.99, reliable: true))
                    }
                    for missed in [false, true] {
                        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
                            finishedAt: Date(timeIntervalSince1970: 60), phase: .completed, reason: nil, signalConfirmed: true,
                            renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: missed ? [] : attacks,
                            clipping: [], analysisVersion: "course-events-1")
                        let report = try AssessmentEngine.evaluate(evidence)
                        #expect(report.validity == .valid && report.overallScore == (missed ? 0 : 100))
                        #expect(report.expectedCount == exercise.noteCount && report.missedCount == (missed ? exercise.noteCount : 0))
                        #expect(try AssessmentEngine.evaluate(evidence) == report)
                        let advice = FeedbackEngine.recommendations(for: report)
                        #expect((1...3).contains(advice.count) && advice.allSatisfy { $0.sourceAttemptID == report.id })
                        #expect(advice.first?.kind == (missed ? .missed : .repeatFragment))
                    }
                }
            }
        }
    }
}
