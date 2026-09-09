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
