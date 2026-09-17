import Foundation
import Testing
import Domain
@testable import Learning

struct MeterAssessmentTests {
    @Test func compoundAndOddExpectedAttacksUseFrozenPulseWithoutQuarterBPMGuessing() throws {
        let cases: [(TimeSignature,Int,Int64,Double)] = [(.sixEight,6,480,1.0/3),(.twelveEight,12,480,1.0/3),(.fiveFour,5,960,1),(.sevenEight,7,480,1)]
        let endpoint = try CalibrationEndpoint(uid:"meter",channel:1,sampleRate:48000,bufferFrames:512,deviceLatencyFrames:0,streamLatencyFrames:0)
        let route = try CalibrationRoute(input:endpoint,output:endpoint,backendVersion:"fixture")
        let calibration = try CalibrationProfile(route:route,method:.measured,residualOffsetSeconds:0.12,uncertaintySeconds:0.015,
            evidence:CalibrationEvidence(algorithmVersion:"fixture",matchedPulses:12,missedPulses:0,extraPulses:0,durationSeconds:25,residualP95Seconds:0.005,driftSeconds:0))
        for (meter,count,ticks,seconds) in cases {
            let events = try (0..<count).map { i in
                try MusicalEvent(id:"n\(i)",startTick:Int64(i)*ticks,durationTicks:ticks,kind:.note,positions:[FretPosition(string:3,fret:5)])
            }
            let config = try PracticeConfiguration(exercise:Exercise(id:"meter",events:events,timeSignature:meter),instrument:InstrumentProfile(),bpm:60,route:route,calibration:calibration)
            let barSeconds = Double(count)*seconds
            #expect(abs(config.durationSeconds-barSeconds)<1e-12 && abs(config.countInSeconds-barSeconds)<1e-12)
            for late in [false,true] {
                let attacks = try (0..<count).map { i in
                    try PracticeAttack(id:UInt64(i+1),normalizedOnset:100+barSeconds+Double(i)*seconds+0.12+(late && i==count-1 ? 0.15 : 0),frequency:261.6255653005986,clarity:0.98,reliable:true)
                }
                let evidence = try PracticeEvidence(id:UUID(),configuration:config,startedAt:Date(timeIntervalSince1970:1),finishedAt:Date(timeIntervalSince1970:30),phase:.completed,reason:nil,signalConfirmed:true,renderEpochSeconds:100,maximumClockDriftSeconds:0,attacks:attacks,clipping:[],analysisVersion:"fixture")
                let result = try AssessmentEngine.evaluate(evidence)
                #expect(result.validity == .valid && result.matchedCount == count && result.extras.isEmpty)
                #expect(abs((result.notes.last?.timingErrorSeconds ?? 1)-(late ? 0.15 : 0))<0.0001)
                #expect(late ? result.timingScore! < 100 : result.overallScore == 100)
                #expect(try JSONDecoder().decode(AssessedPractice.self,from:JSONEncoder().encode(result)) == result)
            }
        }
    }
}
