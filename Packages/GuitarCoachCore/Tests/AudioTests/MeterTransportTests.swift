import Foundation
import Testing
import Domain
@testable import Audio

struct MeterTransportTests {
    @Test func pulseClockAndGroupedClicksMatchIndependentSampleGoldens() throws {
        let cases: [(TimeSignature,Int64,Int,[Int]?,Set<Int>)] = [
            (.threeFour,960,3,nil,[0]), (.fourFour,960,4,nil,[0]),
            (.sixEight,1440,2,nil,[0]), (.twelveEight,1440,4,nil,[0]),
            (.fiveFour,960,5,[2,3],[0,2]), (.sevenEight,480,7,[3,2,2],[0,3,5])]
        for (meter,pulse,count,groups,accents) in cases { for rate in [44100.0,48000.0] { for bpm in [60.0,137.0] {
            let bar = pulse * Int64(count)
            let events = try (0..<count*2).map { i in
                try MusicalEvent(id:"n\(i)",startTick:Int64(i)*pulse,durationTicks:pulse,kind:.note,positions:[FretPosition(string:3,fret:5)])
            }
            let exercise = try Exercise(id:"meter",events:events,timeSignature:meter,metronome:MetronomePattern(silentBeatTicks:[pulse,bar]),beatGrouping:groups)
            let plan = try TransportPlan(request:TransportRequest(exercise:exercise,tuning:.standard,bpm:bpm,mode:.practice),sampleRate:rate)
            #expect(plan.practiceStartFrame == Int64((Double(count)*60/bpm*rate).rounded()))
            #expect(plan.endFrame == Int64((Double(count*3)*60/bpm*rate).rounded()))
            for beat in 0..<count*3 {
                let frame = Int64((Double(beat)*60/bpm*rate).rounded())
                let output = try plan.render(startFrame:frame,count:96)
                let silent = beat == count+1 || beat == count*2
                let frequency = accents.contains(beat%count) ? 1800.0 : 1200.0
                let decaySamples = Double(Int64(rate*0.012))
                for index in 0..<96 {
                    let expected = silent ? 0 : sin(2 * .pi * frequency * Double(index)/rate) * (1-Double(index)/decaySamples) * 0.125
                    #expect(abs(Double(output[index])-expected) < 1e-7)
                }
                if beat < count { #expect(plan.position(at:frame).countInBeat == beat+1) }
                else { #expect(plan.position(at:frame).tick == Int64(beat-count)*pulse) }
            }
            let loop = try TransportPlan(request:TransportRequest(exercise:exercise,tuning:.standard,bpm:bpm,range:bar..<bar*2,startTick:bar+pulse,countInBars:0,loops:true,mode:.practice),sampleRate:rate)
            let boundary = Int64((Double(count-1)*60/bpm*rate).rounded())
            #expect(try loop.render(startFrame:0,count:96).contains { abs($0)>0.01 })
            #expect(try loop.render(startFrame:boundary,count:96).allSatisfy { $0 == 0 })
            #expect(loop.position(at:boundary).tick == bar && loop.position(at:boundary).loopIndex == 1)
            let single = try loop.render(startFrame:boundary-100,count:300)
            let split = try loop.render(startFrame:boundary-100,count:99) + loop.render(startFrame:boundary-1,count:201)
            #expect(single == split)
        } } }
    }
}
