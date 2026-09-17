import Foundation
import Testing
import Domain
@testable import Learning

struct HarmonicCourseTests {
    private func lesson() throws -> LoadedLesson {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first { $0.id == "harmonics" })
    }
    @Test func partialsAndTwoHandReachabilityRemainCorrectAcrossTuningsNecksAndRegions() throws {
        let lesson = try lesson()
        #expect(lesson.manifest.topic == .technique && lesson.manifest.practiceEntries.count == 6)
        let upper: [String: [Int]] = ["natural-octaves": [62,67,71], "natural-partials": [62,69,74],
            "artificial-octave": [60,72,60,72], "artificial-line": [70,72,74,72], "artificial-region": [72]]
        let bass = [[52,57,62],[50,57,62],[50,55,60],[48,55,60],[48,53,58],[46,53,58],[47,52,57],[45,52,57]]
        var count = 0
        for (index,tuning) in TuningProfile.presets.enumerated() {
            let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                for activity in lesson.manifest.activities {
                    let choices = lesson.availableChoices(activityID: activity.id, instrument: instrument)
                    let expectedChoices: [PositionChoice] = activity.id == "artificial-region"
                        ? [.original,.region(firstFret: 5)] + (frets.rawValue >= 22 ? [.region(firstFret: 10)] : []) : [.original]
                    #expect(choices == expectedChoices)
                    for choice in choices {
                        let resolved = try lesson.resolveActivity(id: activity.id, instrument: instrument, choice: choice)
                        let exercise = try #require(resolved.exercises.first)
                        let events = try exercise.resolvedEvents(instrument: tuning)
                        let expected = activity.id == "natural-bass" ? bass[index] : upper[activity.id]!.map { $0 + shift }
                        #expect(events.flatMap(\.pitches).map(\.midi) == expected)
                        #expect(exercise.events.flatMap(\.techniquePositions).allSatisfy(instrument.contains))
                        for bpm in [40.0,60.0,100.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                        let notes = exercise.events.filter { $0.kind == .note }
                        if activity.id == "natural-partials" {
                            #expect(notes.map { $0.positions[0].fret } == [12,7,5])
                            let open = 440 * pow(2, Double(50 + shift - 69) / 12)
                            let frequencies = try notes.flatMap { try $0.soundingFrequencies(in: tuning) }
                            for (actual,multiple) in zip(frequencies,[2.0,3.0,4.0]) { #expect(abs(actual-open*multiple) < 1e-9) }
                        }
                        if choice == .region(firstFret: 10) {
                            #expect(notes[0].positions == [try FretPosition(string: 4, fret: 10)])
                            #expect(notes[0].techniquePositions.last?.fret == 22)
                        }
                        let visual = try resolved.visual(stepID: activity.id)
                        #expect(visual.positions.contains { $0.role == .harmonicTouch })
                        if activity.id.hasPrefix("artificial") { #expect(visual.positions.contains { $0.role == .harmonicBase }) }
                        for language in [LessonLanguage.en,.uk] {
                            let text = resolved.text(for: language)
                            #expect(text.body == lesson.text(for: language).body)
                            #expect(!text.activities[activity.id]!.body.contains("{{"))
                            #expect(text.activities[activity.id]!.body.contains(language == .uk ? "дотик" : "touch"))
                            #expect(text.taskTexts == lesson.text(for: language).taskTexts)
                        }
                        #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                        count += 1
                    }
                }
            }
        }
        #expect(count == 296)
    }

    @Test func intervalPolicyCannotMoveNaturalNodesToCompensateForDropAndShapesCannotEraseRoles() throws {
        let source = try lesson(), m = source.manifest
        let changed = LessonManifest(id: m.id, steps: m.steps, exercises: m.exercises, adaptation: LessonAdaptationDefinition(policy: .transposeIntervals),
            materials: m.materials, activities: m.activities, practiceEntries: m.practiceEntries, learningTasks: m.learningTasks)
        let loaded = LoadedLesson(manifest: changed, english: source.english, ukrainian: source.ukrainian)
        #expect(try loaded.resolveActivity(id: "natural-bass", instrument: InstrumentProfile(tuning: .standard)).exercises[0].events[0].positions[0].fret == 12)
        #expect(throws: PositioningError.incompatibleTuning) { try loaded.resolveActivity(id: "natural-bass", instrument: InstrumentProfile(tuning: .dropD)) }
        // Unaffected strings retain their nodes under the same transposition policy.
        #expect(try loaded.resolveActivity(id: "natural-partials", instrument: InstrumentProfile(tuning: .dropD)).exercises[0].events[1].positions[0].fret == 7)
        let shape = try LessonSourceFingering(id: "lost-role", exerciseID: m.exercises[0].id, fingering: Fingering(positions: [FretPosition(string: 4, fret: 12)]))
        let shaped = LessonManifest(id: m.id, steps: m.steps, exercises: m.exercises, adaptation: m.adaptation,
            materials: m.materials, activities: m.activities, practiceEntries: m.practiceEntries, fingerings: [shape], learningTasks: m.learningTasks)
        #expect(throws: (any Error).self) { try LessonCatalogLoader().validateActivities(shaped) }
    }
}
