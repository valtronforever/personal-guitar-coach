import Foundation
import Testing
import Domain
import Learning
@testable import Audio

struct TripletTimingTests {
    @Test(arguments: [44100.0,48000.0]) func generatedThirdBeatAttacksTraverseCaptureAndKeepQuarterClicks(rate: Double) throws {
        for shuffle in [false,true] {
            let slots = shuffle ? [0,2] : [0,1,2]
            var events: [MusicalEvent] = [], groups: [TripletGroup] = []
            for beat in 0..<4 {
                var ids: [String] = []
                for slot in slots {
                    let id = "b\(beat)s\(slot)"; ids.append(id)
                    events.append(try MusicalEvent(id:id,startTick:Int64(beat*960+slot*320),durationTicks:shuffle && slot == 0 ? 640 : 320,
                        kind:.note,positions:[FretPosition(string:3,fret:5)]))
                }
                groups.append(try TripletGroup(id:"b\(beat)",eventIDs:ids))
            }
            let exercise = try Exercise(id:"generated-triplets",events:events,triplets:groups)
            let plain = try Exercise(id:"same-time",events:events)
            let plan = try TransportPlan(request:TransportRequest(exercise:exercise,tuning:.standard,bpm:60,countInBars:1,mode:.practice),sampleRate:rate)
            let ordinary = try TransportPlan(request:TransportRequest(exercise:plain,tuning:.standard,bpm:60,countInBars:1,mode:.practice),sampleRate:rate)
            #expect(plan.practiceStartFrame == Int64(rate*4) && plan.endFrame == Int64(rate*8))
            for frame in [Int64(0),Int64(rate*4),Int64(rate*5.2)] {
                #expect(try plan.render(startFrame:frame,count:16000) == ordinary.render(startFrame:frame,count:16000))
            }
            // A triplet label adds no metronome subdivision or tempo scaling.
            for slot in [1,2] {
                let frame = Int64((rate*(4+Double(slot)/3)).rounded())
                #expect(try plan.render(startFrame:frame,count:256).allSatisfy { $0 == 0 })
            }
            let endpoint = try CalibrationEndpoint(uid:"generated-triplets",channel:1,sampleRate:rate,bufferFrames:512,deviceLatencyFrames:0,streamLatencyFrames:0)
            let route = try CalibrationRoute(input:endpoint,output:endpoint,backendVersion:"generated-triplets")
            let calibration = try CalibrationProfile(route:route,method:.measured,residualOffsetSeconds:0,uncertaintySeconds:0.015,
                evidence:CalibrationEvidence(algorithmVersion:"fixture",matchedPulses:12,missedPulses:0,extraPulses:0,durationSeconds:25,residualP95Seconds:0.005,driftSeconds:0))
            let config = try PracticeConfiguration(exercise:exercise,instrument:InstrumentProfile(),bpm:60,route:route,calibration:calibration)
            let analyzer = try MonophonicAnalyzer(sampleRate:rate)
            var collector = PracticeEvidenceCollector(configuration:config,baseline:analyzer.snapshot())
            let frequency = 261.6255653005986
            var pcm = [Float](repeating:0,count:Int(rate*9.5))
            for beat in 0..<4 { for slot in slots {
                // Independent seconds, not TransportPlan or MusicalTime conversions.
                let onset = 4.2+Double(beat)+Double(slot)/3
                let duration = shuffle && slot == 0 ? 2.0/3 : 1.0/3
                let start = Int((onset*rate).rounded()), count = Int(((duration-0.015)*rate).rounded())
                for index in 0..<count {
                    let age = Double(index)/rate, phase = 2 * Double.pi * frequency * age
                    let attack = min(1,age/0.003), release = min(1,Double(count-index)/(rate*0.004))
                    let fundamental = sin(phase), second = 0.25*sin(phase*2), third = 0.1*sin(phase*3)
                    pcm[start+index] = Float(0.2*(fundamental+second+third)*attack*release)
                }
            } }
            for start in stride(from:0,to:pcm.count,by:769) {
                pcm.withUnsafeBufferPointer { ptr in
                    analyzer.process(.init(rebasing:ptr[start..<min(start+769,ptr.count)]),startHostSeconds:100+Double(start)/rate)
                }
                try collector.consume(analyzer.snapshot(),renderEpochSeconds:100.2)
            }
            let input = try PracticeEvidence(id:UUID(),configuration:config,startedAt:Date(timeIntervalSince1970:1),finishedAt:Date(timeIntervalSince1970:11),
                phase:.completed,reason:nil,signalConfirmed:true,renderEpochSeconds:100.2,maximumClockDriftSeconds:0,
                attacks:collector.attacks,clipping:collector.clipping,uncertainSignal:collector.uncertainSignal,analysisVersion:collector.analysisVersion)
            let result = try AssessmentEngine.evaluate(input)
            #expect(result.validity == .valid && result.matchedCount == slots.count*4 && result.extras.isEmpty)
            #expect(result.notes.allSatisfy { abs($0.timingErrorSeconds ?? 1)<0.04 && abs($0.centsError ?? 100)<15 })
            #expect(try JSONDecoder().decode(AssessedPractice.self,from:JSONEncoder().encode(result)) == result)
        }
    }
}
