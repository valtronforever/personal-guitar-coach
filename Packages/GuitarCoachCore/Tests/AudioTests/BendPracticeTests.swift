import Foundation
import Testing
import Domain
import Learning
@testable import Audio

struct BendPracticeTests {
    private func run(rate: Double, mode: String, release: Bool = true, midi: Int = 64) throws -> AssessedPractice {
        let bend = try PitchBend(semitones: 2, riseStartTick: 480, riseEndTick: 960,
            releaseStartTick: release ? 1920 : nil, releaseEndTick: release ? 2400 : nil)
        let event = try MusicalEvent(id: "bend", startTick: 0, durationTicks: 2880, kind: .note,
            positions: [try #require(TuningProfile.standard.strings.compactMap { string in
                let fret = midi - string.openPitch.midi
                return (1...24).contains(fret) ? try? FretPosition(string: string.number, fret: fret) : nil
            }.first)], bend: bend)
        let rest = try MusicalEvent(id: "rest", startTick: 2880, durationTicks: 960, kind: .rest)
        let endpoint = try CalibrationEndpoint(uid: "bend-generated", channel: 1, sampleRate: rate, bufferFrames: 512,
            deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: MonophonicAnalyzer.algorithmVersion)
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0,
            uncertaintySeconds: 0.015, evidence: CalibrationEvidence(algorithmVersion: "generated", matchedPulses: 12,
                missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "bend-test", events: [event, rest]),
            instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let analyzer = try MonophonicAnalyzer(sampleRate: rate)
        var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
        let start = 0.2 + config.countInSeconds, frequency = try Pitch(midi: midi).frequency()
        var pcm: [Float] = [], phase = 0.0, random: UInt64 = 17
        for index in 0..<Int((start + 5) * rate) {
            let time = Double(index) / rate - start
            if time < 0 || time >= 3 { pcm.append(0); continue }
            // Independent time-domain fixture, deliberately not using PitchBend interpolation.
            var cents = time < 0.5 ? 0 : time < 1 ? (time - 0.5) * 400 : 200
            if release && mode != "no-return" && time >= 2 { cents = max(0, 200 - (time - 2) * 400) }
            if mode == "stuck" { cents = 0 }
            if mode == "overshoot" { cents *= 1.5 }
            phase += 2 * .pi * frequency * pow(2, cents / 1200) / rate
            random = random &* 6364136223846793005 &+ 1
            let envelope = min(1, time / 0.005, (3 - time) / 0.005)
            let signal = 0.15 * (sin(phase) + 0.3 * sin(2 * phase) + 0.15 * sin(3 * phase)) * envelope
            let sample: Float
            switch mode {
            case "silence": sample = 0
            case "noise":
                let normalizedRandom = Double(random >> 32) / Double(UInt32.max)
                sample = Float((normalizedRandom * 2 - 1) * 0.2)
            case "clipped": sample = Float(signal * 12)
            default: sample = Float(signal)
            }
            pcm.append(sample)
        }
        for frame in stride(from: 0, to: pcm.count, by: 769) {
            pcm.withUnsafeBufferPointer { ptr in analyzer.process(.init(rebasing: ptr[frame..<min(frame + 769, ptr.count)]), startHostSeconds: 100 + Double(frame) / rate) }
            try collector.consume(analyzer.snapshot(), renderEpochSeconds: 100.2)
        }
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 12), phase: .completed, reason: nil, signalConfirmed: true,
            renderEpochSeconds: 100.2, maximumClockDriftSeconds: 0, attacks: collector.attacks, clipping: collector.clipping,
            uncertainSignal: collector.uncertainSignal, pitchContour: collector.pitchContourTrace(), analysisVersion: collector.analysisVersion)
        return try AssessmentEngine.evaluate(evidence)
    }
    @Test(arguments: [44100.0, 48000.0]) func correctRiseAndReturnReachMeasuredPhases(rate: Double) throws {
        for release in [false, true] {
            let result = try run(rate: rate, mode: "correct", release: release)
            #expect(result.validity == .valid, "\(rate), release \(release), notes \(result.notes), phases \(String(describing: result.bends))")
            #expect((result.bendScore ?? -1) > 95)
            #expect(result.matchedCount == 1)
            #expect(result.parameters.version == "monophonic-assessment-4")
            #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        }
    }
    @Test(arguments: [44100.0, 48000.0]) func supportedRangeTracksCleanHarmonicBends(rate: Double) throws {
        for midi in [55, 60, 69, 81] {
            let result = try run(rate: rate, mode: "correct", midi: midi)
            #expect(result.validity == .valid && (result.bendScore ?? -1) > 95, "MIDI \(midi), \(rate): \(String(describing: result.bends))")
        }
    }
    @Test func wrongContoursAndInvalidSignalRemainDifferent() throws {
        for mode in ["stuck", "overshoot", "no-return", "silence", "noise", "clipped"] {
            let result = try run(rate: 48000, mode: mode)
            if ["noise", "clipped"].contains(mode) {
                #expect(result.validity == .insufficientSignal && result.bendScore == nil, "\(mode): \(String(describing: result.bends))")
            } else {
                #expect(result.validity == .valid, "\(mode): \(result.validity)")
                #expect((result.bendScore ?? 100) < 75, "\(mode): \(String(describing: result.bends))")
                if mode == "silence" { #expect(result.bendScore == 0 && result.matchedCount == 0) }
            }
        }
    }
}
