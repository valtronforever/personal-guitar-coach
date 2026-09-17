import Foundation
import Testing
import Domain
@testable import Learning

struct ImprovisationCourseTests {
    @Test func motifsLandingsConversationSlotsAndSoloFormSurviveTuningAndPositionChanges() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let golden: [String: [String: [Int]]] = [
            "two-note-improvisation": ["seed": [60,63,60], "rhythm-change": [60,60,63,60], "third-pitch": [60,63,65,63,60]],
            "chord-tone-targeting": ["backdrop": [60,64,67,65,69,72,67,71,74,60,64,67], "roots": [60,65,67,60], "thirds": [64,69,71,64], "approach": [62,65,64,67,71,69,69,72,71,62,59,60]],
            "question-answer-phrases": ["call-one": [60,62,64], "call-two": [64,62,60], "conversation": [60,62,64,64,62,60,60,62,64,67,67,64,60]],
            "build-a-solo": ["opening": [60,63,65,63,60], "development": [60,60,63,65,63,65,67,70,67,70,72,70,67,65,63,65], "ending": [67,65,63,60], "complete-solo": [60,63,65,63,60,60,60,63,65,63,65,67,70,67,70,72,70,67,65,63,65,67,65,63,60]]
        ]
        var resolvedCount = 0
        for id in golden.keys.sorted() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            let expected = try #require(golden[id])
            #expect(Set(lesson.manifest.activities.map(\.id)) == Set(expected.keys))
            #expect(lesson.manifest.practiceEntries.count == (id == "chord-tone-targeting" ? 3 : 0))
            #expect(lesson.manifest.tasks.contains { $0.kind == .selfPractice })
            for (i,tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][i]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for activity in lesson.manifest.activities {
                        let choices = lesson.availableChoices(activityID: activity.id, instrument: instrument)
                        #expect(choices.count == (activity.id == "backdrop" ? 1 : 4))
                        for choice in choices {
                            let resolved = try lesson.resolveActivity(id: activity.id, instrument: instrument, choice: choice)
                            let exercise = try #require(resolved.exercises.first)
                            let source = try #require(lesson.manifest.exercises.first { $0.id == exercise.id })
                            let pitches = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                            #expect(pitches == expected[activity.id]!.map { $0 + shift })
                            #expect(exercise.events.map(\.startTick) == source.events.map(\.startTick))
                            #expect(exercise.events.map(\.durationTicks) == source.events.map(\.durationTicks))
                            #expect(zip(exercise.events, exercise.events.dropFirst()).allSatisfy { $0.endTick == $1.startTick })
                            #expect(exercise.events.flatMap(\.positions).allSatisfy(instrument.contains))
                            for text in [resolved.english, resolved.ukrainian] {
                                #expect(text.activities[activity.id]?.body.contains("{{") == false)
                            }
                            if exercise.assessmentMode == .monophonic {
                                for bpm in [40.0,60.0,90.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                                #expect(exercise.durationTicks == 15360)
                            }
                            if id == "question-answer-phrases", activity.id.hasPrefix("call-") {
                                #expect(exercise.assessmentMode == .displayOnly && exercise.durationTicks == 7680)
                                let answer = exercise.events.filter { $0.startTick >= 3840 }
                                #expect(answer.count == 1 && answer[0].kind == .rest && answer[0].durationTicks == 3840)
                            }
                            if id == "build-a-solo" {
                                let bars = ["opening":2,"development":4,"ending":2,"complete-solo":8][activity.id]!
                                #expect(exercise.durationTicks == Int64(bars)*3840 && exercise.assessmentMode == .displayOnly)
                            }
                            if activity.id == "approach" {
                                #expect(exercise.events.filter(\.assessSustain).map(\.id) == ["event-12"])
                                let targets = try exercise.resolvedEvents(instrument: tuning).filter { $0.event.startTick % 3840 == 1920 }.flatMap(\.pitches).map(\.midi)
                                #expect(targets == [64,69,71,60].map { $0+shift })
                            }
                            resolvedCount += 1
                        }
                    }
                }
            }
        }
        #expect(resolvedCount == 2120) // 13 movable examples × 4 choices + 1 fixed backdrop, each × 40 instruments.
    }
}
