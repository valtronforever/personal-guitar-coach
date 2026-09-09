import Testing
import Foundation
import Domain
@testable import Audio

struct TransportTests {
    private func exercise(signature: TimeSignature = .fourFour, chord: Bool = false) throws -> Exercise {
        try Exercise(id: "transport-test", events: [
            MusicalEvent(id: "first", startTick: 0, durationTicks: 960, kind: .note,
                         positions: chord ? [FretPosition(string: 6, fret: 0), FretPosition(string: 5, fret: 2)] : [FretPosition(string: 6, fret: 0)]),
            MusicalEvent(id: "rest", startTick: 960, durationTicks: 960, kind: .rest),
            MusicalEvent(id: "last", startTick: 1920, durationTicks: 960, kind: .note, positions: [FretPosition(string: 1, fret: 0)])
        ], timeSignature: signature, assessmentMode: chord ? .displayOnly : .monophonic)
    }
    @Test func absoluteFramesRemainWithinHalfASampleAcrossFifteenMinutes() throws {
        for rate in [44100.0, 48000] { for bpm in [40.0, 73, 120, 173, 200] {
            let plan = try TransportPlan(request: TransportRequest(exercise: exercise(), tuning: .standard, bpm: bpm, loops: true), sampleRate: rate)
            for beat in 0...Int(bpm * 15) {
                let expected = Double(beat) * 60 * rate / bpm
                #expect(abs(Double(plan.frame(at: Int64(beat) * 960)) - expected) <= 0.500001)
            }
        } }
    }
    @Test func countInFirstLastRestAndLoopShareBoundaries() throws {
        for signature in TimeSignature.allCases {
            let plan = try TransportPlan(request: TransportRequest(exercise: exercise(signature: signature), tuning: .standard, bpm: 73, loops: true), sampleRate: 44100)
            #expect(plan.position(at: 0).countInBeat == 1)
            #expect(plan.position(at: plan.practiceStartFrame - 1).countInBeat == signature.beatsPerBar)
            #expect(plan.position(at: plan.practiceStartFrame).tick == 0)
            let boundary = plan.frame(at: plan.countInTicks + 2880)
            #expect(plan.position(at: boundary).loopIndex == 1 && plan.position(at: boundary).tick == 0)
            let sound = try plan.render(startFrame: boundary, count: 2000)
            let beginning = try plan.render(startFrame: plan.practiceStartFrame, count: 2000)
            // Absolute rounding can change the event's end by one sample, but its onset waveform is identical.
            #expect(sound == beginning)
        }
    }
    @Test func restsAndPracticeNeverContainReferenceTones() throws {
        let preview = try TransportPlan(request: TransportRequest(exercise: exercise(chord: true), tuning: .standard, bpm: 120, countInBars: 0, clickEnabled: false), sampleRate: 48000)
        #expect(try preview.render(startFrame: 0, count: 2000).contains { abs($0) > 0.01 })
        #expect(try preview.render(startFrame: 24000, count: 24000).allSatisfy { $0 == 0 })
        #expect(try preview.render(startFrame: 48000, count: 2000).contains { abs($0) > 0.01 })
        #expect(try preview.render(startFrame: 72000, count: 2000).allSatisfy { $0 == 0 })
        #expect(preview.position(at: 72000).completed)
        let practice = try TransportPlan(request: TransportRequest(exercise: exercise(), tuning: .standard, bpm: 120, countInBars: 0, mode: .practice, clickEnabled: false, toneVolume: 1), sampleRate: 48000)
        #expect(try practice.render(startFrame: 0, count: 48000).allSatisfy { $0 == 0 })
    }
    @Test func chunksSeekAndPartialFirstLoopHaveNoMissingOrDuplicatedSamples() throws {
        let request = try TransportRequest(exercise: exercise(), tuning: .dropD, bpm: 173, startTick: 1440, countInBars: 0, loops: true)
        let plan = try TransportPlan(request: request, sampleRate: 48000)
        let whole = try plan.render(startFrame: 0, count: 48000)
        let divided = try stride(from: 0, to: 48000, by: 1000).flatMap { try plan.render(startFrame: Int64($0), count: 1000) }
        #expect(whole == divided)
        #expect(plan.position(at: 0).tick == 1440)
        #expect(plan.position(at: plan.frame(at: 1440)).tick == 0)
        #expect(plan.position(at: plan.frame(at: 1440)).loopIndex == 1)
    }
    @Test func invalidBoundsAndVolumesRejectBeforeAllocation() throws {
        let item = try exercise()
        let huge = try Exercise(id: "huge", events: [MusicalEvent(id: "huge-note", startTick: 0, durationTicks: Int64.max,
            kind: .note, positions: [FretPosition(string: 6, fret: 0)])])
        #expect(throws: MusicError.invalidTime) { try TransportRequest(exercise: huge, tuning: .standard, bpm: 60) }
        #expect(throws: MusicError.invalidTime) { try TransportRequest(exercise: item, tuning: .standard, bpm: 60, range: 0..<10) }
        #expect(throws: MusicError.invalidTime) { try TransportRequest(exercise: item, tuning: .standard, bpm: 60, startTick: 2880) }
        #expect(throws: MusicError.invalidTime) { try TransportRequest(exercise: item, tuning: .standard, bpm: 60, clickVolume: .nan) }
    }
}
