import Foundation
import Testing
import Domain
@testable import Learning

struct AdvancedPickingCourseTests {
    @Test func physicalPatternsAndCuesRemainFixedWhileSoundingPitchesTranspose() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let up = [60,62,64,65,67,69,71,72,74]
        let golden: [String: [String: [Int]]] = [
            "string-skipping": ["adjacent-control": [57,60,57,60,57,60,57,60], "skip-one": [57,64,57,64,57,64,57,64],
                "skip-two": [57,69,57,69,57,69,57,69], "alternating-gaps": [57,64,57,69,57,67,57,72]],
            "economy-picking": ["alternate-control": up, "economy-up": up, "economy-down": Array(up.reversed()), "turnaround": up + up.reversed()],
            "sweep-picking": ["two-strings": [60,64,60,64], "major-down": [60,64,67,60,64,67], "major-up": [67,64,60,67,64,60],
                "round-trip": [60,64,67,67,64,60], "minor-shape": [60,63,67,67,63,60]],
            "hybrid-picking": ["pick-and-middle": [57,64,57,64,57,64,57,64], "two-fingers": [57,64,69,64,57,64,69,64],
                "inside-outside": [57,69,64,69,57,67,72,67], "hybrid-phrase": [57,64,69,57,67,72,57,64,69,57,67,72]]]
        var count = 0
        for id in golden.keys.sorted() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(lesson.manifest.topic == .technique)
            #expect(lesson.manifest.practiceEntries.count == (id == "sweep-picking" ? 5 : 4) && lesson.manifest.tasks.contains { $0.kind == .selfPractice })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for activity in lesson.manifest.activities {
                        #expect(lesson.availableChoices(activityID: activity.id, instrument: instrument) == [.original])
                        let resolved = try lesson.resolveActivity(id: activity.id, instrument: instrument)
                        let exercise = try #require(resolved.exercises.first), source = try #require(lesson.manifest.exercises.first { $0.id == exercise.id })
                        let notes = exercise.events.filter { $0.kind == .note }
                        #expect(try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi) == golden[id]![activity.id]!.map { $0 + shift })
                        #expect(exercise.events.map(\.positions) == source.events.map(\.positions))
                        #expect(exercise.events.map(\.startTick) == source.events.map(\.startTick))
                        #expect(exercise.events.map(\.durationTicks) == source.events.map(\.durationTicks))
                        if id == "hybrid-picking" {
                            for note in notes {
                                switch note.positions[0].string {
                                case 4: #expect(note.pickStroke == .down && note.pluckFinger == nil)
                                case 2: #expect(note.pluckFinger == .middle && note.pickStroke == nil)
                                case 1: #expect(note.pluckFinger == .ring && note.pickStroke == nil)
                                default: Issue.record("Unexpected hybrid string")
                                }
                            }
                        } else {
                            #expect(notes.allSatisfy { $0.pluckFinger == nil })
                            let expected: [StrumDirection] = notes.indices.map { i in
                                if id == "sweep-picking" {
                                    return activity.id == "major-up" || ((activity.id == "round-trip" || activity.id == "minor-shape") && i >= 3) ? .up : .down
                                }
                                if id == "string-skipping" || activity.id == "alternate-control" { return i.isMultiple(of: 2) ? .down : .up }
                                if activity.id == "economy-down" || activity.id == "turnaround" && i >= 9 { return (i % 3 == 1) ? .down : .up }
                                return (i % 3 == 1) ? .up : .down
                            }
                            #expect(notes.compactMap(\.pickStroke) == expected)
                            if id == "string-skipping" {
                                let strings = notes.map { $0.positions[0].string }
                                #expect(strings.enumerated().allSatisfy { $0.offset.isMultiple(of: 2) ? $0.element == 4 : $0.element != 4 })
                                if activity.id == "skip-one" { #expect(Set(strings) == [4,2]) }
                                if activity.id == "skip-two" { #expect(Set(strings) == [4,1]) }
                            }
                        }
                        for bpm in [40.0,60.0,120.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                        #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                        #expect(exercise.durationTicks % 3840 == 0)
                        count += 1
                    }
                }
            }
        }
        #expect(count == 680)
    }
}
