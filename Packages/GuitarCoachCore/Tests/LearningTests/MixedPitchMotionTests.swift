import Foundation
import Testing
import Domain
@testable import Learning

struct MixedPitchMotionTests {
    @Test func movingNotesShareWeightBeforeSustainAndRoundTripWithoutRescoring() throws {
        let position = try FretPosition(string: 3, fret: 9)
        let events = try [
            MusicalEvent(id: "bend", startTick: 0, durationTicks: 2880, kind: .note, positions: [position], bend: PitchBend(semitones: 2, riseStartTick: 480, riseEndTick: 960)),
            MusicalEvent(id: "rest1", startTick: 2880, durationTicks: 960, kind: .rest),
            MusicalEvent(id: "hammer", startTick: 3840, durationTicks: 2880, kind: .note, positions: [position], pitchTransition: PitchTransition(kind: .hammerOn, semitones: 2, startTick: 960)),
            MusicalEvent(id: "rest2", startTick: 6720, durationTicks: 960, kind: .rest),
            MusicalEvent(id: "held", startTick: 7680, durationTicks: 1920, kind: .note, positions: [position], assessSustain: true),
            MusicalEvent(id: "rest3", startTick: 9600, durationTicks: 1920, kind: .rest)
        ]
        let endpoint = try CalibrationEndpoint(uid: "mixed-motion", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "mixed", events: events), instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let start = 104.0, hz = 329.6275569128699
        let contour = try (0..<611).map { i -> SustainFrame in
            let t = Double(i) * 0.02 - 0.1
            // Correct first bend; the later hammer-on never changes pitch.
            let cents = t < 0.5 ? 0 : t < 1 ? (t - 0.5) * 400 : t < 3 ? 200 : 0
            return try SustainFrame(id: UInt64(i + 1), normalizedTime: start + t, state: .pitched, frequency: hz * pow(2, cents / 1200))
        }
        let sustain = try contour.map { try SustainFrame(id: $0.id, normalizedTime: $0.normalizedTime, state: .pitched, frequency: hz) }
        let attacks = try [0.0,4,8].enumerated().map { try PracticeAttack(id: UInt64($0.offset + 1), normalizedOnset: start + $0.element, frequency: hz, clarity: 0.99, reliable: true) }
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 30),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: attacks, clipping: [], sustainTrace: SustainTrace(frames: sustain), pitchContour: PitchContourTrace(frames: contour), analysisVersion: "fixture")
        let result = try AssessmentEngine.evaluate(evidence)
        #expect(result.validity == .valid && result.pitchScore == 100 && result.timingScore == 100)
        #expect(result.bendScore == 100 && result.pitchTransitionScore == 50 && result.sustainScore == 100)
        // Mean moving-note score = 75; attack/motion 50:50 = 87.5; sustain 80:20 = 90.
        #expect(result.overallScore == 90 && result.parameters == .withPitchTransitions)
        #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        #expect(FeedbackEngine.recommendations(for: result).first?.kind == .pitchTransition)
    }
}
