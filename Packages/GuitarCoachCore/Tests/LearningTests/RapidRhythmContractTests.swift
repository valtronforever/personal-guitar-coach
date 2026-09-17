import Foundation
import Testing
import Domain
@testable import Learning

struct RapidRhythmContractTests {
    @Test func rapidModeIsOptInBoundedAndCannotSmuggleOtherTechniques() throws {
        let note = try MusicalEvent(id: "n", startTick: 0, durationTicks: 240, kind: .note, positions: [FretPosition(string: 3, fret: 5)])
        let rhythm = try Exercise(id: "rhythm", events: [note], defaultBPM: 100, assessmentMode: .rhythmOnly)
        try rhythm.validateForPractice(instrument: .standard, bpm: 100)
        #expect(throws: MusicError.unsupportedDuration) { try rhythm.validateForPractice(instrument: .standard, bpm: 101) }
        let ordinary = try Exercise(id: "ordinary", events: [note], defaultBPM: 100)
        #expect(throws: MusicError.unsupportedDuration) { try ordinary.validateForPractice(instrument: .standard, bpm: 100) }
        let low = try MusicalEvent(id: "low", startTick: 0, durationTicks: 240, kind: .note, positions: [FretPosition(string: 6, fret: 0)])
        let lowExercise = try Exercise(id: "low", events: [low], assessmentMode: .rhythmOnly)
        #expect(throws: MusicError.unsupportedPitch) { try lowExercise.validateForPractice(instrument: .standard, bpm: 60) }
        let change = try MusicalEvent(id: "other", startTick: 240, durationTicks: 240, kind: .note, positions: [FretPosition(string: 3, fret: 7)])
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "changing", events: [note,change], assessmentMode: .rhythmOnly) }
        let sustained = try MusicalEvent(id: "sustain", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 5)], assessSustain: true)
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "held", events: [sustained], assessmentMode: .rhythmOnly) }
        let chord = try MusicalEvent(id: "chord", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 5), FretPosition(string: 2, fret: 5)])
        #expect(throws: MusicError.unsupportedPolyphony) { try Exercise(id: "chord", events: [chord], assessmentMode: .rhythmOnly) }
        #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(rhythm)) == rhythm)
        let current = AssessmentParameters.current
        #expect(current.onsetUncertaintySeconds == 0.03 && current.version == "monophonic-assessment-3")
        #expect(AssessmentParameters.rhythmOnly.onsetUncertaintySeconds == 0.02)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(AssessmentParameters.rhythmOnly)) as? [String: Any])
        json["onsetUncertaintySeconds"] = 0
        #expect(throws: (any Error).self) { try JSONDecoder().decode(AssessmentParameters.self, from: JSONSerialization.data(withJSONObject: json)) }
    }
}
