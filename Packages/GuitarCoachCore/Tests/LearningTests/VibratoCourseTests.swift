import Foundation
import Testing
import Domain
@testable import Learning

struct VibratoCourseTests {
    @Test func fiveProgressionsPreservePitchAndGestureAcrossTuningsNecksAndRegions() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let loaded = LessonCatalogLoader().load(directory: repo.appendingPathComponent("Resources/Lessons"))
        #expect(loaded.issues.isEmpty)
        let lesson = try #require(loaded.lessons.first { $0.id == "vibrato" })
        #expect(lesson.manifest.practiceEntries.count == 5 && lesson.manifest.learningTasks?.map(\.kind) == [.quiz, .selfPractice])
        for (index, tuning) in TuningProfile.presets.enumerated() {
            let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                for (id, extent, period) in [("steady", 0, 960), ("narrow", 40, 960), ("wide", 80, 960), ("faster", 80, 480), ("delayed-phrase", 60, 480)] {
                    for choice in [PositionChoice.original, .region(firstFret: 7), .region(firstFret: 12)] {
                        let resolved = try lesson.resolveActivity(id: id, instrument: instrument, choice: choice)
                        let exercise = try #require(resolved.exercises.first)
                        let notes = try exercise.resolvedEvents(instrument: tuning).filter { $0.event.kind == .note }
                        let base = id == "delayed-phrase" ? [64,62,64] : [64,64]
                        #expect(notes.flatMap(\.pitches).map(\.midi) == base.map { $0 + shift })
                        #expect(notes.allSatisfy { $0.event.positions.count == 1 && $0.event.positions[0].fret > 0 && $0.event.positions[0].fret <= frets.rawValue })
                        #expect(notes.map { $0.event.startTick } == base.indices.map { Int64($0) * 7680 })
                        #expect(exercise.durationTicks == Int64(base.count) * 7680)
                        if id == "steady" { #expect(notes.allSatisfy { $0.event.assessSustain && $0.event.vibrato == nil && $0.event.durationTicks == 3840 }) }
                        else {
                            let start: Int64 = id == "delayed-phrase" ? 1920 : 960
                            #expect(notes.allSatisfy { $0.event.vibrato?.extentCents == extent && $0.event.vibrato?.periodTicks == Int64(period) && $0.event.vibrato?.startTick == start && $0.event.vibrato?.endTick == start + 3840 && $0.event.durationTicks == start + 4800 })
                        }
                        for bpm in [60.0, 90.0] { #expect(try MonophonicCapability.limitations(exercise: exercise, instrument: tuning, bpm: bpm).isEmpty) }
                        #expect(resolved.english.steps[id]?.body.contains("{{") == false && resolved.ukrainian.steps[id]?.body.contains("{{") == false)
                        #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                    }
                }
            }
        }
    }
}
