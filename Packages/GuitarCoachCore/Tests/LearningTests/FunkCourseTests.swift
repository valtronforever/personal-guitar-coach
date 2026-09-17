import Foundation
import Testing
import Domain
@testable import Learning

struct FunkCourseTests {
    private func lesson() throws -> LoadedLesson {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first { $0.id == "funk-study" })
    }
    @Test func funkPatternsKeepChordsScratchesAndSilencesDistinctAcrossTuningsAndNecks() throws {
        let lesson = try lesson()
        let patterns = ["chord-cutoff": "C---C---C---C---", "muted-grid": "xxxx----x-x-xx--",
            "chord-and-scratch": "C-xx-xCx-xCx--x-", "syncopated-change": "x--C-xC-x--C-x--x--F-xF-x--F-x--",
            "space-study": "C-xx-xCx-xCx--x-C-xx-xCx-xCx--x-F-x-------Fx----C---------------"]
        #expect(lesson.manifest.practiceEntries.isEmpty && lesson.manifest.curriculum?.ordinal == 102)
        var cases = 0
        for (index,tuning) in TuningProfile.presets.enumerated() {
            let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                for activity in lesson.manifest.activities {
                    let pattern = Array(try #require(patterns[activity.id]))
                    #expect(lesson.availableChoices(activityID: activity.id, instrument: instrument) == [.original])
                    let snapshot = try lesson.resolveActivity(id: activity.id, instrument: instrument)
                    let exercise = try #require(snapshot.exercises.first)
                    #expect(exercise.durationTicks == Int64(pattern.count * 240) && exercise.events.count == pattern.count)
                    #expect(exercise.assessmentMode == .displayOnly)
                    #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm: 80) }
                    for (slot,resolved) in try exercise.resolvedEvents(instrument: tuning).enumerated() {
                        let event = resolved.event, symbol = pattern[slot]
                        #expect(event.startTick == Int64(slot * 240) && event.durationTicks == 240)
                        if symbol == "x" {
                            #expect(event.kind == .note && event.positions.isEmpty && resolved.pitches.isEmpty)
                            #expect(event.mutedAttack?.strings == [1,2,3] && event.pickingDirection == (slot % 2 == 0 ? .down : .up))
                        } else if symbol == "-" {
                            #expect(event.kind == .rest && event.mutedAttack == nil && resolved.pitches.isEmpty)
                        } else {
                            #expect(event.mutedAttack == nil && event.strum?.spreadTicks == 30)
                            #expect(resolved.pitches.map(\.midi) == (symbol == "C" ? [58,64,67] : [57,63,65]).map { $0 + shift })
                            #expect(event.positions.allSatisfy(instrument.contains))
                        }
                    }
                    let visual = try snapshot.visual(stepID: activity.id)
                    #expect(visual.mutedStrings == (activity.id == "chord-cutoff" ? [] : [1,2,3]))
                    if activity.id == "muted-grid" { #expect(visual.positions.isEmpty) }
                    for language in [LessonLanguage.en,.uk] {
                        #expect(snapshot.text(for: language).body == lesson.text(for: language).body)
                        #expect(!snapshot.text(for: language).activities[activity.id]!.body.contains("{{"))
                    }
                    cases += 1
                }
            }
        }
        #expect(cases == 200)
        let context = LessonTaskContext(lessonVersion: 1, instrument: InstrumentProfile())
        let task = try #require(lesson.manifest.tasks.first { $0.kind == .selfPractice })
        #expect(!task.isComplete(LessonTaskProgress(context: context, checkedIDs: ["pulse"]), context: context))
        #expect(lesson.manifest.tasks.first { $0.kind == .quiz }?.correctOptionID == "scratch")
    }
    @Test func textNamesMutedStringsWithoutInventingPitchesAndShapesCannotEraseTheAttack() throws {
        let source = try lesson(), m = source.manifest
        func textWithTokens(_ text: LessonText) throws -> LessonText {
            var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(text)) as? [String: Any])
            var activities = try #require(object["activities"] as? [String: [String: Any]])
            activities["muted-grid"]?["body"] = "{{sequence}} | {{positions}}"
            object["activities"] = activities
            return try JSONDecoder().decode(LessonText.self, from: JSONSerialization.data(withJSONObject: object))
        }
        let changed = try LoadedLesson(manifest: m, english: textWithTokens(source.english), ukrainian: textWithTokens(source.ukrainian))
        let snapshot = try changed.resolveActivity(id: "muted-grid", instrument: InstrumentProfile(tuning: .cStandard))
        for language in [LessonLanguage.en,.uk] {
            let body = try #require(snapshot.text(for: language).activities["muted-grid"]?.body)
            #expect(body.contains(language == .en ? "muted strings: 1, 2, 3" : "приглушені струни: 1, 2, 3"))
            #expect(!body.contains("{{") && !body.contains("A♭") && body.components(separatedBy: "×").count == 17)
        }
        let exercise = try #require(m.exercises.first { $0.id.hasSuffix("chord-and-scratch") })
        let shape = try LessonSourceFingering(id: "lost-attack", exerciseID: exercise.id, fingering: Fingering(positions: [FretPosition(string: 3, fret: 3)]))
        let shaped = LessonManifest(id: m.id, steps: m.steps, exercises: m.exercises, adaptation: m.adaptation,
            materials: m.materials, activities: m.activities, practiceEntries: m.practiceEntries, fingerings: [shape], learningTasks: m.learningTasks)
        #expect(throws: (any Error).self) { try LessonCatalogLoader().validateActivities(shaped) }
    }
}
