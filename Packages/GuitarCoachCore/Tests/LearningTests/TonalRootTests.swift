import Foundation
import Testing
import Yams
import Domain
@testable import Learning

struct TonalRootTests {
    private func lesson(root: Pitch? = try! Pitch(midi: 45), policy: LessonAdaptationPolicy = .transposeIntervals,
                        fingeringOnly: Bool = false) throws -> LoadedLesson {
        let positions = try [FretPosition(string: 1, fret: 0), FretPosition(string: 2, fret: 1), FretPosition(string: 3, fret: 2)]
        let exercise = try Exercise(id: "inversion", events: [MusicalEvent(id: "chord", startTick: 0, durationTicks: 3840, kind: .note, positions: positions)],
            tuningPolicy: .fixedTuning, requiredTuning: .standard, assessmentMode: .displayOnly)
        let shape = try LessonSourceFingering(id: "shape", exerciseID: exercise.id, fingering: Fingering(positions: positions, mutedStrings: [4,5,6]))
        let source = fingeringOnly ? LessonMaterialSource(kind: .fingering, fingeringID: shape.id) : LessonMaterialSource(kind: .exercise, exerciseID: exercise.id)
        let material = LessonMaterial(id: "material", source: source, positioning: try PositioningPolicy(windowFrets: 6, allowedStarts: .auto), tonalRoot: root)
        let activity = LessonActivity(id: "explore", materialID: material.id, positionSelection: ActivityPositionSelection(mode: .learner, defaultChoice: .original))
        let step = LessonStep(id: "show", kind: fingeringOnly ? .fingering : .events, exerciseID: exercise.id,
            eventIDs: fingeringOnly ? [] : ["chord"], activityID: activity.id, fingeringID: fingeringOnly ? shape.id : nil)
        let manifest = LessonManifest(id: "tonal-root", steps: [step], exercises: [exercise], adaptation: LessonAdaptationDefinition(policy: policy),
            materials: [material], activities: [activity], practiceEntries: [], fingerings: [shape])
        try LessonCatalogLoader().validate(manifest)
        func text(_ locale: String) -> LessonText {
            LessonText(lessonID: manifest.id, lessonVersion: manifest.version, locale: locale, title: "Minor inversion", summary: "A chord", goal: "Compare", body: "Theory",
                steps: ["show": LessonStepText(title: "{{root}} minor", body: "First: {{first}}; positions: {{positions}}")],
                activities: [activity.id: LessonActivityText(title: "{{root}} minor", body: "First: {{first}}")])
        }
        return LoadedLesson(manifest: manifest, english: text("en"), ukrainian: text("uk"))
    }
    @Test func harmonicRootIsIndependentOfVoiceOrderFingeringAndPosition() throws {
        let expected = ["A", "A", "G", "G", "F", "F", "E", "E"]
        for fingeringOnly in [false, true] {
            let source = try lesson(fingeringOnly: fingeringOnly)
            for (tuning, root) in zip(TuningProfile.presets, expected) {
                for choice in [PositionChoice.original, .region(firstFret: 5)] {
                    let resolved = try source.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: tuning), choice: choice)
                    #expect(resolved.english.activities["explore"]?.title == root + " minor")
                    #expect(resolved.ukrainian.steps["show"]?.title == root + " minor")
                    let firstPitch = try #require(resolved.exercises.first?.resolvedEvents(instrument: tuning).first?.pitches.first)
                    #expect(firstPitch.midi % 12 != (source.manifest.materials[0].tonalRoot!.midi + tuning.strings[0].openPitch.midi - 64) % 12)
                }
            }
        }
    }
    @Test func yamlRoundTripPreservesExplicitRootAndMissingRootKeepsExistingBehavior() throws {
        let source = try lesson()
        let yaml = try YAMLEncoder().encode(source.manifest)
        let decoded = try YAMLDecoder().decode(LessonManifest.self, from: yaml)
        #expect(decoded.materials[0].tonalRoot?.midi == 45)
        try LessonCatalogLoader().validate(decoded)
        let legacy = try lesson(root: nil)
        #expect(try legacy.resolveActivity(id: "explore", instrument: InstrumentProfile()).english.activities["explore"]?.title == "E minor")
        #expect(throws: (any Error).self) { try lesson(policy: .fretPattern) }
    }
}
