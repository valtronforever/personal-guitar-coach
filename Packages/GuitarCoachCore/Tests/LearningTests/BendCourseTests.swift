import Foundation
import Testing
import Domain
@testable import Learning

struct BendCourseTests {
    @Test func sourceTargetsAndAllTuningVariantsAgreeWithBendIntervals() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        for id in ["first-bend", "bend-target-and-release"] {
            let lesson = try #require(report.lessons.first { $0.id == id })
            for tuning in TuningProfile.presets { for frets in GuitarFretCount.allCases {
                for activity in lesson.manifest.activities {
                    let exercise = try #require(lesson.resolveActivity(id: activity.id, instrument: InstrumentProfile(tuning: tuning, frets: frets)).exercises.first)
                    let notes = exercise.events.filter { $0.kind == .note }
                    if activity.id.contains("target") {
                        let interval = activity.id == "half-step-target" ? 1 : 2
                        #expect(notes.flatMap(\.positions) == (try [FretPosition(string: 3, fret: 9), FretPosition(string: 3, fret: 9 + interval), FretPosition(string: 3, fret: 9)]))
                        let midi = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                        #expect(midi[1] - midi[0] == interval && midi[2] == midi[0])
                        #expect(exercise.durationTicks == 3840 && notes.allSatisfy { $0.bend == nil })
                    } else {
                        let returning = id == "bend-target-and-release", count = activity.id == "half-step-return" ? 4 : 2
                        #expect(notes.count == count && exercise.durationTicks == Int64(count) * 3840)
                        for (index, note) in notes.enumerated() {
                            #expect(note.startTick == Int64(index) * 3840 && note.durationTicks == 2880)
                            #expect(note.positions == [try FretPosition(string: 3, fret: 9)])
                            let bend = try #require(note.bend)
                            #expect(bend.semitones == (activity.id.hasPrefix("half-step") ? 1 : 2))
                            #expect(bend.riseStartTick == 480 && bend.riseEndTick == 960)
                            #expect(bend.releaseStartTick == (returning ? 1920 : nil) && bend.releaseEndTick == (returning ? 2400 : nil))
                        }
                        #expect(exercise.events.filter { $0.kind == .rest }.allSatisfy { $0.durationTicks == 960 })
                    }
                    for bpm in [40.0, 60.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                    #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                }
            } }
        }
    }
    @Test func bendRelocationAvoidsAnOpenStringEvenWhenItIsTheNearestPitch() throws {
        // Same E4 exists at 1/0 and 2/5. A bend requires a fretted destination.
        let source = try FretPosition(string: 1, fret: 1)
        let resolved = try LessonFingeringResolver.resolve([source], sourceTuning: .standard, tuning: .standard,
            shift: -1, maximumFret: 19, region: nil, minimumFret: 1)
        #expect(resolved == [try FretPosition(string: 2, fret: 5)])
    }
}
