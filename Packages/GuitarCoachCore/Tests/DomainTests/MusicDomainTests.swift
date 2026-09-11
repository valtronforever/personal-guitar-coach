import Foundation
import Testing
@testable import Domain

@Suite("Musical domain invariants")
struct MusicDomainTests {
    @Test func cStandardUsesSoundingPitchesAcrossEveryStringAndFret() throws {
        #expect(TuningProfile.cStandard.strings.map { $0.openPitch.midi } == [60, 55, 51, 46, 41, 36])
        #expect(TuningProfile.presets.map(\.id) == ["standard", "drop-d", "d-standard", "c-standard"])
        #expect(TuningProfile.cStandard.strings.reversed().map { $0.openPitch.name(spelling: TuningProfile.cStandard.preferredSpelling) } == ["C2", "F2", "B♭2", "E♭3", "G3", "C4"])
        for string in 1...6 {
            for fret in 0...24 {
                let position = try FretPosition(string: string, fret: fret)
                #expect(try TuningProfile.cStandard.pitch(at: position).midi == TuningProfile.standard.pitch(at: position).midi - 4)
            }
        }
        #expect(try abs(TuningProfile.cStandard.frequency(at: FretPosition(string: 6, fret: 0)) - 65.4063913251) < 0.000001)
        let equivalent = try TuningProfile(id: "custom-c", name: "Custom C", strings: TuningProfile.cStandard.strings, referenceA4: 442)
        #expect(equivalent.preferredSpelling == .flats)
    }
    @Test(arguments: [0, 24, 36, 38, 40, 45, 50, 55, 59, 60, 64, 69, 88, 103, 127])
    func pitchFrequencyRoundTrip(midi: Int) throws {
        let pitch = try Pitch(midi: midi)
        for reference in [400.0, 440.0, 442.0, 480.0] {
            let hz = try pitch.frequency(referenceA4: reference)
            #expect(try Pitch.nearest(to: hz, referenceA4: reference) == pitch)
            #expect(abs(try pitch.cents(from: hz, referenceA4: reference)) < 1e-8)
        }
    }

    @Test func pitchNamesAndSignedCents() throws {
        #expect(try Pitch(midi: 60).name() == "C4")
        #expect(try Pitch(midi: 0).name() == "C-1")
        #expect(try Pitch(midi: 70).name(spelling: .flats) == "B♭4")
        let a = try Pitch(midi: 69)
        #expect(abs(try a.cents(from: 440 * pow(2, 25.0 / 1200)) - 25) < 1e-8)
        #expect(abs(try a.cents(from: 440 * pow(2, -25.0 / 1200)) + 25) < 1e-8)
        #expect(abs(try a.cents(from: 880) - 1200) < 1e-8)
    }

    @Test func invalidNumericValuesCannotBecomeNotesOrTicks() {
        for hz in [0, -1, Double.nan, Double.infinity] {
            #expect(throws: MusicError.self) { try Pitch.nearest(to: hz) }
        }
        #expect(throws: MusicError.invalidPitch) { try Pitch(midi: 128) }
        #expect(throws: MusicError.invalidReference) { try Pitch(midi: 69).frequency(referenceA4: 0) }
        #expect(throws: MusicError.invalidReference) { try Pitch(midi: 69).frequency(referenceA4: .nan) }
        #expect(throws: MusicError.invalidTime) { try MusicalTime.ticks(forSeconds: .greatestFiniteMagnitude, bpm: 60) }
        #expect(throws: MusicError.invalidTime) { try MusicalTime.ticks(forSeconds: -1, bpm: 60) }
        #expect(throws: MusicError.invalidTempo) { try MusicalTime.seconds(forTicks: 960, bpm: .nan) }
    }

    @Test func presetMappingAndAmbiguousStringPositions() throws {
        let standard = TuningProfile.standard
        #expect(standard.strings.map(\.number) == [1, 2, 3, 4, 5, 6])
        #expect(standard.strings.reversed().map(\.openPitch.midi) == [40, 45, 50, 55, 59, 64])
        #expect(TuningProfile.dropD.strings.reversed().map(\.openPitch.midi) == [38, 45, 50, 55, 59, 64])
        #expect(TuningProfile.dStandard.strings.reversed().map(\.openPitch.midi) == [38, 43, 48, 53, 57, 62])
        #expect(try standard.pitch(at: FretPosition(string: 6, fret: 0)).midi == 40)
        #expect(try standard.pitch(at: FretPosition(string: 6, fret: 12)).midi == 52)
        #expect(try standard.pitch(at: FretPosition(string: 1, fret: 24)).midi == 88)
        #expect(try standard.pitch(at: FretPosition(string: 6, fret: 24)) == standard.pitch(at: FretPosition(string: 1, fret: 0)))
    }

    @Test func validateFingeringAndMutedStrings() throws {
        let position = try FretPosition(string: 5, fret: 2)
        let shape = try Fingering(positions: [position], mutedStrings: [6], fingerNumbers: [5: 2])
        #expect(shape.mutedStrings == [6] && shape.positions.count == 1)
        #expect(throws: MusicError.invalidString) { try FretPosition(string: 7, fret: 0) }
        #expect(throws: MusicError.invalidFret) { try FretPosition(string: 1, fret: -1) }
        #expect(throws: MusicError.invalidFret) { try FretPosition(string: 1, fret: 25) }
        #expect(throws: MusicError.invalidFingering) { try Fingering(positions: [position], mutedStrings: [5]) }
        #expect(throws: MusicError.invalidFingering) { try Fingering(positions: [position, position]) }
        #expect(throws: MusicError.invalidFingering) { try Fingering(positions: [FretPosition(string: 1, fret: 0)], fingerNumbers: [1: 1]) }
    }

    @Test func timingAndRestsUseOneTimeline() throws {
        #expect(try MusicalTime.seconds(forTicks: 960, bpm: 120) == 0.5)
        #expect(try MusicalTime.ticks(forSeconds: 0.125, bpm: 120) == 240)
        #expect(TimeSignature.threeFour.ticksPerBar == 2880)
        #expect(TimeSignature.fourFour.ticksPerBar == 3840)
        let exercise = try Exercise(id: "rest-example", events: [
            note("first", 0),
            MusicalEvent(id: "rest", startTick: 960, durationTicks: 960, kind: .rest),
            note("last", 1920)
        ])
        let resolved = try exercise.resolvedEvents(instrument: .standard)
        #expect(exercise.noteCount == 2 && exercise.durationTicks == 2880)
        #expect(resolved[1].pitches.isEmpty && resolved[1].event.durationTicks == 960)
    }

    @Test func tuningPolicyAffectsResolutionWithoutSilentTransposition() throws {
        let event = try note("low", 0)
        let follows = try Exercise(id: "follows", events: [event])
        #expect(try follows.resolvedEvents(instrument: .dropD)[0].pitches[0].midi == 38)
        let fixed = try Exercise(id: "fixed", events: [event], tuningPolicy: .fixedTuning, requiredTuning: .standard)
        #expect(try fixed.resolvedEvents(instrument: .dropD)[0].pitches[0].midi == 40)
        #expect(throws: MusicError.tuningMismatch) { try fixed.validateForPractice(instrument: .dropD, bpm: 60) }
        let renamed = try TuningProfile(id: "mine", name: "My tuning", strings: TuningProfile.standard.strings)
        try fixed.validateForPractice(instrument: renamed, bpm: 60)
        let alternateA4 = try TuningProfile(id: "442", name: "442 Hz", strings: renamed.strings, referenceA4: 442)
        #expect(throws: MusicError.tuningMismatch) { try fixed.validateForPractice(instrument: alternateA4, bpm: 60) }
    }

    @Test func chordsAreDisplayableButNeverMonophonicScores() throws {
        let chord = try MusicalEvent(id: "em", startTick: 0, durationTicks: 960, kind: .note,
                                    positions: [FretPosition(string: 6, fret: 0), FretPosition(string: 5, fret: 2)])
        #expect(throws: MusicError.unsupportedPolyphony) { try Exercise(id: "bad", events: [chord]) }
        let display = try Exercise(id: "shape", events: [chord], assessmentMode: .displayOnly)
        #expect(try display.resolvedEvents(instrument: .standard)[0].pitches.count == 2)
        #expect(throws: MusicError.displayOnlyExercise) { try display.validateForPractice(instrument: .standard, bpm: 60) }
    }

    @Test func invalidSequencesCannotReachAssessment() throws {
        #expect(throws: MusicError.invalidTime) { try MusicalEvent(id: "overflow", startTick: .max, durationTicks: 1, kind: .rest) }
        #expect(throws: MusicError.invalidTime) { try MusicalEvent(id: "zero", startTick: 0, durationTicks: 0, kind: .rest) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "empty", startTick: 0, durationTicks: 960, kind: .note) }
        #expect(throws: MusicError.duplicateIdentifier) { try Exercise(id: "dup", events: [note("a", 0), note("a", 960)]) }
        #expect(throws: MusicError.overlappingEvents) { try Exercise(id: "overlap", events: [note("a", 0), note("b", 480)]) }
        #expect(throws: MusicError.overlappingEvents) { try Exercise(id: "reverse", events: [note("a", 960), note("b", 0)]) }
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "empty", events: []) }
        #expect(throws: MusicError.invalidExercise) {
            try Exercise(id: "rests", events: [MusicalEvent(id: "r", startTick: 0, durationTicks: 960, kind: .rest)])
        }
        #expect(throws: MusicError.invalidTuning) { try Exercise(id: "no-profile", events: [note("a", 0)], tuningPolicy: .fixedTuning) }
        #expect(throws: MusicError.invalidTempo) { try Exercise(id: "tempo", events: [note("a", 0)], minimumBPM: 120, maximumBPM: 60) }
    }

    @Test func decodingCannotBypassValidation() throws {
        let decoder = JSONDecoder()
        #expect(throws: MusicError.invalidFret) { try decoder.decode(FretPosition.self, from: Data(#"{"string":1,"fret":25}"#.utf8)) }
        #expect(throws: MusicError.invalidPitch) { try decoder.decode(Pitch.self, from: Data(#"{"midi":999}"#.utf8)) }
        let exercise = try Exercise(id: "valid", events: [note("a", 0)])
        let data = try JSONEncoder().encode(exercise)
        #expect(try decoder.decode(Exercise.self, from: data) == exercise)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["ppq"] = 480
        #expect(throws: MusicError.invalidExercise) { try decoder.decode(Exercise.self, from: JSONSerialization.data(withJSONObject: object)) }
        var tuning = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(TuningProfile.standard)) as? [String: Any])
        tuning["strings"] = []
        #expect(throws: MusicError.invalidTuning) { try decoder.decode(TuningProfile.self, from: JSONSerialization.data(withJSONObject: tuning)) }
        tuning["strings"] = Array(repeating: ["number": 1, "openPitch": ["midi": 64]] as [String: Any], count: 6)
        #expect(throws: MusicError.invalidTuning) { try decoder.decode(TuningProfile.self, from: JSONSerialization.data(withJSONObject: tuning)) }
    }

    private func note(_ id: String, _ start: Int64) throws -> MusicalEvent {
        try MusicalEvent(id: id, startTick: start, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)])
    }
}
