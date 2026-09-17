import Foundation
import Testing
import Domain
@testable import Audio

struct LegatoChainReferenceTests {
    @Test func chainedReferenceKeepsPhaseDuringSeekChunksLoopsAndDifferentMeters() throws {
        for meter in TimeSignature.allCases {
            let pulse = meter.pulseTicks
            let chain = try LegatoChain(targets: [.init(kind: .hammerOn, semitones: 3, startTick: pulse),
                .init(kind: .tap, semitones: 4, startTick: pulse * 2), .init(kind: .pullOff, semitones: -7, startTick: pulse * 3)])
            let exercise = try Exercise(id: "chain", events: [MusicalEvent(id: "chain", startTick: 0, durationTicks: pulse * 5,
                kind: .note, positions: [FretPosition(string: 3, fret: 5)], legatoChain: chain)], timeSignature: meter)
            for rate in [44100.0, 48000.0] {
                let plan = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0,
                    clickEnabled: false), sampleRate: rate)
                let start = Int64(rate * 0.75), large = try plan.render(startFrame: start, count: 48000)
                var small: [Float] = []
                for offset in stride(from: 0, to: large.count, by: 769) {
                    small += try plan.render(startFrame: start + Int64(offset), count: min(769, large.count - offset))
                }
                #expect(large == small)
                for tick in [pulse * 3 / 2, pulse * 5 / 2, pulse * 7 / 2] {
                    let seek = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                        startTick: tick, countInBars: 0, clickEnabled: false), sampleRate: rate)
                    #expect(try plan.render(startFrame: Int64(Double(tick) / Double(pulse) * rate), count: 12000) == seek.render(startFrame: 0, count: 12000))
                }
                let loop = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    countInBars: 1, loops: true, clickEnabled: false), sampleRate: rate)
                #expect(try loop.render(startFrame: loop.practiceStartFrame + start, count: large.count) == large)
                #expect(try loop.render(startFrame: loop.practiceStartFrame + Int64(rate * 5) + start, count: large.count) == large)
                // Independent accumulated areas for C4→Eb4→G4→C4, including nonzero phase at the return.
                for seconds in [0.5, 1.25, 2.25, 3.25, 4.5] {
                    let index = Int64(rate * seconds), time = Double(index) / rate
                    let phase = min(time, 1) + min(max(0, time - 1), 1) * pow(2, 3.0 / 12)
                        + min(max(0, time - 2), 1) * pow(2, 7.0 / 12) + max(0, time - 3)
                    let sample = try #require(plan.render(startFrame: index, count: 1).first)
                    #expect(abs(Double(sample) - sin(2 * .pi * 261.6255653005986 * phase) * 0.1) < 1e-6)
                }
                let practice = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                    countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
                #expect(try practice.render(startFrame: 0, count: 48000).allSatisfy { $0 == 0 })
                #expect(large.allSatisfy { $0.isFinite && abs($0) <= 0.1 })
            }
        }
    }
}
