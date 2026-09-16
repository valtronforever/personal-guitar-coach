import Foundation
import Testing
import Domain
@testable import Audio

struct StrumReferenceTests {
    private func exercise(_ direction: StrumDirection) throws -> Exercise {
        // Deliberately scrambled: direction must follow strings, not author array order.
        try Exercise(id: "strum", events: [MusicalEvent(id: "chord", startTick: 0, durationTicks: 1920, kind: .note,
            positions: [FretPosition(string: 3, fret: 2), FretPosition(string: 1, fret: 0), FretPosition(string: 2, fret: 1)],
            strum: StrumPattern(direction: direction, spreadTicks: 120))], assessmentMode: .displayOnly)
    }
    @Test func referenceUsesMusicalSpreadStringOrderAndChunkIndependentSamples() throws {
        for rate in [44100.0, 48000.0] {
            for direction in [StrumDirection.down, .up] {
                let exercise = try exercise(direction)
                let plan = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    countInBars: 0, clickEnabled: false, toneVolume: 1), sampleRate: rate)
                let audio = try plan.render(startFrame: 0, count: 12000)
                let chunks = try plan.render(startFrame: 0, count: 1711) + plan.render(startFrame: 1711, count: 10289)
                #expect(audio == chunks)
                let midi = direction == .down ? [57, 60, 64] : [64, 60, 57]
                // Independent three-voice renderer: first-to-last spread = 120/960 seconds at 60 BPM.
                for sample in stride(from: 0, to: 12000, by: 37) {
                    var expected = 0.0
                    for rank in 0..<3 {
                        let onset = Int((Double(rank) * 60 / 960 * rate).rounded())
                        guard sample >= onset else { continue }
                        let age = Double(sample - onset)
                        let frequency = 440 * pow(2, Double(midi[rank] - 69) / 12)
                        expected += sin(2 * .pi * frequency * age / rate) * 0.2 / 3 * min(1, age / (rate * 0.005))
                    }
                    #expect(abs(Double(audio[sample]) - expected) < 1e-6)
                }
                let sought = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    startTick: 480, countInBars: 0, clickEnabled: false, toneVolume: 1), sampleRate: rate)
                let resumed = try sought.render(startFrame: 0, count: 2000)
                let continuous = try plan.render(startFrame: Int64(rate * 0.5), count: 2000)
                // Absolute tick rounding may shift one voice by one sample after changing epoch (44.1 kHz).
                // Bound that phase difference; restarting an envelope/strum would exceed it substantially.
                let oneSampleBound = midi.reduce(0.0) { $0 + 2 * .pi * 440 * pow(2, Double($1 - 69) / 12) / rate * 0.2 / 3 }
                #expect(zip(resumed, continuous).allSatisfy { abs(Double($0 - $1)) <= oneSampleBound })
                let practice = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
                #expect(try practice.render(startFrame: 0, count: 12000).allSatisfy { $0 == 0 })
                #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: .standard, bpm: 60) }
            }
        }
    }
    @Test func invalidPatternsAreRejectedAndOldEncodingIsUnchanged() throws {
        let event = try exercise(.down).events[0]
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: JSONEncoder().encode(event)) == event)
        #expect(throws: MusicError.invalidTime) { try StrumPattern(direction: .down, spreadTicks: 0) }
        #expect(throws: MusicError.invalidTime) { try StrumPattern(direction: .down, spreadTicks: 961) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "n", startTick: 0, durationTicks: 120, kind: .note,
            positions: event.positions, strum: StrumPattern(direction: .down)) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "n", startTick: 0, durationTicks: 960, kind: .note,
            positions: [event.positions[0]], strum: StrumPattern(direction: .down)) }
        let normal = try MusicalEvent(id: "n", startTick: 0, durationTicks: 960, kind: .note, positions: event.positions)
        #expect(!(String(data: try JSONEncoder().encode(normal), encoding: .utf8) ?? "").contains("strum"))
    }
}
