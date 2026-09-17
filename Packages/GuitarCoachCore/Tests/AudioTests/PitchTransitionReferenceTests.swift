import Foundation
import Testing
import Domain
@testable import Audio

struct PitchTransitionReferenceTests {
    @Test func referencePreservesPhaseAcrossChunksSeekLoopAndMeters() throws {
        for kind in PitchTransition.Kind.allCases {
            for meter in TimeSignature.allCases {
                let pulse = meter.pulseTicks
                let transition = try PitchTransition(kind: kind, semitones: kind == .pullOff ? -2 : 2,
                    startTick: pulse, travelTicks: kind == .slide ? pulse : 0)
                let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: pulse * 3, kind: .note,
                    positions: [FretPosition(string: 3, fret: 7)], pitchTransition: transition)
                let exercise = try Exercise(id: "motion", events: [event], timeSignature: meter)
                for rate in [44100.0, 48000.0] {
                    let plan = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0,
                        clickEnabled: false), sampleRate: rate)
                    let start = Int64(rate * 0.75), large = try plan.render(startFrame: start, count: 48000)
                    var small: [Float] = []
                    for offset in stride(from: 0, to: 48000, by: 769) {
                        small += try plan.render(startFrame: start + Int64(offset), count: min(769, 48000 - offset))
                    }
                    #expect(large == small)
                    let seek = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                        startTick: pulse * 3 / 2, countInBars: 0, clickEnabled: false), sampleRate: rate)
                    #expect(try plan.render(startFrame: Int64(rate * 1.5), count: 12000) == seek.render(startFrame: 0, count: 12000))
                    let loop = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                        countInBars: 1, loops: true, clickEnabled: false), sampleRate: rate)
                    #expect(try loop.render(startFrame: loop.practiceStartFrame + start, count: 48000) == large)
                    #expect(try loop.render(startFrame: loop.practiceStartFrame + Int64(rate * 3) + start, count: 48000) == large)
                    let practice = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
                        countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
                    #expect(try practice.render(startFrame: start, count: 48000).allSatisfy { $0 == 0 })
                    // Independent constant-frequency target plateau with phase accumulated before the change.
                    let hz = 293.6647679174076, multiplier = pow(2, Double(kind == .pullOff ? -2 : 2) / 12)
                    let index = Int64(rate * 2.25), seconds = Double(index) / rate
                    let phaseTime = kind == .slide ? 1 + (multiplier - 1) / log(multiplier) + (seconds - 2) * multiplier
                        : 1 + (seconds - 1) * multiplier
                    let sample = try #require(plan.render(startFrame: index, count: 1).first)
                    #expect(abs(Double(sample) - sin(2 * .pi * hz * phaseTime) * 0.1) < 1e-6)
                    #expect(large.allSatisfy { $0.isFinite && abs($0) <= 0.1 })
                }
            }
        }
    }
}
