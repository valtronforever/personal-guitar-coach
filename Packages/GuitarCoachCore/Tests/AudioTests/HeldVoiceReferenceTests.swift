import Foundation
import Testing
import Domain
@testable import Audio

struct HeldVoiceReferenceTests {
    @Test func bassHasOneEnvelopeWhileMelodyReattacksAcrossChunksSeekAndLoop() throws {
        let bass = try FretPosition(string: 5,fret: 3), e = try FretPosition(string: 2,fret: 5), f = try FretPosition(string: 2,fret: 6)
        let events = [try MusicalEvent(id: "a",startTick: 0,durationTicks: 960,kind: .note,positions: [bass,e]),
                      try MusicalEvent(id: "b",startTick: 960,durationTicks: 960,kind: .note,positions: [bass,f],heldStrings: [5]),
                      try MusicalEvent(id: "c",startTick: 1920,durationTicks: 960,kind: .note,positions: [bass],heldStrings: [5]),
                      try MusicalEvent(id: "rest",startTick: 2880,durationTicks: 960,kind: .rest)]
        let exercise = try Exercise(id: "reference",events: events,assessmentMode: .displayOnly)
        func render(_ plan: TransportPlan, _ start: Int64, _ count: Int, chunk: Int = 40000) throws -> [Float] {
            var samples: [Float] = []
            for offset in stride(from: 0,to: count,by: chunk) { samples += try plan.render(startFrame: start+Int64(offset),count: min(chunk,count-offset)) }
            return samples
        }
        for rate in [44100.0,48000.0] {
            func plan(start: Int64 = 0, loops: Bool = false, mode: TransportMode = .preview) throws -> TransportPlan {
                try TransportPlan(request: TransportRequest(exercise: exercise,tuning: .standard,bpm: 60,startTick: start,countInBars: 0,loops: loops,mode: mode,clickEnabled: false,toneVolume: 1),sampleRate: rate)
            }
            let reference = try plan(), full = try render(reference,0,Int(rate*4))
            // Independent analytic voices: C3 for 3s, E4 for 1s, then F4 for 1s.
            let definitions: [(Int,Double,Double)] = [(48,0,3),(64,0,1),(65,1,2)]
            var maximumError: Float = 0
            for sample in 0..<full.count {
                var expected = 0.0
                for (midi,start,end) in definitions where Double(sample) >= start*rate && Double(sample) < end*rate {
                    let age = Double(sample)-start*rate, remaining = end*rate-Double(sample)-1
                    let envelope = min(1,min(age/(rate*0.005),remaining/(rate*0.005)))
                    let frequency = 440*pow(2,Double(midi-69)/12)
                    expected += sin(2 * .pi * frequency * age/rate)*0.1*envelope
                }
                maximumError = max(maximumError,abs(full[sample]-Float(expected)))
            }
            #expect(maximumError < 0.000001)
            #expect(try render(reference,0,full.count,chunk: 769) == full)
            let seek = try plan(start: 1440), offset = Int(rate*1.5)
            #expect(try render(seek,0,Int(rate)) == Array(full[offset..<(offset+Int(rate))]))
            #expect(try render(plan(loops: true),Int64(rate*4),full.count) == full)
            #expect(try render(plan(mode: .practice),0,full.count).allSatisfy { $0 == 0 })
            #expect(full.suffix(Int(rate)).allSatisfy { $0 == 0 })
        }
    }
}
