import Testing
import Domain

struct TuningEditingTests {
    @Test func namedPitchesIncludeAccidentalsAndOctaveBoundaries() throws {
        for (name, midi) in [("E2", 40), ("D2", 38), ("Bb3", 58), ("F♯4", 66), ("C♭4", 59), ("B#3", 60), (" c#4 ", 61), ("C-1", 0), ("G9", 127)] {
            #expect(try Pitch.parse(name).midi == midi)
        }
        for name in ["", "H2", "E", "C-2", "A9", "C9999999999999999999999999", "F##4", "nan"] {
            #expect(throws: MusicError.self) { try Pitch.parse(name) }
        }
    }

    @Test func editsPreserveIdentityAndAdvanceOnlyChangedRevision() throws {
        let original = try TuningProfile(id: "test-custom", name: "Original", strings: TuningProfile.dropD.strings)
        let renamed = try original.revised(name: "New name", strings: original.strings, referenceA4: 442)
        #expect(renamed.id == original.id)
        #expect(renamed.revision == 2)
        #expect(original.revision == 1)
        #expect(try renamed.revised(name: renamed.name, strings: renamed.strings, referenceA4: 442) == renamed)
        let maxRevision = try TuningProfile(id: "test-custom", revision: .max, name: "Full", strings: original.strings)
        #expect(throws: MusicError.invalidTuning) { try maxRevision.revised(name: "Changed", strings: original.strings, referenceA4: 440) }
    }

    @Test func displayAndArchivalValidationAreIndependentOfCurrentAudioRange() throws {
        let tuning = try TuningProfile(id: "very-low", name: "Display example", strings: (1...6).map { try TunedString(number: $0, openPitch: Pitch(midi: 12)) })
        let exercise = try Exercise(id: "low", events: [MusicalEvent(id: "one", startTick: 0, durationTicks: 960, kind: .note,
                                                                   positions: [FretPosition(string: 6, fret: 0)])])
        #expect(try exercise.resolvedEvents(instrument: tuning).first?.pitches.first?.midi == 12)
        try exercise.validatePracticeSnapshot(instrument: tuning, bpm: 60)
        #expect(throws: MusicError.unsupportedPitch) { try exercise.validateForPractice(instrument: tuning, bpm: 60) }
    }
}
