import Foundation
import Testing
import Domain
@testable import Learning

struct PickingCourseTests {
    @Test func directionsSurviveEveryTuningWithoutBecomingMeasuredTechnique() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report=LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        for id in ["alternate-picking","hand-synchronization"] {
            let lesson=try #require(report.lessons.first { $0.id == id })
            #expect(lesson.manifest.adaptation?.policy == .fretPattern)
            for tuning in TuningProfile.presets {
                for frets in GuitarFretCount.allCases {
                    for activity in lesson.manifest.activities {
                        let resolved=try lesson.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets))
                        let exercise=try #require(resolved.exercises.first)
                        let notes=exercise.events.filter { $0.kind == .note }
                        let firstUp=activity.id == "upstroke-start"
                        for (n,note) in notes.enumerated() {
                            let expected: StrumDirection = (n.isMultiple(of:2) != firstUp) ? .down : .up
                            #expect(note.pickStroke == expected && note.pickingDirection == expected && note.strum == nil)
                        }
                        #expect(exercise.events.filter { $0.kind == .rest }.allSatisfy { $0.pickStroke == nil })
                        let expectedPositions: [FretPosition]
                        switch activity.id {
                        case "one-string":
                            expectedPositions=try Array(repeating:FretPosition(string:3,fret:5),count:16)
                            #expect(exercise.durationTicks == 7680)
                        case "cross-strings":
                            expectedPositions=try Array(repeating:[FretPosition(string:6,fret:5),FretPosition(string:6,fret:7),FretPosition(string:5,fret:5),FretPosition(string:5,fret:7)],count:4).flatMap { $0 }
                            #expect(exercise.durationTicks == 7680)
                        case "upstroke-start":
                            expectedPositions=try Array(repeating:FretPosition(string:3,fret:5),count:8)
                            #expect(exercise.durationTicks == 3840)
                        case "one-note-at-a-time":
                            expectedPositions=try [6,5,4].flatMap { s in try (5...8).map { try FretPosition(string:s,fret:$0) } }
                            #expect(exercise.durationTicks == 15360 && exercise.events.suffix(4).allSatisfy { $0.kind == .rest })
                        case "four-note-groups":
                            expectedPositions=try Array(repeating:(5...8).map { try FretPosition(string:3,fret:$0) },count:4).flatMap { $0 }
                            #expect(exercise.durationTicks == 15360 && exercise.events.filter { $0.kind == .rest }.map(\.durationTicks) == [1920,1920,1920,1920])
                        default: Issue.record("Unknown activity");continue
                        }
                        #expect(notes.flatMap(\.positions) == expectedPositions)
                        for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument:tuning,bpm:bpm) }
                        #expect(try JSONDecoder().decode(Exercise.self,from:JSONEncoder().encode(exercise)) == exercise)
                    }
                }
            }
        }
    }
}
