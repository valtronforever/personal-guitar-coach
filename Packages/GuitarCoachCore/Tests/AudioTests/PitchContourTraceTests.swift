import Foundation
import Testing
import Domain
@testable import Audio

struct PitchContourTraceTests {
    @Test func movingPeriodicPitchHasIndependentQualityWithoutChangingStableSustain() throws {
        for rate in [44100.0,48000.0] {
            let analyzer=try MonophonicAnalyzer(sampleRate:rate)
            var phase=0.0,pcm:[Float]=[]
            for index in 0..<Int(rate*1.2) {
                let time=Double(index)/rate, cents=min(400,max(0,(time-0.4)/0.2*400))
                phase += 2 * .pi * 261.625565 * pow(2,cents/1200)/rate
                pcm.append(Float(0.15*sin(phase)))
            }
            pcm.withUnsafeBufferPointer { analyzer.process($0,startHostSeconds:10) }
            let snapshot=analyzer.snapshot(), trace=try #require(snapshot.pitchContour), sustain=try #require(snapshot.sustainTrace)
            #expect(trace.frames.map(\.id) == sustain.frames.map(\.id) && trace.totalFrames == sustain.totalFrames)
            #expect(trace.frames.map(\.time) == sustain.frames.map(\.time))
            // The 4096-sample window must lie inside the constant-slope ramp.
            // Its last ~47 ms blends the ramp into the destination plateau.
            let dynamic=trace.frames.filter { (0.46...0.54).contains(Double($0.time.frame)/rate) }
            #expect(dynamic.filter { $0.state == .pitched }.count >= 3)
            #expect(dynamic.contains { frame in sustain.frames.first { $0.id == frame.id }?.state != .pitched && frame.state == .pitched })
            for frame in dynamic where frame.state == .pitched {
                let time=Double(frame.time.frame)/rate, expected=min(400,max(0,(time-0.4)/0.2*400))
                let frequency=try #require(frame.frequency)
                #expect(abs(1200*log2(frequency/261.625565)-expected) < 15)
            }
            let settled = trace.frames.filter { (0.67...0.9).contains(Double($0.time.frame)/rate) }
            #expect(settled.count >= 10 && settled.allSatisfy { $0.state == .pitched })
            for frame in settled {
                #expect(abs(1200*log2(frame.frequency!/261.625565)-400) < 2)
            }
            let closed=try PitchContourTrace(frames:trace.frames.map { try SustainFrame(id:$0.id,normalizedTime:$0.time.hostSeconds!,state:$0.state,frequency:$0.frequency) })
            #expect(try JSONDecoder().decode(PitchContourTrace.self,from:JSONEncoder().encode(closed)) == closed)
            #expect(throws:PracticeError.invalidEvidence) { try PitchContourTrace(version:SustainTrace.currentVersion,frames:closed.frames) }
        }
    }
    @Test func badInputNeverBecomesPitchedAndRollingStorageRemainsBounded() throws {
        for mode in ["noise","clipping","silence"] {
            let analyzer=try MonophonicAnalyzer(sampleRate:48000)
            var random:UInt64=17,pcm:[Float]=[]
            for index in 0..<24000 {
                random=random &* 6364136223846793005 &+ 1
                let noise=Double(random >> 32)/Double(UInt32.max)*2-1
                pcm.append(mode == "noise" ? Float(noise*0.15) : mode == "clipping" ? Float(1.5*sin(2 * .pi * 440*Double(index)/48000)) : 0)
            }
            pcm.withUnsafeBufferPointer { analyzer.process($0,startHostSeconds:10) }
            let frames=try #require(analyzer.snapshot().pitchContour?.frames)
            #expect(!frames.isEmpty && frames.allSatisfy { $0.state != .pitched && $0.frequency == nil })
            if mode == "silence" { #expect(frames.allSatisfy { $0.state == .silence }) }
        }
        let analyzer=try MonophonicAnalyzer(sampleRate:48000),quiet=[Float](repeating:0,count:48000*13)
        quiet.withUnsafeBufferPointer { analyzer.process($0,startHostSeconds:10) }
        let trace=try #require(analyzer.snapshot().pitchContour)
        #expect(trace.frames.count == MonophonicAnalyzer.sustainFrameCapacity && trace.totalFrames > UInt64(trace.frames.count))
        #expect(trace.frames.last?.id == trace.totalFrames)
    }
    @Test func missingOrLostContourCannotCompleteBendCapture() throws {
        let endpoint = try CalibrationEndpoint(uid: "lost-contour", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let event = try MusicalEvent(id: "bend", startTick: 0, durationTicks: 2880, kind: .note,
            positions: [FretPosition(string: 3, fret: 9)], bend: PitchBend(semitones: 1, riseStartTick: 480, riseEndTick: 960))
        let config = try PracticeConfiguration(exercise: Exercise(id: "lost", events: [event]), instrument: InstrumentProfile(), bpm: 60,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "generated"))
        func snapshot(_ trace: PitchContourSnapshot?) -> AudioAnalysisSnapshot {
            AudioAnalysisSnapshot(algorithmVersion: "test", latest: nil, events: [], totalEvents: 0,
                invalidSamples: 0, qualitySpans: [], totalQualitySpans: 0, pitchContour: trace)
        }
        var collector = PracticeEvidenceCollector(configuration: config, baseline: snapshot(.init(frames: [], totalFrames: 0)))
        #expect(throws: AudioBackendError.dataLoss) { try collector.consume(snapshot(nil), renderEpochSeconds: 100) }
        #expect(throws: AudioBackendError.dataLoss) { try collector.consume(snapshot(.init(frames: [], totalFrames: 10)), renderEpochSeconds: 100) }
    }

}
