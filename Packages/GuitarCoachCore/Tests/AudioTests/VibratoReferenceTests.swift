import Foundation
import Testing
import Domain
@testable import Audio

struct VibratoReferenceTests {
    @Test func phaseIsStableAcrossSeekChunksLoopMetersAndRates() throws {
        for meter in TimeSignature.allCases {
            let pulse = meter.pulseTicks
            let vibrato = try PitchVibrato(extentCents: 80, startTick: pulse, endTick: pulse * 3, periodTicks: pulse / 2)
            let note = try MusicalEvent(id: "vibrato", startTick: 0, durationTicks: pulse * 4, kind: .note,
                positions: [FretPosition(string: 3, fret: 7)], vibrato: vibrato)
            let exercise = try Exercise(id: "vibrato", events: [note], timeSignature: meter)
            for rate in [44100.0, 48000.0] {
                let plan = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    countInBars: 0, clickEnabled: false), sampleRate: rate)
                let start = Int64(rate * 0.75), count = 48000
                let whole = try plan.render(startFrame: start, count: count)
                var chunks: [Float] = []
                for offset in stride(from: 0, to: count, by: 769) {
                    chunks += try plan.render(startFrame: start + Int64(offset), count: min(769, count - offset))
                }
                #expect(whole == chunks)
                let seek = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    startTick: pulse * 3 / 2, countInBars: 0, clickEnabled: false), sampleRate: rate)
                #expect(try plan.render(startFrame: Int64(rate * 1.5), count: 12000) == seek.render(startFrame: 0, count: 12000))
                let loop = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    countInBars: 1, loops: true, clickEnabled: false), sampleRate: rate)
                #expect(try loop.render(startFrame: loop.practiceStartFrame + start, count: count) == whole)
                #expect(try loop.render(startFrame: loop.practiceStartFrame + Int64(rate * 4) + start, count: count) == whole)
                let practice = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
                #expect(try practice.render(startFrame: start, count: count).allSatisfy { $0 == 0 })
                // Independent integration of the authored instantaneous frequency, not the lookup table.
                for time in [1.125, 1.25, 1.75, 2.99, 3.5] {
                    let frame = Int64((rate * time).rounded()), exactTime = Double(frame) / rate
                    let steps = 100000, width = exactTime / Double(steps)
                    let phase = (0..<steps).reduce(0.0) { sum, index in
                        let t = (Double(index) + 0.5) * width
                        let cents = t > 1 && t < 3 ? 40 * (1 - cos(4 * .pi * (t - 1))) : 0
                        return sum + pow(2, cents / 1200) * width
                    }
                    let sample = try #require(plan.render(startFrame: frame, count: 1).first)
                    #expect(abs(Double(sample) - 0.1 * sin(2 * .pi * 293.6647679174076 * phase)) < 1e-6)
                }
            }
        }
    }
}
