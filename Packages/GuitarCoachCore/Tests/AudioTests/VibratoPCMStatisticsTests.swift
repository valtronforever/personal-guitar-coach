import Foundation
import Testing
import Domain
@testable import Learning
@testable import Audio

struct VibratoPCMStatisticsTests {
    private func run(rate: Double, midi: Int, width: Int, modulationRate: Double, mode: String = "correct") throws -> (VibratoStatistics, Double, AssessedPractice) {
        let plateau = 0.4, activeSeconds = 4 / modulationRate, noteSeconds = plateau * 2 + activeSeconds
        let periodTicks = Int64((960 / modulationRate).rounded())
        let vibrato = try PitchVibrato(extentCents: width, startTick: 384, endTick: 384 + 4 * periodTicks, periodTicks: periodTicks)
        let position = try #require(TuningProfile.standard.strings.compactMap { string -> FretPosition? in
            let fret = midi - string.openPitch.midi
            return (1...24).contains(fret) ? try? FretPosition(string: string.number, fret: fret) : nil
        }.first)
        let event = try MusicalEvent(id: "v", startTick: 0, durationTicks: vibrato.endTick + 384, kind: .note, positions: [position], vibrato: vibrato)
        let heardRate = mode == "wrong-rate" ? modulationRate / 2 : modulationRate
        let endpoint = try CalibrationEndpoint(uid: "motion-generated", channel: 1, sampleRate: rate, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: MonophonicAnalyzer.algorithmVersion)
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "generated", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "vibrato-test", events: [event]), instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let analyzer = try MonophonicAnalyzer(sampleRate: rate)
        var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
        let start = 0.2 + config.countInSeconds, frequency = try Pitch(midi: midi).frequency()
        var pcm: [Float] = [], phase = 0.0, random: UInt64 = 17
        for index in 0..<Int((start + 5) * rate) {
            let time = Double(index) / rate - start
            if time < 0 || time >= noteSeconds { pcm.append(0); continue }
            // Independent sample-by-sample harmonic signal; never calls the reference renderer.
            let active = time - plateau
            var cents = active > 0 && active < activeSeconds ? Double(width) * (1 - cos(2 * .pi * heardRate * active)) / 2 : 0
            if mode == "flat" { cents = 0 }
            if mode == "wrong-width" { cents *= 2 }
            if mode == "wrong-base" { cents += 100 }
            phase += 2 * .pi * frequency * pow(2, cents / 1200) / rate
            random = random &* 6364136223846793005 &+ 1
            let envelope = min(1, time / 0.005, (noteSeconds - time) / 0.005)
            let signal = 0.15 * (sin(phase) + 0.3 * sin(2 * phase) + 0.15 * sin(3 * phase)) * envelope
            let sample: Float
            switch mode {
            case "silence": sample = 0
            case "noise": sample = Float((Double(random >> 32) / Double(UInt32.max) * 2 - 1) * 0.2)
            case "clipped": sample = Float(signal * 12)
            default: sample = Float(signal)
            }
            pcm.append(sample)
        }
        for frame in stride(from: 0, to: pcm.count, by: 769) {
            pcm.withUnsafeBufferPointer { ptr in analyzer.process(.init(rebasing: ptr[frame..<min(frame + 769, ptr.count)]), startHostSeconds: 100 + Double(frame) / rate) }
            try collector.consume(analyzer.snapshot(), renderEpochSeconds: 100.2)
        }
        let optionalTrace = try collector.pitchContourTrace()
        let trace = try #require(optionalTrace)
        let lower = 100 + start + plateau
        let range = lower..<(lower + activeSeconds)
        let frames = trace.frames.filter { range.contains($0.normalizedTime) }
        let unknownCount = frames.filter { $0.state == SustainFrame.State.uncertain }.count
        let unknown = Double(unknownCount) / Double(max(1, frames.count))
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 12),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100.2, maximumClockDriftSeconds: 0,
            attacks: collector.attacks, clipping: collector.clipping, uncertainSignal: collector.uncertainSignal,
            pitchContour: trace, analysisVersion: collector.analysisVersion)
        return (VibratoStatistics(frames: trace.frames, range: range, baseFrequency: frequency), unknown, try AssessmentEngine.evaluate(evidence))
    }
    @Test(arguments: [44100.0, 48000.0]) func harmonicPCMTracksWidthAndRateAtCandidateBounds(rate: Double) throws {
        for midi in [55, 81] {
            for width in [30, 100] {
                for speed in [1.0, 3.0] {
                    let (value, unknown, result) = try run(rate: rate, midi: midi, width: width, modulationRate: speed)
                    let label = "rate=\(rate) midi=\(midi) width=\(width) speed=\(speed) measured=\(String(describing: value)) unknown=\(unknown)"
                    #expect(result.validity == .valid && (result.vibratoScore ?? -1) > 95, "\(label), result=\(String(describing: result.vibrato))")
                    #expect(result.matchedCount == 1 && result.scoredExtras.isEmpty)
                    #expect(result.parameters.version == "monophonic-assessment-6" && result.evidence.configuration.capabilityVersion == "mono-capability-5")
                    #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
                    #expect(unknown <= 0.2, "\(label)")
                    #expect(abs((value.widthCents ?? 0) - Double(width)) <= max(10, Double(width) * 0.25), "\(label)")
                    #expect(abs((value.rateHz ?? 0) - speed) <= speed * 0.2, "\(label)")
                    #expect((value.periodVariation ?? 1) <= 0.2, "\(label)")
                }
            }
        }
    }
    @Test func knownWrongVibratoAndUnavailableSignalRemainDistinct() throws {
        for mode in ["flat", "wrong-width", "wrong-rate", "wrong-base", "silence", "noise", "clipped"] {
            let (_, _, result) = try run(rate: 48000, midi: 60, width: 50, modulationRate: 2, mode: mode)
            let label = "\(mode): \(String(describing: result.vibrato))"
            if ["noise", "clipped"].contains(mode) {
                #expect(result.validity == .insufficientSignal && result.vibratoScore == nil, "\(label)")
            } else {
                #expect(result.validity == .valid && (result.vibratoScore ?? 100) < 80, "\(label)")
                if mode == "silence" { #expect(result.vibratoScore == 0 && result.matchedCount == 0) }
            }
        }
    }

}
