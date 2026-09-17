import Foundation
import Testing
import Domain
@testable import Learning

struct PitchTransitionCourseTests {
    @Test func progressiveLessonsHaveExactEndpointTargetsAcrossEveryPresetAndNeck() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let loaded = LessonCatalogLoader().load(directory: repo.appendingPathComponent("Resources/Lessons"))
        #expect(loaded.issues.isEmpty)
        let goldens: [String: [(String, [Int], [Int])]] = [
            "slides": [("upward", [60,60], [62,62]), ("downward", [62,62], [60,60]), ("connected-phrase", [60,62,64,62], [62,64,62,60])],
            "hammer-ons": [("open-string", [64,64], [66,66]), ("fretted-pair", [60,60], [62,62]), ("legato-phrase", [60,62,64,60], [62,64,65,62])],
            "pull-offs": [("fretted-pair", [62,62], [60,60]), ("open-string", [66,66], [64,64]), ("legato-phrase", [64,62,65,62], [62,60,64,60])]
        ]
        for (slug, examples) in goldens {
            let lesson = try #require(loaded.lessons.first { $0.id == slug })
            #expect(lesson.manifest.practiceEntries.count == 3)
            #expect(lesson.manifest.learningTasks?.map(\.kind) == [.quiz, .selfPractice])
            for (index, tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for (activityID, bases, targets) in examples {
                        let activity = try lesson.resolveActivity(id: activityID, instrument: instrument)
                        let exercise = try #require(activity.exercises.first)
                        let events = try exercise.resolvedEvents(instrument: tuning).filter { $0.event.kind == .note }
                        #expect(events.compactMap { $0.pitches.first?.midi } == bases.map { $0 + shift })
                        #expect(events.compactMap(\.transitionTargetPitch?.midi) == targets.map { $0 + shift })
                        #expect(events.map { $0.event.startTick } == bases.indices.map { Int64($0) * 3840 })
                        #expect(events.allSatisfy { $0.event.positions.count == 1 && $0.event.techniquePositions.count == 2 && $0.event.durationTicks == 2880 && $0.event.pickStroke == .down && !$0.event.assessSustain })
                        #expect(events.allSatisfy { $0.event.pitchTransition?.startTick == 960 && $0.event.pitchTransition?.endTick == (slug == "slides" ? 1920 : 960) })
                        #expect(exercise.events.filter { $0.kind == .rest }.map(\.startTick) == bases.indices.map { Int64($0) * 3840 + 2880 })
                        #expect(exercise.durationTicks == Int64(bases.count) * 3840)
                        #expect(exercise.defaultBPM == 60 && exercise.minimumBPM == 40 && exercise.maximumBPM == 60)
                        #expect(try MonophonicCapability.limitations(exercise: exercise, instrument: tuning, bpm: 60).isEmpty)
                        #expect(try MonophonicCapability.limitations(exercise: exercise, instrument: tuning, bpm: 40).isEmpty)
                        #expect(activity.english.steps[activityID]?.body.contains("{{") == false)
                        #expect(activity.ukrainian.steps[activityID]?.body.contains("{{") == false)
                        #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                        if activityID == "open-string" {
                            #expect(activity.material.positioning?.enabled == false)
                            #expect(events.allSatisfy { $0.event.techniquePositions.contains { $0.string == 1 && $0.fret == 0 } })
                        }
                        if activity.material.positioning?.enabled == true {
                            for region in [7,12] {
                                let moved = try lesson.resolveActivity(id: activityID, instrument: instrument, choice: .region(firstFret: region))
                                let movedEvents = try moved.exercises[0].resolvedEvents(instrument: tuning).filter { $0.event.kind == .note }
                                #expect(movedEvents.compactMap { $0.pitches.first?.midi } == bases.map { $0 + shift })
                                #expect(movedEvents.compactMap(\.transitionTargetPitch?.midi) == targets.map { $0 + shift })
                                #expect(movedEvents.allSatisfy { event in event.event.techniquePositions.allSatisfy { (region...region+5).contains($0.fret) && $0.string == event.event.positions[0].string } })
                            }
                        }
                    }
                }
            }
        }
    }
}
