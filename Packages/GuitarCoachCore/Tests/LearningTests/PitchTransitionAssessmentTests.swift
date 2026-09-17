import Foundation
import Testing
import Domain
@testable import Learning

struct PitchTransitionAssessmentTests {
    private func evidence(kind: PitchTransition.Kind = .slide, meter: TimeSignature = .fourFour,
                          mode: String = "correct", offset: Double = 0.12, late: Double = 0.07, calibrated: Bool = true) throws -> PracticeEvidence {
        let pulse = meter.pulseTicks
        let transition = try PitchTransition(kind: kind, semitones: kind == .pullOff ? -2 : 2, startTick: pulse, travelTicks: kind == .slide ? pulse : 0)
        let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: pulse * 3, kind: .note, positions: [FretPosition(string: 3, fret: 7)], pitchTransition: transition)
        let rest = try MusicalEvent(id: "rest", startTick: pulse * 3, durationTicks: pulse, kind: .rest)
        let endpoint = try CalibrationEndpoint(uid: "motion-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let calibration = try calibrated ? CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: offset, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0)) : nil
        let config = try PracticeConfiguration(exercise: Exercise(id: "motion", events: [event, rest], timeSignature: meter),
            instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let onset = 100 + Double(meter.beatsPerBar) + offset + late, hz = 293.6647679174076
        let frames = try (0..<211).map { index -> SustainFrame in
            let seconds = Double(index) * 0.02 - 0.1
            let sign = kind == .pullOff ? -1.0 : 1.0
            var cents = kind == .slide ? min(200, max(0, (seconds - 1) * 200)) : seconds < 1 ? 0.0 : sign * 200
            if mode == "fretted" { cents = (cents / 100).rounded() * 100 }
            if mode == "stuck" { cents = 0 }
            if mode == "wrong-direction" { cents = -cents }
            if mode == "early-target", seconds >= 1 { cents = sign * 200 }
            if mode == "jump-middle" { cents = seconds < 1.5 ? 0 : sign * 200 }
            if mode == "late-change", kind != .slide { cents = seconds < 1.7 ? 0 : sign * 200 }
            let unknown = mode == "unknown" && (2...3).contains(seconds)
            let silent = mode == "silence"
            return try SustainFrame(id: UInt64(index + 1), normalizedTime: onset + seconds,
                state: unknown ? .uncertain : silent ? .silence : .pitched,
                frequency: unknown || silent ? nil : hz * pow(2, cents / 1200))
        }
        return try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 20),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: [PracticeAttack(id: 1, normalizedOnset: onset, frequency: hz, clarity: 0.99, reliable: true),
                PracticeAttack(id: 2, normalizedOnset: onset + 1.2, frequency: nil, clarity: nil, reliable: false),
                PracticeAttack(id: 3, normalizedOnset: onset + 3.5, frequency: hz, clarity: 0.99, reliable: true)],
            clipping: [], pitchContour: mode == "missing" ? nil : PitchContourTrace(frames: frames), analysisVersion: "fixture")
    }
    @Test func independentContoursUseActualPulseAndCompensateInitialAttackOnlyOnce() throws {
        for kind in PitchTransition.Kind.allCases {
            for meter in TimeSignature.allCases {
                let input = try evidence(kind: kind, meter: meter), result = try AssessmentEngine.evaluate(input)
                #expect(result.validity == .valid && result.pitchTransitionScore == 100)
                #expect(result.parameters == .withPitchTransitions && result.bends == nil)
                #expect(abs(try #require(result.notes.first?.timingErrorSeconds) - 0.07) < 1e-7)
                #expect(result.pitchTransitions?.notes.first?.normalizedStart == input.attacks[0].normalizedOnset)
                #expect(result.extras.map(\.id) == [2, 3] && result.scoredExtras.map(\.id) == [3])
                #expect(result.uncertainExtraCount == 0 && result.scoredExtras.first?.restID == "rest")
                #expect(result.pitchTransitions?.notes.first?.phases.map(\.kind) == (kind == .slide ? [.base, .travel, .target] : [.base, .target]))
                #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
            }
        }
        let fretted = try AssessmentEngine.evaluate(evidence(mode: "fretted"))
        #expect(fretted.pitchTransitionScore == 100)
        let uncalibrated = try AssessmentEngine.evaluate(evidence(offset: 0, late: 0, calibrated: false))
        #expect(uncalibrated.validity == .uncalibrated && uncalibrated.pitchTransitionScore == 100 && uncalibrated.overallScore == nil)
    }
    @Test func wrongPitchTimingAndUnknownEvidenceHaveDifferentResults() throws {
        for mode in ["stuck", "wrong-direction", "early-target", "jump-middle", "silence", "missing", "unknown"] {
            let result = try AssessmentEngine.evaluate(evidence(mode: mode))
            if ["missing", "unknown"].contains(mode) {
                #expect(result.validity == .insufficientSignal && result.pitchTransitionScore == nil && result.overallScore == nil)
                #expect(FeedbackEngine.recommendations(for: result).first?.kind == .signal)
                #expect(FeedbackEngine.recommendations(for: result).first?.evidenceCount == 1)
            } else {
                #expect(result.validity == .valid && (result.pitchTransitionScore ?? 100) < 80, "\(mode): \(String(describing: result.pitchTransitions))")
                #expect(FeedbackEngine.recommendations(for: result).contains { $0.kind == .pitchTransition && $0.eventIDs == ["motion"] })
                if mode == "silence" { #expect(result.pitchTransitionScore == 0) }
            }
        }
        for kind in [PitchTransition.Kind.hammerOn, .pullOff] {
            let result = try AssessmentEngine.evaluate(evidence(kind: kind, mode: "late-change"))
            #expect((result.pitchTransitionScore ?? 100) < 85)
            #expect((result.pitchTransitions?.notes.first?.phases.last?.matchedFraction ?? 1) < 0.7)
        }
    }
    @Test func archivedVersionsAndPhaseKindsCannotBeSubstituted() throws {
        let result = try AssessmentEngine.evaluate(evidence())
        let encoded = try JSONEncoder().encode(result)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var parameters = try #require(object["parameters"] as? [String: Any])
        parameters["version"] = "monophonic-assessment-4"; object["parameters"] = parameters
        #expect(throws: AssessmentError.invalidResult) { try JSONDecoder().decode(AssessedPractice.self, from: JSONSerialization.data(withJSONObject: object)) }
        let measured = try PitchTransitionPhaseAssessment(kind: .base, matchedFraction: 1, silentFraction: 0, unknownFraction: 0, medianErrorCents: 0)
        #expect(throws: AssessmentError.invalidResult) { try PitchTransitionNoteAssessment(id: "motion", kind: .slide, normalizedStart: 1, phases: [measured, measured]) }
        #expect(throws: AssessmentError.invalidResult) { try PitchTransitionPhaseAssessment(kind: .target, matchedFraction: 1, silentFraction: 0, unknownFraction: 0.3, medianErrorCents: 0) }
    }
}
