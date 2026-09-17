import Foundation
import Testing
import Domain
@testable import Learning

struct LegatoChainCourseTests {
    @Test func fullLegatoAndTappingPhrasesKeepIndependentMusicalTargetsAcrossTuningsAndFrets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let golden: [String: [String: [[Int]]]] = [
            "long-legato": ["three-notes": [[60,62,60]], "five-notes": [[60,62,64,62,60]],
                "string-crossings": [[60,62,64,62,60], [64,65,67,65,64], [67,69,71,69,67]]],
            "tapping": ["tap-return": [[60,67,60]], "minor-triad": [[60,63,67,63,60]], "two-cycles": [[60,63,67,63,60,63,67,63,60]]]]
        var count = 0
        for id in golden.keys.sorted() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(lesson.manifest.practiceEntries.count == 3 && lesson.manifest.tasks.contains { $0.kind == .selfPractice })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for activity in lesson.manifest.activities {
                        let choices = lesson.availableChoices(activityID: activity.id, instrument: instrument)
                        #expect(choices.contains(.original))
                        #expect(activity.id == "string-crossings" ? choices == [.original] : choices.count >= 2)
                        for choice in choices {
                            let resolved = try lesson.resolveActivity(id: activity.id, instrument: instrument, choice: choice)
                            let exercise = try #require(resolved.exercises.first), notes = exercise.events.filter { $0.kind == .note }
                            let expected = try #require(golden[id]?[activity.id])
                            #expect(notes.count == expected.count)
                            for (event,pitches) in zip(notes, expected) {
                                let chain = try #require(event.legatoChain)
                                #expect(try event.techniquePositions.map { try tuning.pitch(at: $0).midi } == pitches.map { $0 + shift })
                                #expect(chain.boundaryTicks == pitches.indices.map { Int64($0) * 960 })
                                #expect(event.durationTicks == Int64(pitches.count) * 960 && event.pickStroke == .down)
                                #expect(event.techniquePositions.allSatisfy(instrument.contains))
                                #expect(Set(event.techniquePositions.map(\.string)).count == 1)
                                #expect(chain.targets.contains { $0.kind == .tap } == (id == "tapping"))
                            }
                            for bpm in [40.0,60.0,90.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                            let source = try #require(lesson.manifest.exercises.first { $0.id == exercise.id })
                            #expect(exercise.events.map(\.startTick) == source.events.map(\.startTick))
                            #expect(exercise.events.map(\.durationTicks) == source.events.map(\.durationTicks))
                            #expect(exercise.events.last?.kind == .rest && exercise.durationTicks % 3840 == 0)
                            let visual = try resolved.visual(stepID: activity.id)
                            #expect(Set(visual.positions.map(\.pitch.midi)) == Set(expected.flatMap { $0 }.map { $0 + shift }))
                            #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                            count += 1
                        }
                    }
                }
            }
        }
        #expect(count >= 480)
    }
}
