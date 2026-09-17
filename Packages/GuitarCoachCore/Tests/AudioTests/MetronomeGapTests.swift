import Foundation
import Testing
import Domain
@testable import Audio

struct MetronomeGapTests {
    @Test func omissionsKeepCountInClockSeekLoopAndChunkBoundaries() throws {
        let events = try (0..<12).map { i in
            try MusicalEvent(id: "n\(i)", startTick: Int64(i*960), durationTicks: 960, kind: .note, positions: [FretPosition(string:3,fret:5)])
        }
        let ordinary = try Exercise(id: "full", events: events)
        let gapped = try Exercise(id: "gap", events: events, metronome: MetronomePattern(silentBeatTicks: [0,1920,3840,4800,5760,6720]))
        for rate in [44100.0,48000.0] { for bpm in [60.0,137.0] {
            let full = try TransportPlan(request: TransportRequest(exercise: ordinary, tuning: .standard, bpm:bpm, mode:.practice), sampleRate:rate)
            let gap = try TransportPlan(request: TransportRequest(exercise:gapped,tuning:.standard,bpm:bpm,mode:.practice),sampleRate:rate)
            #expect(full.endFrame == gap.endFrame && full.practiceStartFrame == gap.practiceStartFrame)
            for beat in 0..<16 {
                let frame = Int64((Double(beat)*60/bpm*rate).rounded())
                let a = try full.render(startFrame:frame,count:1024), b = try gap.render(startFrame:frame,count:1024)
                let silent = beat >= 4 && [0,2,4,5,6,7].contains(beat-4)
                #expect(a.contains { abs($0)>0.01 })
                #expect(silent ? b.allSatisfy { $0 == 0 } : a == b)
                #expect(full.position(at:frame) == gap.position(at:frame))
                #expect(full.audibleTimelineTick(renderedFrames:frame,outputLatencySeconds:0.1) == gap.audibleTimelineTick(renderedFrames:frame,outputLatencySeconds:0.1))
            }
            let loop = try TransportPlan(request:TransportRequest(exercise:gapped,tuning:.standard,bpm:bpm,range:3840..<11520,startTick:5760,countInBars:0,loops:true,mode:.practice),sampleRate:rate)
            // First partial pass has two silent then four audible beats; each full
            // subsequent pass repeats four silent then four audible source beats.
            for beat in 0..<22 {
                let frame = Int64((Double(beat)*60/bpm*rate).rounded())
                let silent = beat < 6 ? beat < 2 : (beat-6)%8 < 4
                let samples = try loop.render(startFrame:frame,count:1024)
                #expect(silent ? samples.allSatisfy { $0 == 0 } : samples.contains { abs($0)>0.01 })
            }
            let boundary = Int64((10*60/bpm*rate).rounded())
            let whole = try loop.render(startFrame:boundary-257,count:2048)
            let chunks = try loop.render(startFrame:boundary-257,count:333) + loop.render(startFrame:boundary+76,count:1715)
            #expect(whole == chunks)
            let muted = try TransportPlan(request:TransportRequest(exercise:gapped,tuning:.standard,bpm:bpm,mode:.practice,clickEnabled:false),sampleRate:rate)
            #expect(try muted.render(startFrame:0,count:1024).allSatisfy { $0 == 0 })
            let preview = try TransportPlan(request:TransportRequest(exercise:gapped,tuning:.standard,bpm:bpm,countInBars:0,mode:.preview),sampleRate:rate)
            #expect(try preview.render(startFrame:0,count:1024).contains { abs($0)>0.01 })
        } }
    }
}
