import Foundation
import Testing
import Domain
@testable import Learning

struct RockRhythmCourseTests {
    @Test func rockProgressionPreservesPatternsMutingAndHonestPracticeAcrossInstruments() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let ids = ["moving-power-chords","palm-muting","fretting-hand-muting","two-hand-muting","pedal-tone-riffs","first-overdriven-riff"]
        let noteCounts = [[4,16],[8,24],[4,8],[4,12],[8,20],[8,29]]
        let barCounts = [[4,4],[2,4],[2,4],[2,4],[2,4],[2,8]]
        let muteCounts = [[0,0],[4,24],[0,0],[0,0],[0,0],[6,21]]
        // Source-coordinate pitches, independently specified from the lesson fret arrays.
        let pitches: [[[Int]]] = [
            [[43,50,45,52,47,54,43,50], [43,43,43,43,45,45,45,45,47,47,47,47,43,43,43,43].flatMap { [$0,$0+7] }],
            [Array(repeating:40,count:8),Array(repeating:40,count:24)],
            [[43,50,43,50,45,52,45,52],[43,43,45,45,47,47,43,43].flatMap { [$0,$0+7] }],
            [[45,52,52,45],Array(repeating:[45,52,57],count:4).flatMap { $0 }],
            [[40,43,40,45,40,47,40,45],[40,43,40,45,40,40,47,40,45,40,40,43,40,47,40,40,45,40,43,40]],
            [[40,40,43,50,40,40,40,45,52,40],[3,5,3,7,3,5,7].flatMap { [40,40,40+$0,47+$0,40] } + [40,47]]
        ]
        for (lessonIndex,id) in ids.enumerated() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(lesson.manifest.curriculum?.moduleID == "rock-rhythm")
            #expect(lesson.manifest.practiceEntries.count == (id == "pedal-tone-riffs" ? 2 : 0))
            for (tuningIndex,tuning) in TuningProfile.presets.enumerated() {
                let bassAnchor = ["palm-muting","pedal-tone-riffs","first-overdriven-riff"].contains(id)
                let shift = (bassAnchor ? [0,-2,-2,-4,-4,-6,-5,-7] : [0,0,-2,-2,-4,-4,-5,-5])[tuningIndex]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for (index,activity) in lesson.manifest.activities.enumerated() {
                        let resolved = try lesson.resolveActivity(id: activity.id, instrument: instrument)
                        let exercise = try #require(resolved.exercises.first)
                        #expect(exercise.noteCount == noteCounts[lessonIndex][index])
                        #expect(exercise.durationTicks == Int64(barCounts[lessonIndex][index]) * 3840)
                        #expect(exercise.events.filter(\.palmMuted).count == muteCounts[lessonIndex][index])
                        #expect(try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi) == pitches[lessonIndex][index].map { $0 + shift })
                        #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                        if id == "pedal-tone-riffs" {
                            for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                        } else {
                            #expect(exercise.assessmentMode == .displayOnly)
                            #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm:50) }
                        }
                        if id == "first-overdriven-riff", index == 1 {
                            #expect(exercise.events.last?.kind == .rest && exercise.events.last?.durationTicks == 1920)
                            #expect(exercise.events.dropLast().last?.palmMuted == false)
                        }
                    }
                }
            }
        }
    }
}
