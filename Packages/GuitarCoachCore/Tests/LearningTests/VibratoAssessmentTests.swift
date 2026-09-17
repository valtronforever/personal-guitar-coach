import Foundation
import Testing
import Domain
@testable import Learning

struct VibratoAssessmentTests {
    private func evidence(meter: TimeSignature = .fourFour,
                          mode: String = "correct", offset: Double = 0.12, late: Double = 0.07, calibrated: Bool = true) throws -> PracticeEvidence {
        let pulse = meter.pulseTicks
        let vibrato = try PitchVibrato(extentCents: 80, startTick: pulse, endTick: pulse * 3, periodTicks: pulse / 2)
        let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: pulse * 4, kind: .note, positions: [FretPosition(string: 3, fret: 7)], vibrato: vibrato)
        let rest = try MusicalEvent(id: "rest", startTick: pulse * 4, durationTicks: pulse, kind: .rest)
        let endpoint = try CalibrationEndpoint(uid: "motion-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let calibration = try calibrated ? CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: offset, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0)) : nil
        let config = try PracticeConfiguration(exercise: Exercise(id: "motion", events: [event, rest], timeSignature: meter),
            instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let onset = 100 + Double(meter.beatsPerBar) + offset + late, hz = 293.6647679174076
        let frames = try (0..<261).map { index -> SustainFrame in
            let seconds = Double(index) * 0.02 - 0.1
            let active = seconds - 1
            let phase = mode == "irregular" && active > 1 ? 2 + (active - 1) : active * 2
            var cents = (0..<2).contains(active) ? 40 * (1 - cos(2 * .pi * phase)) : 0
            if mode == "flat" { cents = 0 }
            if mode == "wrong-width" { cents *= 2 }
            if mode == "wrong-base" { cents += 80 }
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
                PracticeAttack(id: 3, normalizedOnset: onset + 4.5, frequency: hz, clarity: 0.99, reliable: true)],
            clipping: [], pitchContour: mode == "missing" ? nil : PitchContourTrace(frames: frames), analysisVersion: "fixture")
    }
    @Test func actualPulseLatencyOnceAndInternalFluxAreHandled() throws {
        for meter in TimeSignature.allCases {
            let input = try evidence(meter: meter), result = try AssessmentEngine.evaluate(input)
            #expect(result.validity == .valid && result.vibratoScore == 100)
            #expect(result.parameters == .withVibrato && result.bends == nil && result.pitchTransitions == nil)
            let error = try #require(result.notes.first?.timingErrorSeconds)
            #expect(abs(error - 0.07) < 1e-7)
            #expect(result.vibrato?.notes.first?.normalizedStart == input.attacks[0].normalizedOnset)
            #expect(result.extras.map(\.id) == [2, 3] && result.scoredExtras.map(\.id) == [3])
            #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        }
        let uncalibrated = try AssessmentEngine.evaluate(evidence(offset: 0, late: 0, calibrated: false))
        #expect(uncalibrated.validity == .uncalibrated && uncalibrated.vibratoScore == 100 && uncalibrated.overallScore == nil)
    }
    @Test func unavailableContourDoesNotMasqueradeAsBadTechnique() throws {
        for mode in ["flat", "wrong-width", "wrong-base", "irregular", "silence", "missing", "unknown"] {
            let result = try AssessmentEngine.evaluate(evidence(mode: mode))
            if ["missing", "unknown"].contains(mode) {
                #expect(result.validity == .insufficientSignal && result.vibratoScore == nil && result.overallScore == nil)
                #expect(FeedbackEngine.recommendations(for: result).first?.kind == .signal)
                #expect(FeedbackEngine.recommendations(for: result).first?.evidenceCount == 1)
            } else {
                #expect(result.validity == .valid && (result.vibratoScore ?? 100) < 80, "\(mode): \(String(describing: result.vibrato))")
                #expect(FeedbackEngine.recommendations(for: result).contains { $0.kind == .vibrato && $0.eventIDs == ["motion"] })
                if mode == "silence" { #expect(result.vibratoScore == 0) }
            }
        }
    }
    @Test func oldAlgorithmVersionAndInvalidMetricsCannotBeSubstituted() throws {
        let result = try AssessmentEngine.evaluate(evidence())
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        var parameters = try #require(object["parameters"] as? [String: Any])
        parameters["version"] = "monophonic-assessment-5"; object["parameters"] = parameters
        #expect(throws: AssessmentError.invalidResult) { try JSONDecoder().decode(AssessedPractice.self, from: JSONSerialization.data(withJSONObject: object)) }
        #expect(throws: AssessmentError.invalidResult) { try VibratoModulationMetrics(lowCents: 0, widthCents: -1, rateHz: nil, periodVariation: nil, measuredPeriods: 0) }
        #expect(throws: AssessmentError.invalidResult) { try VibratoModulationMetrics(lowCents: 0, widthCents: 80, rateHz: 2, periodVariation: 0, measuredPeriods: 1) }
        #expect(throws: AssessmentError.invalidResult) { try VibratoModulationMetrics(lowCents: 0, widthCents: 80, rateHz: nil, periodVariation: nil, measuredPeriods: 2) }
    }
}
