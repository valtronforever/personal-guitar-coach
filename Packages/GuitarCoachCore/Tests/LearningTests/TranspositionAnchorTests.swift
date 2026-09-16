import Foundation
import Testing
import Yams
import Domain
@testable import Learning

struct TranspositionAnchorTests {
    private func source(anchor: Int) throws -> LoadedLesson {
        let positions = try [FretPosition(string: 6, fret: 0), FretPosition(string: 5, fret: 2), FretPosition(string: 4, fret: 2)]
        let exercise = try Exercise(id: "power", events: [MusicalEvent(id: "chord", startTick: 0, durationTicks: 3840, kind: .note, positions: positions)],
            tuningPolicy: .fixedTuning, requiredTuning: .standard, assessmentMode: .displayOnly)
        let shape = try LessonSourceFingering(id: "shape", exerciseID: exercise.id, fingering: Fingering(positions: positions, mutedStrings: [1,2,3]))
        let material = LessonMaterial(id: "material", source: LessonMaterialSource(kind: .lesson), tonalRoot: try Pitch(midi: 40))
        let activity = LessonActivity(id: "play", materialID: material.id)
        let manifest = LessonManifest(id: "root-anchor", steps: [LessonStep(id: "show", kind: .fingering, exerciseID: exercise.id, activityID: activity.id, fingeringID: shape.id)],
            exercises: [exercise], adaptation: try LessonAdaptationDefinition(policy: .transposeIntervals, anchorString: anchor), materials: [material], activities: [activity], practiceEntries: [], fingerings: [shape])
        try LessonCatalogLoader().validate(manifest)
        func text(_ locale: String) -> LessonText {
            LessonText(lessonID: manifest.id, lessonVersion: manifest.version, locale: locale, title: "Open bass", summary: "Root and fifth", goal: "Compare", body: "Power chord",
                steps: ["show": LessonStepText(title: "{{root}}", body: "{{positions}}")], activities: ["play": LessonActivityText(title: "{{root}}", body: "{{notes}}")])
        }
        return LoadedLesson(manifest: manifest, english: text("en"), ukrainian: text("uk"))
    }
    @Test func openBassAnchorPreservesIntervalsAndDefaultAnchorPreservesExistingKeys() throws {
        let expectedRoots = [40,38,38,36,36,34,35,33]
        let oldRoots = [40,40,38,38,36,36,35,35]
        let names = ["E","D","D","C","C","B♭","B","A"]
        for (index,tuning) in TuningProfile.presets.enumerated() {
            for frets in GuitarFretCount.allCases {
                let instrument = try InstrumentProfile(tuning: tuning, frets: frets)
                for anchor in [1,6] {
                    let resolved = try source(anchor: anchor).resolveActivity(id: "play", instrument: instrument)
                    let exercise = try #require(resolved.exercises.first)
                    let pitches = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                    let root = anchor == 6 ? expectedRoots[index] : oldRoots[index]
                    #expect(pitches == [root,root+7,root+12])
                    let bass = try #require(exercise.events.first?.positions.first)
                    #expect(bass.string == 6 && bass.fret == (anchor == 6 || index.isMultiple(of: 2) ? 0 : 2))
                    if anchor == 6 {
                        #expect(resolved.english.activities["play"]?.title == names[index])
                        #expect(resolved.ukrainian.steps["show"]?.title == names[index])
                        #expect(Set(resolved.fingerings[0].fingering.positions) == Set(exercise.events[0].positions))
                    }
                }
            }
        }
    }
    @Test func anchorConfigurationValidatesAndDefaultEncodingRemainsStable() throws {
        let definition = try LessonAdaptationDefinition(policy: .transposeIntervals, anchorString: 6)
        #expect(try YAMLDecoder().decode(LessonAdaptationDefinition.self, from: YAMLEncoder().encode(definition)) == definition)
        #expect(try YAMLDecoder().decode(LessonAdaptationDefinition.self, from: "policy: transposeIntervals\n").anchorString == 1)
        let old = LessonAdaptationDefinition(policy: .transposeIntervals)
        #expect(!(String(data: try JSONEncoder().encode(old), encoding: .utf8) ?? "").contains("anchorString"))
        for yaml in ["policy: transposeIntervals\nanchorString: 0", "policy: transposeIntervals\nanchorString: 7", "policy: fretPattern\nanchorString: 6"] {
            #expect(throws: (any Error).self) { try YAMLDecoder().decode(LessonAdaptationDefinition.self, from: yaml) }
        }
    }
}
