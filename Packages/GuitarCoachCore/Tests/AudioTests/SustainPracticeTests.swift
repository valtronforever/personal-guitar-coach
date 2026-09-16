import Foundation
import Testing
import Domain
import Learning
import AudioTestSupport
@testable import Audio

struct SustainPracticeTests {
    private func run(rate: Double, midi: Int, duration: Double, playedFraction: Double,
                     marked: Bool = true) throws -> (AssessedPractice, AudioAnalysisSnapshot) {
        let bpm = duration == 0.5 ? 120.0 : 60.0
        let ticks: Int64 = duration == 2 ? 1920 : 960
        let note = try MusicalEvent(id: "held", startTick: 0, durationTicks: ticks, kind: .note,
            positions: [FretPosition(string: 6, fret: midi - 33)], assessSustain: marked)
        let endpoint = try CalibrationEndpoint(uid: "sustain-generated", channel: 1, sampleRate: rate, bufferFrames: 512,
            deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: MonophonicAnalyzer.algorithmVersion)
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0,
            uncertaintySeconds: 0.015, evidence: CalibrationEvidence(algorithmVersion: "generated", matchedPulses: 12,
                missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "sustain-test", events: [note]),
            instrument: InstrumentProfile(tuning: .dropA), bpm: bpm, route: route, calibration: calibration)
        let analyzer = try MonophonicAnalyzer(sampleRate: rate)
        var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
        let start = 0.2 + config.countInSeconds
        let pcm = SyntheticAudio.render(rate: rate, duration: start + duration + 1,
            notes: [SyntheticNote(onset: start, duration: duration * playedFraction, frequency: try Pitch(midi: midi).frequency())])
        for frame in stride(from: 0, to: pcm.count, by: 769) {
            pcm.withUnsafeBufferPointer { ptr in
                analyzer.process(.init(rebasing: ptr[frame..<min(frame + 769, ptr.count)]), startHostSeconds: 100 + Double(frame) / rate)
            }
            try collector.consume(analyzer.snapshot(), renderEpochSeconds: 100.2)
        }
        #expect(try collector.hasResolvedTail(renderEpochSeconds: 100.2))
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 10), phase: .completed, reason: nil, signalConfirmed: true,
            renderEpochSeconds: 100.2, maximumClockDriftSeconds: 0, attacks: collector.attacks, clipping: collector.clipping,
            uncertainSignal: collector.uncertainSignal, sustainTrace: collector.sustainTrace(), analysisVersion: collector.analysisVersion)
        return (try AssessmentEngine.evaluate(evidence), analyzer.snapshot())
    }
    @Test(arguments: [44100.0, 48000.0])
    func sustainedAndEarlyStoppedPCMReachDifferentMeasuredResults(rate: Double) throws {
        for midi in [33, 40, 52] {
            for duration in [0.5, 1.0, 2.0] {
                let (held, _) = try run(rate: rate, midi: midi, duration: duration, playedFraction: 1)
                #expect(held.validity == .valid, "held MIDI \(midi), \(duration)s, \(rate)Hz")
                #expect((held.sustainScore ?? -1) >= 95)
                let (early, _) = try run(rate: rate, midi: midi, duration: duration, playedFraction: 0.5)
                if rate == 48000 && midi == 33 && duration == 0.5 {
                    // A 250 ms A1 release leaves 60 ms of genuinely ambiguous pitch
                    // windows (24% of the evaluation interval). Keep the quality gate:
                    // this boundary must not become a fabricated duration score.
                    #expect(early.validity == .insufficientSignal && early.sustainScore == nil)
                    #expect((0.23...0.25).contains(try #require(early.sustain?.notes.first?.unknownFraction)))
                } else {
                    #expect(early.validity == .valid, "early MIDI \(midi), \(duration)s, \(rate)Hz")
                    #expect((early.sustainScore ?? 100) < 65)
                }
                #expect(early.matchedCount == 1 && early.missedCount == 0)
            }
        }
    }
    @Test func ordinaryPracticeDoesNotPersistATraceAndWorkerStorageIsBounded() throws {
        let (normal, snapshot) = try run(rate: 48000, midi: 40, duration: 1, playedFraction: 1, marked: false)
        #expect(normal.evidence.sustainTrace == nil && normal.sustain == nil)
        #expect(snapshot.sustainTrace?.version == SustainTrace.currentVersion)
        let analyzer = try MonophonicAnalyzer(sampleRate: 48000)
        let silence = [Float](repeating: 0, count: 48000)
        for second in 0..<12 { silence.withUnsafeBufferPointer { analyzer.process($0, startHostSeconds: 100 + Double(second)) } }
        let trace = try #require(analyzer.snapshot().sustainTrace)
        #expect(trace.totalFrames > UInt64(MonophonicAnalyzer.sustainFrameCapacity))
        #expect(trace.frames.count == MonophonicAnalyzer.sustainFrameCapacity)
        #expect(trace.frames.last?.id == trace.totalFrames)
    }
    @Test func dcClippingAndNoiseCannotMasqueradeAsHeldPitch() throws {
        for kind in ["dc", "clipped", "noise"] {
            let analyzer = try MonophonicAnalyzer(sampleRate: 48000)
            var seed: UInt64 = 17
            let pcm: [Float] = (0..<48000).map { _ in
                seed = seed &* 6364136223846793005 &+ 1
                if kind == "dc" { return 0.2 }
                if kind == "clipped" { return 1 }
                return Float(Double(seed >> 32) / Double(UInt32.max) * 0.3 - 0.15)
            }
            pcm.withUnsafeBufferPointer { analyzer.process($0, startHostSeconds: 100) }
            let frames = try #require(analyzer.snapshot().sustainTrace?.frames)
            #expect(!frames.isEmpty)
            #expect(frames.allSatisfy { $0.state == (kind == "dc" ? .silence : .uncertain) && $0.frequency == nil })
        }
    }
    @Test func missingTraceOrALostPrefixInterruptsMarkedPractice() throws {
        let endpoint = try CalibrationEndpoint(uid: "lost-trace", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let event = try MusicalEvent(id: "held", startTick: 0, durationTicks: 1920, kind: .note,
            positions: [FretPosition(string: 6, fret: 0)], assessSustain: true)
        let config = try PracticeConfiguration(exercise: Exercise(id: "lost", events: [event]), instrument: InstrumentProfile(), bpm: 60,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "generated"))
        func snapshot(_ trace: SustainTraceSnapshot?) -> AudioAnalysisSnapshot {
            AudioAnalysisSnapshot(algorithmVersion: "test", latest: nil, events: [], totalEvents: 0,
                invalidSamples: 0, qualitySpans: [], totalQualitySpans: 0, sustainTrace: trace)
        }
        var collector = PracticeEvidenceCollector(configuration: config, baseline: snapshot(.init(frames: [], totalFrames: 0)))
        #expect(throws: AudioBackendError.dataLoss) { try collector.consume(snapshot(nil), renderEpochSeconds: 100) }
        #expect(throws: AudioBackendError.dataLoss) {
            try collector.consume(snapshot(.init(frames: [], totalFrames: 10)), renderEpochSeconds: 100)
        }
    }
}
