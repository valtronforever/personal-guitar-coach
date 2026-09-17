import Foundation
import Testing
import Domain
import Learning
@testable import Audio
@testable import PersonalGuitarCoach

@MainActor struct ImprovisationPresentationTests {
    private func lessons() throws -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return report.lessons.filter { (85...88).contains($0.manifest.curriculum?.ordinal ?? 0) }
    }
    @Test func allModelsHaveCompleteTABAndMonophonicStaffWhileOnlyFixedTargetsAreGraded() throws {
        let lessons = try lessons(); #expect(lessons.count == 4)
        for lesson in lessons {
            #expect(LessonLearningMode.selfPractice.includes(lesson))
            #expect(LessonLearningMode.scored.includes(lesson) == (lesson.id == "chord-tone-targeting"))
            for tuning in [TuningProfile.standard, .cStandard] {
                for activity in lesson.manifest.activities {
                    let resolved = try lesson.resolveActivity(id: activity.id, instrument: InstrumentProfile(tuning: tuning))
                    let exercise = try #require(resolved.exercises.first)
                    let timeline = try TimelineModel(exercise: exercise, instrument: tuning)
                    let staff = StaffModel(timeline: timeline, key: .neutral)
                    #expect(timeline.events.map(\.id) == exercise.events.map(\.id))
                    if exercise.events.contains(where: { $0.positions.count > 1 }) {
                        #expect(activity.id == "backdrop" && timeline.events.count == 4)
                        #expect(timeline.events.allSatisfy { $0.pitches.count == 3 })
                        // Chords use TAB/fretboard; the existing staff contract explicitly supports one voice.
                        #expect(throws: StaffLimitation.polyphony) { try staff.symbols(in: 0) }
                    } else {
                        let symbols = try (0..<timeline.barCount).flatMap { try staff.symbols(in: $0) }
                        let starts = symbols.filter { $0.startTick == $0.resolved.event.startTick }
                        #expect(Set(starts.map(\.eventID)) == Set(exercise.events.map(\.id)))
                        #expect(starts.compactMap(\.pitch).map(\.soundingMIDI) == timeline.events.flatMap(\.pitches).map(\.midi))
                    }
                    if exercise.assessmentMode == .displayOnly {
                        #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm: 60) }
                    }
                }
            }
        }
    }
    @Test func callSlotsContainOnlyMetronomeAndTheNextLoopRestartsTheCall() throws {
        let lesson = try #require(lessons().first { $0.id == "question-answer-phrases" })
        for activity in ["call-one", "call-two"] {
            let exercise = try #require(lesson.resolveActivity(id: activity, instrument: InstrumentProfile(tuning: .cStandard)).exercises.first)
            for rate in [44100.0,48000.0] {
                let request = try TransportRequest(exercise: exercise, tuning: .cStandard, bpm: 60, countInBars: 0, loops: true, clickEnabled: false)
                let tone = try TransportPlan(request: request, sampleRate: rate)
                let first = try tone.render(startFrame: 1000, count: 2000)
                #expect(first.contains { abs($0) > 0.01 })
                #expect(try tone.render(startFrame: Int64(4*rate), count: 2000).allSatisfy { $0 == 0 })
                #expect(try tone.render(startFrame: Int64(8*rate)+1000, count: 2000) == first)
                let withClicks = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .cStandard, bpm: 60,
                    countInBars: 0, loops: true, clickEnabled: true), sampleRate: rate)
                #expect(try withClicks.render(startFrame: Int64(4*rate), count: 1000).contains { abs($0) > 0.01 })
            }
        }
    }
}
