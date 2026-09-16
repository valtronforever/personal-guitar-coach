import Testing
@testable import Domain

@Suite struct MonophonicCapabilityTests {
    @Test func durationTempoMatrixAllowsPreviewButRejectsUnsupportedGrading() throws {
        for (ticks, maximumBPM) in [(Int64(960), 200.0), (480, 150), (240, 75)] {
            let exercise = try Exercise(id: "duration", events: [.init(id: "note", startTick: 0, durationTicks: ticks,
                kind: .note, positions: [.init(string: 6, fret: 0)])])
            try exercise.validateForPractice(instrument: .standard, bpm: maximumBPM)
            if maximumBPM < 200 {
                let unsupportedBPM = maximumBPM + 1
                try exercise.validatePracticeSnapshot(instrument: .standard, bpm: unsupportedBPM)
                #expect(try exercise.resolvedEvents(instrument: .standard).count == 1)
                #expect(throws: MusicError.unsupportedDuration) { try exercise.validateForPractice(instrument: .standard, bpm: unsupportedBPM) }
                let limitation = try #require(MonophonicCapability.limitations(exercise: exercise, instrument: .standard, bpm: unsupportedBPM).first)
                #expect(limitation.eventID == "note" && limitation.reason == .duration)
            }
        }
    }

    @Test func everyPresetOpenStringIsEligibleButBelowFloorReferenceRemainsExplicit() throws {
        for tuning in TuningProfile.presets {
            for string in tuning.strings {
                #expect(MonophonicCapability.supportsTarget(string.openPitch, referenceA4: tuning.referenceA4))
                let note = try MusicalEvent(id: "open", startTick: 0, durationTicks: 960, kind: .note,
                    positions: [FretPosition(string: string.number, fret: 0)])
                try Exercise(id: "preset-open", events: [note]).validateForPractice(instrument: tuning, bpm: 60)
            }
        }
        let low = try TuningProfile(id: "low-reference", name: "A1 below 55 Hz", strings: TuningProfile.dropA.strings, referenceA4: 400)
        #expect(!MonophonicCapability.supportsTarget(try Pitch(midi: 33), referenceA4: low.referenceA4))
        #expect(!MonophonicCapability.supportsTarget(try Pitch(midi: 32), referenceA4: 480))
        let note = try MusicalEvent(id: "low", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)])
        let exercise = try Exercise(id: "low-reference", events: [note])
        try exercise.validatePracticeSnapshot(instrument: low, bpm: 60) // Reading saved evidence is independent of current grading.
        #expect(throws: MusicError.unsupportedPitch) { try exercise.validateForPractice(instrument: low, bpm: 60) }
        #expect(try MonophonicCapability.limitations(exercise: exercise, instrument: low, bpm: 60).first?.reason == .frequency)
    }

    @Test func referenceAndEveryResolvedNoteEnterCapabilityValidation() throws {
        let tuning = try TuningProfile(id: "range", revision: 1, name: "Wide range",
            strings: [88, 59, 55, 50, 45, 36].enumerated().map { try TunedString(number: $0.offset + 1, openPitch: Pitch(midi: $0.element)) }, referenceA4: 480)
        let exercise = try Exercise(id: "range", events: [
            .init(id: "low", startTick: 0, durationTicks: 960, kind: .note, positions: [.init(string: 6, fret: 0)]),
            .init(id: "high", startTick: 960, durationTicks: 960, kind: .note, positions: [.init(string: 1, fret: 0)])])
        try exercise.validateForPractice(instrument: tuning, bpm: 200)
        #expect(MonophonicCapability.sampleRates == [44100, 48000])
    }
}
