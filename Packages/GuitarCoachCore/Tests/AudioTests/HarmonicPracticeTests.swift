import Foundation
import Testing
import Domain
import Learning
import AudioTestSupport
@testable import Audio

struct HarmonicPracticeTests {
    private func run(rate: Double, partial: Int = 3, artificial: Bool = false, mode: String = "correct") throws -> AssessedPractice {
        let harmonic = try HarmonicNote(kind: artificial ? .artificial : .natural, partial: partial)
        let position = try FretPosition(string: 3, fret: artificial ? 5 : harmonic.nodeOffset)
        let event = try MusicalEvent(id: "harmonic", startTick: 0, durationTicks: 1920, kind: .note, positions: [position], assessSustain: mode == "sustain", harmonic: harmonic)
        let rest = try MusicalEvent(id: "rest", startTick: 1920, durationTicks: 1920, kind: .rest)
        let endpoint = try CalibrationEndpoint(uid: "synthetic-harmonic", channel: 1, sampleRate: rate, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: MonophonicAnalyzer.algorithmVersion)
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "synthetic-clock", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "harmonic", events: [event,rest]), instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        // Independent base frequencies: G3 open or C4 stopped, not production target math.
        let ideal = (artificial ? 261.6255653005986 : 195.99771799087463) * Double(partial)
        let frequency = mode == "stopped" ? 440 * pow(2, Double(55 + position.fret - 69) / 12) : mode == "base" ? 195.99771799087463 : ideal
        let start = 0.2 + config.countInSeconds
        let notes = mode == "silence" || mode == "noise" ? [] : [SyntheticNote(onset: start, duration: 2, frequency: frequency, amplitude: mode == "clipped" ? 5 : 0.25, harmonics: [1,0.15,0.05])]
        let pcm = SyntheticAudio.render(rate: rate, duration: start + 5.5, notes: notes, noise: mode == "noise" ? 0.2 : 0, clip: mode == "clipped")
        let analyzer = try MonophonicAnalyzer(sampleRate: rate)
        var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
        for frame in stride(from: 0, to: pcm.count, by: 769) {
            pcm.withUnsafeBufferPointer { ptr in analyzer.process(.init(rebasing: ptr[frame..<min(frame + 769, ptr.count)]), startHostSeconds: 100 + Double(frame) / rate) }
            try collector.consume(analyzer.snapshot(), renderEpochSeconds: 100.2)
        }
        #expect(try collector.hasResolvedTail(renderEpochSeconds: 100.2))
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 12),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100.2, maximumClockDriftSeconds: 0,
            attacks: collector.attacks, clipping: collector.clipping, uncertainSignal: collector.uncertainSignal, sustainTrace: collector.sustainTrace(), analysisVersion: collector.analysisVersion)
        let result = try AssessmentEngine.evaluate(evidence)
        #expect(abs(result.notes[0].targetFrequency - ideal) < 1e-9)
        #expect(result.parameters == .withHarmonics && config.capabilityVersion == MonophonicCapability.harmonicVersion)
        #expect(evidence.analysisVersion == "mono-mpm-flux-4")
        #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        return result
    }

    @Test(arguments: [44100.0,48000.0]) func isolatedPartialsReachTheExistingPCMCollectorAndExactTargetGrade(rate: Double) throws {
        for (partial,artificial) in [(2,false),(3,false),(4,false),(2,true)] {
            let result = try run(rate: rate, partial: partial, artificial: artificial)
            #expect(result.validity == .valid && result.matchedCount == 1 && result.scoredExtras.isEmpty)
            #expect((result.pitchScore ?? 0) > 95)
            #expect(abs(result.notes[0].timingErrorSeconds ?? 1) < 0.04)
        }
    }
    @Test func stoppedNotesOpenFundamentalsAndInvalidSignalDoNotBecomeHarmonicSuccess() throws {
        for mode in ["stopped","base","silence","noise","clipped"] {
            let result = try run(rate: 48000, mode: mode)
            if mode == "noise" || mode == "clipped" {
                #expect(result.validity == .insufficientSignal && result.pitchScore == nil, "\(mode): \(result)")
            } else {
                #expect(result.validity == .valid && result.pitchScore == 0, "\(mode): \(result)")
            }
        }
    }
    @Test func harmonicSustainAndFrozenTargetsDoNotFallBackToStoppedFretMath() throws {
        let result = try run(rate: 48000, partial: 3, mode: "sustain")
        #expect(result.validity == .valid && (result.sustainScore ?? 0) > 95)
        #expect(result.sustain?.notes.count == 1 && result.evidence.sustainTrace != nil)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        var parameters = try #require(object["parameters"] as? [String: Any]); parameters["version"] = AssessmentParameters.current.version
        object["parameters"] = parameters
        #expect(throws: (any Error).self) { try JSONDecoder().decode(AssessedPractice.self, from: JSONSerialization.data(withJSONObject: object)) }
        object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        var notes = try #require(object["notes"] as? [[String: Any]])
        notes[0]["targetFrequency"] = 587.3295358348151 // Equal-tempered D5 is not the frozen exact third partial.
        object["notes"] = notes
        #expect(throws: (any Error).self) { try JSONDecoder().decode(AssessedPractice.self, from: JSONSerialization.data(withJSONObject: object)) }
    }
    @Test func thirdPartialReferenceUsesIdealFrequencyAndPreservesPhaseAcrossChunksSeekAndLoops() throws {
        let event = try MusicalEvent(id: "third", startTick: 0, durationTicks: 3840, kind: .note,
            positions: [FretPosition(string: 3, fret: 7)], harmonic: HarmonicNote(kind: .natural, partial: 3))
        let exercise = try Exercise(id: "reference", events: [event])
        for rate in [44100.0,48000.0] {
            let request = try TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, clickEnabled: false)
            let plan = try TransportPlan(request: request, sampleRate: rate)
            let start = Int64(rate), large = try plan.render(startFrame: start, count: 12000)
            var chunks: [Float] = []
            for offset in stride(from: 0, to: 12000, by: 769) { chunks += try plan.render(startFrame: start + Int64(offset), count: min(769,12000-offset)) }
            #expect(chunks == large)
            let frequency = 195.99771799087463 * 3
            for index in [0,317,4000,11000] {
                let seconds = Double(start + Int64(index)) / rate
                #expect(abs(Double(large[index]) - sin(2 * .pi * frequency * seconds) * 0.1) < 1e-6)
            }
            let seek = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, startTick: 960, countInBars: 0, clickEnabled: false), sampleRate: rate)
            #expect(try seek.render(startFrame: 0, count: 12000) == large)
            let loop = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, loops: true, clickEnabled: false), sampleRate: rate)
            #expect(try loop.render(startFrame: Int64(rate * 5), count: 12000) == large)
            let practice = try TransportPlan(request: TransportRequest(exercise: exercise, tuning: .standard, bpm: 60, countInBars: 0, mode: .practice, clickEnabled: false), sampleRate: rate)
            #expect(try practice.render(startFrame: 0, count: 48000).allSatisfy { $0 == 0 })
        }
    }
}
