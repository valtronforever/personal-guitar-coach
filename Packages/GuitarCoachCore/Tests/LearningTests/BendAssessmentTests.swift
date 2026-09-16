import Foundation
import Testing
import Domain
@testable import Learning

struct BendAssessmentTests {
    private func evidence(offset: Double = 0, late: Double = 0, calibrated: Bool = true,
                          missing: Bool = false, uncertainTarget: Bool = false, omitReturn: Bool = false) throws -> PracticeEvidence {
        let bend = try PitchBend(semitones: 2, riseStartTick: 480, riseEndTick: 960, releaseStartTick: 1920, releaseEndTick: 2400)
        let event = try MusicalEvent(id: "bend", startTick: 0, durationTicks: 2880, kind: .note, positions: [FretPosition(string: 3, fret: 9)], bend: bend)
        let endpoint = try CalibrationEndpoint(uid: "bend-domain", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let calibration = try calibrated ? CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: offset,
            uncertaintySeconds: 0.015, evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0,
                extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0)) : nil
        let config = try PracticeConfiguration(exercise: Exercise(id: "bend", events: [event, MusicalEvent(id: "rest", startTick: 2880, durationTicks: 960, kind: .rest)]), instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let start = try config.expectedStart(renderEpochSeconds: 100) + offset + late, hz = try Pitch(midi: 64).frequency()
        let frames = try (0..<161).map { index -> SustainFrame in
            let t = Double(index) * 0.02 - 0.1
            let up = t < 0.5 ? 0 : t < 1 ? 400 * (t - 0.5) : 200
            let cents = t > 2 && !omitReturn ? max(0, 200 - 400 * (t - 2)) : up
            let unknown = uncertainTarget && (1...2).contains(t)
            return try SustainFrame(id: UInt64(index + 1), normalizedTime: start + t,
                state: unknown ? .uncertain : .pitched, frequency: unknown ? nil : hz * pow(2, cents / 1200))
        }
        return try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 10),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: [PracticeAttack(id: 1, normalizedOnset: start, frequency: hz, clarity: 0.99, reliable: true),
                      PracticeAttack(id: 2, normalizedOnset: start + 1.2, frequency: nil, clarity: nil, reliable: false),
                      PracticeAttack(id: 3, normalizedOnset: start + 3.5, frequency: hz, clarity: 0.99, reliable: true)],
            clipping: [], pitchContour: missing ? nil : PitchContourTrace(frames: frames), analysisVersion: "fixture")
    }
    @Test func latencyAppliesOnceAndDynamicObservationsDoNotBecomeExtraPickErrors() throws {
        let result = try AssessmentEngine.evaluate(evidence(offset: 0.12, late: 0.07))
        #expect(result.validity == .valid && result.bendScore == 100)
        #expect(abs(try #require(result.notes.first?.timingErrorSeconds) - 0.07) < 1e-7)
        #expect(result.extras.map(\.id) == [2, 3] && result.scoredExtras.map(\.id) == [3])
        #expect(result.uncertainExtraCount == 0 && result.scoredExtras.first?.restID == "rest")
        let uncalibrated = try AssessmentEngine.evaluate(evidence(calibrated: false))
        #expect(uncalibrated.validity == .uncalibrated && uncalibrated.bendScore == 100 && uncalibrated.overallScore == nil)
    }
    @Test func everyPhaseNeedsReliableEvidenceAndMissingReturnGetsSpecificAdvice() throws {
        for input in [try evidence(missing: true), try evidence(uncertainTarget: true)] {
            let result = try AssessmentEngine.evaluate(input)
            #expect(result.validity == .insufficientSignal && result.bendScore == nil && result.overallScore == nil)
            #expect(FeedbackEngine.recommendations(for: result).first?.kind == .signal)
            #expect(FeedbackEngine.recommendations(for: result).first?.evidenceCount == 1)
        }
        let result = try AssessmentEngine.evaluate(evidence(omitReturn: true))
        #expect((result.bendScore ?? 100) < 70)
        #expect(result.bends?.notes.first?.phases.last?.matchedFraction == 0)
        #expect(FeedbackEngine.recommendations(for: result).contains { $0.kind == .bend && $0.eventIDs == ["bend"] })
        #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        #expect(throws: AssessmentError.invalidResult) { try BendPhaseAssessment(kind: .target, matchedFraction: 1, silentFraction: 0, unknownFraction: 0.3, medianErrorCents: 0) }
    }
}
