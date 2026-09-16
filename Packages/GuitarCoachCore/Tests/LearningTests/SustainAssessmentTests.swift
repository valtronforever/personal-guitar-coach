import Foundation
import Testing
import Domain
@testable import Learning

struct SustainAssessmentTests {
    private func evidence(finish: Double = 1, wrongAfter: Double? = nil, uncertain: Bool = false,
                          traceIncluded: Bool = true, missed: Bool = false, calibrated: Bool = true,
                          offset: Double = 0, late: Double = 0, phase: PracticePhase = .completed) throws -> PracticeEvidence {
        let event = try MusicalEvent(id: "held", startTick: 0, durationTicks: 1920, kind: .note,
            positions: [FretPosition(string: 6, fret: 0)], assessSustain: true)
        let endpoint = try CalibrationEndpoint(uid: "sustain-test", channel: 1, sampleRate: 48000,
            bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "generated")
        let calibration = try calibrated ? CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: offset,
            uncertaintySeconds: 0.015, evidence: CalibrationEvidence(algorithmVersion: "generated", matchedPulses: 12,
                missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0)) : nil
        let config = try PracticeConfiguration(exercise: Exercise(id: "sustain", events: [event]), instrument: InstrumentProfile(),
            bpm: 60, route: route, calibration: calibration)
        let start = try config.expectedStart(renderEpochSeconds: 100) + offset + late
        let hz = try Pitch(midi: 40).frequency()
        let frames = try (0..<121).map { index -> SustainFrame in
            let elapsed = Double(index) * 0.02 - 0.1
            let state: SustainFrame.State = uncertain ? .uncertain : elapsed >= finish * 2 ? .silence : .pitched
            let frequency = hz * (elapsed >= (wrongAfter ?? .infinity) * 2 ? 2 : 1)
            return try SustainFrame(id: UInt64(index + 1), normalizedTime: start + elapsed, state: state, frequency: state == .pitched ? frequency : nil)
        }
        return try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 10),
            phase: phase, reason: phase == .completed ? nil : .dataLoss, signalConfirmed: true, renderEpochSeconds: 100,
            maximumClockDriftSeconds: 0, attacks: missed ? [] : [PracticeAttack(id: 1, normalizedOnset: start, frequency: hz, clarity: 0.99, reliable: true)],
            clipping: [], sustainTrace: traceIncluded ? SustainTrace(frames: frames) : nil, analysisVersion: "synthetic-sustain-test")
    }
    @Test func heldPitchScoresItsDurationAndUsesVersionedWeight() throws {
        let full = try AssessmentEngine.evaluate(evidence())
        #expect(full.validity == .valid && full.sustainScore == 100 && full.overallScore == 100)
        #expect(full.parameters.version == "monophonic-assessment-3")
        let short = try AssessmentEngine.evaluate(evidence(finish: 0.5))
        #expect(short.validity == .valid && short.pitchScore == 100 && short.timingScore == 100)
        #expect((44...48).contains(try #require(short.sustainScore)))
        #expect(short.overallScore == 89)
        #expect(FeedbackEngine.recommendations(for: short).contains { $0.kind == .sustain && $0.eventIDs == ["held"] })
        let detail = try #require(short.sustain?.notes.first)
        #expect((0.52...0.56).contains(try #require(detail.silentFraction)))
    }
    @Test func changedPitchDoesNotMasqueradeAsCorrectSustainOrSilence() throws {
        let result = try AssessmentEngine.evaluate(evidence(wrongAfter: 0.5))
        #expect((44...48).contains(try #require(result.sustainScore)))
        #expect(result.sustain?.notes.first?.silentFraction == 0)
        #expect(result.pitchScore == 100) // The initial attack was correct; the held portion was not.
    }
    @Test func missingOrUnreliableTraceNeverBecomesAPlayingErrorScore() throws {
        for input in [try evidence(uncertain: true), try evidence(traceIncluded: false)] {
            let result = try AssessmentEngine.evaluate(input)
            #expect(result.validity == .insufficientSignal && result.overallScore == nil && result.sustainScore == nil)
            #expect(result.sustain?.notes.first?.state == .uncertain)
            #expect(FeedbackEngine.recommendations(for: result).first?.kind == .signal)
            #expect(FeedbackEngine.recommendations(for: result).first?.evidenceCount == 1)
        }
        let interrupted = try AssessmentEngine.evaluate(evidence(phase: .interrupted))
        #expect(interrupted.validity == .interrupted && interrupted.sustainScore == nil)
    }
    @Test func durationUsesTheObservedAttackWithoutApplyingLatencyTwice() throws {
        let result = try AssessmentEngine.evaluate(evidence(offset: 0.12, late: 0.07))
        #expect(result.sustainScore == 100)
        #expect(abs(try #require(result.notes.first?.timingErrorSeconds) - 0.07) < 1e-6)
        let uncalibrated = try AssessmentEngine.evaluate(evidence(calibrated: false))
        #expect(uncalibrated.validity == .uncalibrated && uncalibrated.sustainScore == 100 && uncalibrated.overallScore == nil)
        let missed = try AssessmentEngine.evaluate(evidence(missed: true))
        #expect(missed.missedCount == 1 && missed.sustainScore == 0 && missed.sustain?.notes.first?.state == .missed)
    }
    @Test func evidenceAndResultRoundTripWithoutReratingAndRejectInvalidFractions() throws {
        let result = try AssessmentEngine.evaluate(evidence(finish: 0.5))
        #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        #expect(throws: AssessmentError.invalidResult) {
            try SustainNoteAssessment(id: "held", state: .measured, heldFraction: 0.8, silentFraction: 0.8, unknownFraction: 0)
        }
    }
}
