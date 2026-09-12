import Foundation
import Testing
import Domain
@testable import Learning

struct LessonPositionTests {
    private func course() throws -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return report.lessons.filter { $0.manifest.adaptation != nil && $0.id != "same-notes-new-position" }
    }
    @Test func seventhPositionHasIndependentGoldenFingeringAndUnchangedSoundingScale() throws {
        let source = try #require(course().first { $0.id == "c-major" })
        let position = PositionChoice.region(firstFret: 7)
        let original = try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: .cStandard))
        let moved = try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: .cStandard), choice: position)
        let exercise = moved.exercises[0]
        #expect(exercise.events.flatMap(\.positions).map(\.string) == [6,6,5,5,5,4,4,4,4,4,5,5,5,6,6])
        #expect(exercise.events.flatMap(\.positions).map(\.fret) == [8,10,7,8,10,7,9,10,9,7,10,8,7,10,8])
        #expect(try exercise.resolvedEvents(instrument: .standard).flatMap(\.pitches).map(\.midi) == [44,46,48,49,51,53,55,56,55,53,51,49,48,46,44])
        #expect(exercise.events.map(\.id) == original.exercises[0].events.map(\.id))
        #expect(exercise.events.map(\.startTick) == original.exercises[0].events.map(\.startTick))
        #expect(exercise.events.map(\.durationTicks) == original.exercises[0].events.map(\.durationTicks))
        #expect(moved.english.title == original.english.title && moved.english.body == original.english.body)
        #expect(moved.english.activities["lesson"]?.title == "A♭ major" && moved.ukrainian.activities["lesson"]?.title == "A♭ мажор")
        #expect(moved.lessonVersion == original.lessonVersion && exercise.version == original.exercises[0].version)
        for language in [LessonLanguage.en, .uk] {
            for step in moved.steps {
                let visual = try moved.visual(stepID: step.id)
                let text = try #require(moved.text(for: language).steps[step.id])
                for note in visual.positions {
                    #expect(try #require(try source.positioningPolicy(activityID: "lesson")?.region(for: position)).contains(note.position, maximumFret: 24))
                    #expect(text.body.contains("(\(note.position.string)/\(note.position.fret))"))
                }
            }
        }
    }
    @Test func everyPresetAndNeckOffersOnlyCompletePitchPreservingRegions() throws {
        let lessons = try course(), seventh = PositionChoice.region(firstFret: 7)
        for frets in GuitarFretCount.allCases {
            for tuning in TuningProfile.presets {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                for source in lessons {
                    let options = source.availableChoices(activityID: "lesson", instrument: instrument)
                    if source.positioningPolicy(activityID: "lesson")?.enabled != true {
                        #expect(options == [.original])
                        #expect(throws: PositioningError.forbiddenChoice) { try source.resolveActivity(id: "lesson", instrument: instrument, choice: seventh) }
                        continue
                    }
                    let original = try source.resolveActivity(id: "lesson", instrument: instrument)
                    for position in options {
                        let moved = try source.resolveActivity(id: "lesson", instrument: instrument, choice: position)
                        for (before, after) in zip(original.exercises, moved.exercises) {
                            #expect(try before.resolvedEvents(instrument: tuning).flatMap(\.pitches) == after.resolvedEvents(instrument: tuning).flatMap(\.pitches))
                            #expect(after.events.flatMap(\.positions).allSatisfy { (try? source.positioningPolicy(activityID: "lesson")?.region(for: position))?.contains($0, maximumFret: frets.rawValue) ?? true })
                        }
                        #expect(moved.fingerings.map(\.fingering).flatMap(\.positions).allSatisfy { (try? source.positioningPolicy(activityID: "lesson")?.region(for: position))?.contains($0, maximumFret: frets.rawValue) ?? true })
                    }
                    if source.id == "c-major" {
                        let standard = [TuningProfile.standard, .dStandard, .cStandard, .bStandard].contains(tuning)
                        #expect(options.contains(seventh) == standard)
                        if standard { _ = try source.resolveActivity(id: "lesson", instrument: instrument, choice: seventh) }
                        else {
                            #expect(throws: PositioningError.regionUnplayable) { try source.resolveActivity(id: "lesson", instrument: instrument, choice: seventh) }
                            #expect(options.contains(PositionChoice.region(firstFret: 3)))
                        }
                    }
                }
            }
        }
    }
    @Test func invalidAndOutOfReachRegionsFailWithoutChangingOctaves() throws {
        #expect(throws: MusicError.invalidFret) { try LessonPosition(firstFret: -1) }
        #expect(throws: MusicError.invalidFret) { try LessonPosition(firstFret: 25) }
        #expect(throws: MusicError.invalidFret) { try JSONDecoder().decode(LessonPosition.self, from: Data(#"{"firstFret":25}"#.utf8)) }
        let source = try #require(course().first { $0.id == "c-major" })
        #expect(throws: PositioningError.beyondFretCount) {
            try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(frets: .nineteen), choice: .region(firstFret: 24))
        }
        #expect(throws: PositioningError.regionUnplayable) {
            try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: .cStandard), choice: .region(firstFret: 12))
        }
    }
}
