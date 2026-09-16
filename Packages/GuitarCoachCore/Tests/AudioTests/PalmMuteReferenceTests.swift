import Foundation
import Testing
import Domain
@testable import Audio

struct PalmMuteReferenceTests {
    private func exercise(muted: Bool, strum: Bool = false) throws -> Exercise {
        let positions = try strum ? [FretPosition(string: 6, fret: 3), FretPosition(string: 5, fret: 5)] : [FretPosition(string: 6, fret: 3)]
        return try Exercise(id: "mute", events: [MusicalEvent(id: "n", startTick: 0, durationTicks: 1920,
            kind: .note, positions: positions, strum: strum ? StrumPattern(direction: .down) : nil, palmMuted: muted)], assessmentMode: .displayOnly)
    }
    @Test func mutedReferenceDecaysWithoutChangingAttackPitchOrRestartingOnSeek() throws {
        for rate in [44100.0,48000.0] {
            for strum in [false,true] {
                let target = try exercise(muted: true, strum: strum)
                let plan = try TransportPlan(request: TransportRequest(exercise: target, tuning: .standard, bpm: 60, countInBars: 0, clickEnabled: false, toneVolume: 1), sampleRate: rate)
                let samples = try plan.render(startFrame: 0, count: 20000)
                #expect(samples == (try plan.render(startFrame: 0, count: 991) + plan.render(startFrame: 991, count: 19009)))
                for sample in stride(from: 0, to: 20000, by: 31) {
                    let pitches = strum ? [43,50] : [43]
                    var expected = 0.0
                    for (voice,midi) in pitches.enumerated() {
                        let start = Int((Double(voice) * 0.125 * rate).rounded())
                        guard sample >= start else { continue }
                        let seconds = Double(sample - start) / rate
                        let hz = 440 * pow(2, Double(midi - 69) / 12)
                        expected += sin(2 * .pi * hz * seconds) * 0.2 / Double(pitches.count) * min(1, seconds / 0.005) * exp(-seconds / 0.09)
                    }
                    #expect(abs(Double(samples[sample]) - expected) < 1e-6)
                }
                let sought = try TransportPlan(request: TransportRequest(exercise: target, tuning: .standard, bpm: 60, startTick: 480, countInBars: 0, clickEnabled: false, toneVolume: 1), sampleRate: rate)
                let resumed = try sought.render(startFrame: 0, count: 2000)
                let uninterrupted = try plan.render(startFrame: Int64(rate * 0.5), count: 2000)
                // At 44.1 kHz a strum voice can shift one rounded sample after changing the epoch.
                #expect(zip(resumed, uninterrupted).allSatisfy { abs($0 - $1) < 0.0001 })
                let practice = try TransportPlan(request: TransportRequest(exercise: target, tuning: .standard, bpm: 60, countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
                #expect(try practice.render(startFrame: 0, count: 12000).allSatisfy { $0 == 0 })
            }
        }
    }
    @Test func authoredMuteIsVersionSafeAndCannotClaimValidatedGrading() throws {
        let muted = try exercise(muted: true).events[0]
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: JSONEncoder().encode(muted)) == muted)
        let ordinary = try exercise(muted: false).events[0]
        let data = try JSONEncoder().encode(ordinary)
        #expect(!(String(data: data, encoding: .utf8) ?? "").contains("palmMuted"))
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: data).palmMuted == false)
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "rest", startTick: 0, durationTicks: 960, kind: .rest, palmMuted: true) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "held", startTick: 0, durationTicks: 960, kind: .note, positions: muted.positions, assessSustain: true, palmMuted: true) }
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "bad", events: [muted], assessmentMode: .monophonic) }
    }
}
