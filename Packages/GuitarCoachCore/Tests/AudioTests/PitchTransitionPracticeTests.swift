import Foundation
import Testing
import Domain
import Learning
@testable import Audio

struct PitchTransitionPracticeTests {
    private func run(rate: Double, kind: PitchTransition.Kind, mode: String = "correct", midi: Int = 60, semitones: Int = 2, plateauSeconds: Double = 1) throws -> AssessedPractice {
        let signed = kind == .pullOff ? -semitones : semitones
        let plateauTicks = Int64((plateauSeconds * 960).rounded())
        let transition = try PitchTransition(kind: kind, semitones: signed, startTick: plateauTicks, travelTicks: kind == .slide ? 960 : 0)
        let durationTicks = plateauTicks * 2 + transition.travelTicks
        let durationSeconds = plateauSeconds * 2 + (kind == .slide ? 1 : 0)
        let position = try #require(TuningProfile.standard.strings.compactMap { string -> FretPosition? in
            let fret = midi - string.openPitch.midi
            guard (1...24).contains(fret), (1...24).contains(fret + signed) else { return nil }
            return try? FretPosition(string: string.number, fret: fret)
        }.first)
        let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: durationTicks, kind: .note, positions: [position], pitchTransition: transition)
        let rest = try MusicalEvent(id: "rest", startTick: durationTicks, durationTicks: 3840 - durationTicks, kind: .rest)
        let endpoint = try CalibrationEndpoint(uid: "motion-generated", channel: 1, sampleRate: rate, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: MonophonicAnalyzer.algorithmVersion)
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "generated", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "motion-test", events: [event, rest]), instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let analyzer = try MonophonicAnalyzer(sampleRate: rate)
        var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
        let start = 0.2 + config.countInSeconds, frequency = try Pitch(midi: midi).frequency()
        var pcm: [Float] = [], phase = 0.0, random: UInt64 = 17
        for index in 0..<Int((start + 5) * rate) {
            let time = Double(index) / rate - start
            if time < 0 || time >= durationSeconds { pcm.append(0); continue }
            // Independent PCM: chromatic fret steps and instant legato, not the reference renderer.
            var cents = kind == .slide ? Double(signed * 100) * min(1, max(0, time - plateauSeconds)) : time < plateauSeconds ? 0 : Double(signed * 100)
            if kind == .slide && mode != "continuous" { cents = (cents / 100).rounded() * 100 }
            if mode == "stuck" { cents = 0 }
            if mode == "wrong-direction" { cents = -cents }
            if mode == "early-target", time >= plateauSeconds { cents = Double(signed * 100) }
            if mode == "jump-middle" { cents = time < plateauSeconds + 0.5 ? 0 : Double(signed * 100) }
            phase += 2 * .pi * frequency * pow(2, cents / 1200) / rate
            random = random &* 6364136223846793005 &+ 1
            let envelope = min(1, time / 0.005, (durationSeconds - time) / 0.005)
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
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 12),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100.2, maximumClockDriftSeconds: 0,
            attacks: collector.attacks, clipping: collector.clipping, uncertainSignal: collector.uncertainSignal,
            pitchContour: collector.pitchContourTrace(), analysisVersion: collector.analysisVersion)
        return try AssessmentEngine.evaluate(evidence)
    }
    @Test(arguments: [44100.0, 48000.0]) func frettedSlidesAndAbruptLegatoHaveMeasuredCoverage(rate: Double) throws {
        for kind in PitchTransition.Kind.allCases {
            let result = try run(rate: rate, kind: kind)
            #expect(result.validity == .valid && (result.pitchTransitionScore ?? -1) > 95, "\(kind), \(rate): \(String(describing: result.pitchTransitions))")
            #expect(result.matchedCount == 1 && result.scoredExtras.isEmpty)
            #expect(result.parameters.version == "monophonic-assessment-5")
            #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        }
        let continuous = try run(rate: rate, kind: .slide, mode: "continuous")
        #expect(continuous.validity == .valid && (continuous.pitchTransitionScore ?? -1) > 95)
    }
    @Test(arguments: [44100.0, 48000.0]) func conservativePitchBoundsTrackBothEndpoints(rate: Double) throws {
        for (kind, midi) in [(PitchTransition.Kind.slide, 55), (.slide, 81), (.hammerOn, 55), (.hammerOn, 81), (.pullOff, 57), (.pullOff, 81)] {
            let result = try run(rate: rate, kind: kind, midi: midi)
            #expect(result.validity == .valid && (result.pitchTransitionScore ?? -1) > 95, "\(kind), \(midi), \(rate): \(String(describing: result.pitchTransitions))")
        }
    }
    @Test(arguments: [44100.0, 48000.0]) func boundaryPlateausDescendingAndSingleFretSlidesRemainMeasured(rate: Double) throws {
        for kind in PitchTransition.Kind.allCases {
            let result = try run(rate: rate, kind: kind, plateauSeconds: 0.4)
            #expect(result.validity == .valid && (result.pitchTransitionScore ?? -1) > 95, "\(kind), minimum plateau, \(rate): \(String(describing: result.pitchTransitions))")
        }
        for semitones in [-2, -1, 1] {
            let result = try run(rate: rate, kind: .slide, semitones: semitones)
            #expect(result.validity == .valid && (result.pitchTransitionScore ?? -1) > 95, "slide \(semitones), \(rate): \(String(describing: result.pitchTransitions))")
        }
    }
    @Test func incorrectMotionAndUnavailableSignalRemainDistinct() throws {
        for mode in ["stuck", "wrong-direction", "early-target", "jump-middle", "silence", "noise", "clipped"] {
            let result = try run(rate: 48000, kind: .slide, mode: mode)
            if ["noise", "clipped"].contains(mode) {
                #expect(result.validity == .insufficientSignal && result.pitchTransitionScore == nil, "\(mode): \(String(describing: result.pitchTransitions))")
            } else {
                #expect(result.validity == .valid && (result.pitchTransitionScore ?? 100) < 80, "\(mode): \(String(describing: result.pitchTransitions))")
                if mode == "silence" { #expect(result.pitchTransitionScore == 0 && result.matchedCount == 0) }
            }
        }
    }
}
