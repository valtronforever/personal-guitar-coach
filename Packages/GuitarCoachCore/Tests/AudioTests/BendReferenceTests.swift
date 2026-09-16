import Foundation
import Testing
import Domain
@testable import Audio

struct BendReferenceTests {
    @Test func referenceIsContinuousChunkIndependentAndPracticeRemainsSilent() throws {
        let bend = try PitchBend(semitones: 2, riseStartTick: 480, riseEndTick: 960, releaseStartTick: 1920, releaseEndTick: 2400)
        let event = try MusicalEvent(id: "b", startTick: 0, durationTicks: 2880, kind: .note, positions: [FretPosition(string: 3, fret: 9)], bend: bend)
        let exercise = try Exercise(id: "bend", events: [event])
        for rate in [44100.0, 48000.0] {
            let plan = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, clickEnabled: false), sampleRate: rate)
            let start = Int64(rate * 0.35), large = try plan.render(startFrame: start, count: 48000)
            var small: [Float] = []
            for offset in stride(from: 0, to: 48000, by: 769) { small += try plan.render(startFrame: start + Int64(offset), count: min(769, 48000 - offset)) }
            #expect(large == small)
            let seek = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, startTick: 720, countInBars: 0, clickEnabled: false), sampleRate: rate)
            #expect(try plan.render(startFrame: Int64(rate * 0.75), count: 12000) == seek.render(startFrame: 0, count: 12000))
            let practice = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
            #expect(try practice.render(startFrame: 0, count: 48000).allSatisfy { $0 == 0 })
            #expect(large.allSatisfy { $0.isFinite && abs($0) <= 0.1 })
        }
        // Differentiate the analytical phase integral against independent known plateau/ramp frequencies.
        for (tick, cents) in [(240.0, 0.0), (720, 100), (1440, 200), (2160, 100), (2640, 0)] {
            let derivative = (bend.integratedMultiplier(to: tick + 0.01, durationTicks: 2880) - bend.integratedMultiplier(to: tick - 0.01, durationTicks: 2880)) / 0.02
            #expect(abs(derivative - pow(2, cents / 1200)) < 1e-8)
        }
    }
    @Test func invalidAuthoringFailsAndLegacyEncodingStaysUnchanged() throws {
        let p = try FretPosition(string: 3, fret: 9), bend = try PitchBend(semitones: 1, riseStartTick: 480, riseEndTick: 960)
        #expect(throws: MusicError.invalidEvent) { try PitchBend(semitones: 3, riseStartTick: 480, riseEndTick: 960) }
        #expect(throws: MusicError.invalidEvent) { try PitchBend(semitones: 1, riseStartTick: 480, riseEndTick: 960, releaseStartTick: 1440) }
        #expect(throws: MusicError.invalidTime) { try MusicalEvent(id: "n", startTick: 0, durationTicks: 960, kind: .note, positions: [p], bend: bend) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "n", startTick: 0, durationTicks: 1920, kind: .note, positions: [FretPosition(string: 3, fret: 0)], bend: bend) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "n", startTick: 0, durationTicks: 1920, kind: .note, positions: [p], assessSustain: true, bend: bend) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "n", startTick: 0, durationTicks: 1920, kind: .rest, bend: bend) }
        let plain = try MusicalEvent(id: "old", startTick: 0, durationTicks: 960, kind: .note, positions: [p])
        #expect(!String(decoding: try JSONEncoder().encode(plain), as: UTF8.self).contains("bend"))
        #expect(!BendCapability.supports(bend: bend, durationTicks: 1920, bpm: 100, frequency: 330))
        #expect(!BendCapability.supports(bend: bend, durationTicks: 1920, bpm: 60, frequency: 100))
    }
}
