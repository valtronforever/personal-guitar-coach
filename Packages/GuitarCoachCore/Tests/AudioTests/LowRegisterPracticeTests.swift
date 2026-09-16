import Foundation
import Testing
import Domain
import Learning
import AudioTestSupport
@testable import Audio

struct LowRegisterPracticeTests {
    @Test(arguments: [44100.0, 48000.0])
    func repeatedA1TraversesPCMCollectorAndAssessmentWithoutDroppingAttacks(rate: Double) throws {
        for (ticks, bpm, harmonics) in [(Int64(480),150.0,[1.0,0.4,0.2,0.1]), (960,200,[0.25,1,0.1]), (960,120,[0.25,1,0.1])] {
            let endpoint = try CalibrationEndpoint(uid: "generated-low-register", channel: 1, sampleRate: rate,
                bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
            let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: MonophonicAnalyzer.algorithmVersion)
            let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0,
                uncertaintySeconds: 0.015, evidence: CalibrationEvidence(algorithmVersion: "generated-test-clock",
                    matchedPulses: 12, missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
            let events = try (0..<4).map { try MusicalEvent(id: "note-\($0)", startTick: Int64($0)*ticks,
                durationTicks: ticks, kind: .note, positions: [FretPosition(string: 6, fret: 0)]) }
            let config = try PracticeConfiguration(exercise: Exercise(id: "low-repeats", events: events),
                instrument: InstrumentProfile(tuning: .dropA), bpm: bpm, route: route, calibration: calibration)
            let analyzer = try MonophonicAnalyzer(sampleRate: rate)
            var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
            let duration = try MusicalTime.seconds(forTicks: ticks, bpm: bpm)
            let notes = (0..<4).map { SyntheticNote(onset: 0.2 + config.countInSeconds + Double($0)*duration,
                duration: duration, frequency: 55, harmonics: harmonics) }
            let signal = SyntheticAudio.render(rate: rate, duration: 0.2 + config.countInSeconds + duration*4 + 1.5, notes: notes)
            for start in stride(from: 0, to: signal.count, by: 769) {
                signal.withUnsafeBufferPointer { ptr in
                    analyzer.process(.init(rebasing: ptr[start..<min(start + 769, ptr.count)]), startHostSeconds: 100 + Double(start)/rate)
                }
                try collector.consume(analyzer.snapshot(), renderEpochSeconds: 100.2)
            }
            #expect(try collector.hasResolvedTail(renderEpochSeconds: 100.2))
            let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
                finishedAt: Date(timeIntervalSince1970: 10), phase: .completed, reason: nil, signalConfirmed: true,
                renderEpochSeconds: 100.2, maximumClockDriftSeconds: 0, attacks: collector.attacks, clipping: collector.clipping,
                uncertainSignal: collector.uncertainSignal, analysisVersion: collector.analysisVersion)
            let report = try AssessmentEngine.evaluate(evidence)
            #expect(report.validity == .valid)
            #expect(report.matchedCount == 4 && report.missedCount == 0 && report.extras.isEmpty)
            #expect(report.notes.allSatisfy { abs($0.centsError ?? 1000) < 15 && abs($0.timingErrorSeconds ?? 1) <= 0.03 })
            // Estimated pitch has finite error; the score is continuous, not rounded to 100.
            #expect(try #require(report.pitchScore) >= 95)
            #expect(config.capabilityVersion == "mono-capability-2" && evidence.analysisVersion == "mono-mpm-flux-4")
        }
    }
}
