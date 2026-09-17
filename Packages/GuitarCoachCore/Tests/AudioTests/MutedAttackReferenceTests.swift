import Foundation
import Testing
import Domain
@testable import Audio

struct MutedAttackReferenceTests {
    @Test func mutedBurstIsAudibleDistinctFromRestAndIndependentOfTuningChunksSeekAndLoop() throws {
        let muted = try MusicalEvent(id: "muted", startTick: 0, durationTicks: 1920, kind: .note, mutedAttack: MutedStringAttack(strings: [1,2,3], direction: .down))
        let rest = try MusicalEvent(id: "rest", startTick: 1920, durationTicks: 1920, kind: .rest)
        let exercise = try Exercise(id: "noise-reference", events: [muted,rest], assessmentMode: .displayOnly)
        func render(_ plan: TransportPlan, start: Int64 = 0, count: Int) throws -> [Float] {
            var output: [Float] = []
            for offset in stride(from: 0, to: count, by: 40000) { output += try plan.render(startFrame: start + Int64(offset), count: min(40000,count-offset)) }
            return output
        }
        for rate in [44100.0,48000.0] {
            let request = try TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, clickEnabled: false)
            let plan = try TransportPlan(request: request, sampleRate: rate)
            let full = try render(plan, count: Int(rate * 4))
            #expect(full.prefix(Int(rate * 0.08)).contains { abs($0) > 0.01 })
            #expect(full.dropFirst(Int(rate * 0.08)).allSatisfy { $0 == 0 })
            #expect(full.allSatisfy { $0.isFinite && abs($0) <= 0.1 })
            var chunks: [Float] = []
            for offset in stride(from: 0, to: full.count, by: 769) { chunks += try plan.render(startFrame: Int64(offset), count: min(769,full.count-offset)) }
            #expect(chunks == full)
            let drop = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .dropA, bpm: 60, countInBars: 0, clickEnabled: false), sampleRate: rate)
            #expect(try render(drop, count: full.count) == full)
            // Seek 24 ticks (25 ms) into the already-started attack, never re-trigger its envelope.
            let seek = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, startTick: 24, countInBars: 0, clickEnabled: false), sampleRate: rate)
            let start = Int((rate * 0.025).rounded())
            #expect(try seek.render(startFrame: 0, count: 2000) == Array(full[start..<(start+2000)]))
            let loop = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, loops: true, clickEnabled: false), sampleRate: rate)
            #expect(try render(loop, start: Int64(rate * 4), count: full.count) == full)
            let silent = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
            #expect(try silent.render(startFrame: 0, count: 5000).allSatisfy { $0 == 0 })
        }
    }
}
