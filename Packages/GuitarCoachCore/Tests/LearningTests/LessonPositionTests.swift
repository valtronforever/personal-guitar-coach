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
        return report.lessons.filter { $0.manifest.adaptation != nil }
    }
    @Test func seventhPositionHasIndependentGoldenFingeringAndUnchangedSoundingScale() throws {
        let source = try #require(course().first { $0.id == "c-major" })
        let position = try LessonPosition(firstFret: 7)
        let original = try source.adapted(to: .cStandard)
        let moved = try source.adapted(to: .cStandard, position: position)
        let exercise = moved.manifest.exercises[0]
        #expect(exercise.events.flatMap(\.positions).map(\.string) == [6,6,5,5,5,4,4,4,4,4,5,5,5,6,6])
        #expect(exercise.events.flatMap(\.positions).map(\.fret) == [8,10,7,8,10,7,9,10,9,7,10,8,7,10,8])
        #expect(try exercise.resolvedEvents(instrument: .standard).flatMap(\.pitches).map(\.midi) == [44,46,48,49,51,53,55,56,55,53,51,49,48,46,44])
        #expect(exercise.events.map(\.id) == original.manifest.exercises[0].events.map(\.id))
        #expect(exercise.events.map(\.startTick) == original.manifest.exercises[0].events.map(\.startTick))
        #expect(exercise.events.map(\.durationTicks) == original.manifest.exercises[0].events.map(\.durationTicks))
        #expect(moved.english.title == original.english.title && moved.english.body == original.english.body)
        #expect(moved.english.variant?.title == "A♭ major" && moved.ukrainian.variant?.title == "A♭ мажор")
        #expect(moved.manifest.version == original.manifest.version && exercise.version == original.manifest.exercises[0].version)
        for language in [LessonLanguage.en, .uk] {
            for step in moved.manifest.steps {
                let visual = try moved.visual(stepID: step.id, instrument: .standard)
                let text = try #require(moved.text(for: language).steps[step.id])
                for note in visual.positions {
                    #expect(position.contains(note.position, maximumFret: 24))
                    #expect(text.body.contains("(\(note.position.string)/\(note.position.fret))"))
                }
            }
        }
    }
    @Test func everyPresetAndNeckOffersOnlyCompletePitchPreservingRegions() throws {
        let lessons = try course(), seventh = try LessonPosition(firstFret: 7)
        for frets in GuitarFretCount.allCases {
            for tuning in TuningProfile.presets {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                for source in lessons {
                    let options = source.availablePositions(instrument: instrument)
                    if !source.supportsPositionSelection {
                        #expect(options.isEmpty)
                        #expect(throws: LessonAdaptationError.unplayable) { try source.adapted(to: instrument, position: seventh) }
                        continue
                    }
                    let original = try source.adapted(to: instrument)
                    for position in options {
                        let moved = try source.adapted(to: instrument, position: position)
                        for (before, after) in zip(original.manifest.exercises, moved.manifest.exercises) {
                            #expect(try before.resolvedEvents(instrument: tuning).flatMap(\.pitches) == after.resolvedEvents(instrument: tuning).flatMap(\.pitches))
                            #expect(after.events.flatMap(\.positions).allSatisfy { position.contains($0, maximumFret: frets.rawValue) })
                        }
                        #expect(moved.manifest.steps.compactMap(\.fingering).flatMap(\.positions).allSatisfy { position.contains($0, maximumFret: frets.rawValue) })
                    }
                    if source.id == "c-major" {
                        let standard = [TuningProfile.standard, .dStandard, .cStandard, .bStandard].contains(tuning)
                        #expect(options.contains(seventh) == standard)
                        if standard { _ = try source.adapted(to: instrument, position: seventh) }
                        else {
                            #expect(throws: LessonAdaptationError.unplayable) { try source.adapted(to: instrument, position: seventh) }
                            #expect(options.contains(try LessonPosition(firstFret: 3)))
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
        #expect(throws: LessonAdaptationError.unplayable) {
            try source.adapted(to: InstrumentProfile(frets: .nineteen), position: LessonPosition(firstFret: 24))
        }
        #expect(throws: LessonAdaptationError.unplayable) {
            try source.adapted(to: .cStandard, position: LessonPosition(firstFret: 12))
        }
    }
}
