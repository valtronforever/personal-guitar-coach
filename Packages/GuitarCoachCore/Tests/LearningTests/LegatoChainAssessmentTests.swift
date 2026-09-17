import Foundation
import Testing
import Domain
@testable import Learning

struct LegatoChainAssessmentTests {
    private func evidence(mode: String = "correct", meter: TimeSignature = .fourFour, calibrated: Bool = true) throws -> PracticeEvidence {
        let pulse = meter.pulseTicks
        let chain = try LegatoChain(targets: [
            .init(kind: .hammerOn, semitones: 3, startTick: pulse),
            .init(kind: .tap, semitones: 4, startTick: pulse * 2),
            .init(kind: .pullOff, semitones: -4, startTick: pulse * 3),
            .init(kind: .pullOff, semitones: -3, startTick: pulse * 4)])
        let event = try MusicalEvent(id: "chain", startTick: 0, durationTicks: pulse * 5, kind: .note,
            positions: [FretPosition(string: 3, fret: 5)], legatoChain: chain)
        let rest = try MusicalEvent(id: "rest", startTick: pulse * 5, durationTicks: pulse, kind: .rest)
        let endpoint = try CalibrationEndpoint(uid: "chain-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let offset = calibrated ? 0.12 : 0.0, late = 0.07
        let calibration = try calibrated ? CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: offset, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0)) : nil
        let config = try PracticeConfiguration(exercise: Exercise(id: "chain", events: [event, rest], timeSignature: meter),
            instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let onset = 100 + config.countInSeconds + offset + late, hz = 261.6255653005986
        let frames = try (0...310).map { index -> SustainFrame in
            let seconds = Double(index) * 0.02 - 0.1
            // Independent C4, Eb4, G4, Eb4, C4 plateaus.
            let noteIndex = min(4, max(0, Int(floor(seconds))))
            var cents = [0.0, 300, 700, 300, 0][noteIndex]
            if mode == "skipped", noteIndex == 1 || noteIndex == 3 { cents = 700 }
            if mode == "late", (1..<1.7).contains(seconds) { cents = 0 }
            if mode == "stuck" { cents = 0 }
            let unknown = mode == "unknown" && noteIndex == 2
            let silent = mode == "silence" || mode == "missing-middle" && noteIndex == 2
            return try SustainFrame(id: UInt64(index + 1), normalizedTime: onset + seconds,
                state: unknown ? .uncertain : silent ? .silence : .pitched, frequency: unknown || silent ? nil : hz * pow(2, cents / 1200))
        }
        return try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 20),
            phase: mode == "unconfirmed" ? .preflightFailed : mode == "interrupted" ? .cancelled : .completed,
            reason: mode == "unconfirmed" ? .noTestSignal : mode == "interrupted" ? .userCancelled : nil,
            signalConfirmed: mode != "unconfirmed", renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: [PracticeAttack(id: 1, normalizedOnset: onset, frequency: hz, clarity: 0.99, reliable: true),
                PracticeAttack(id: 2, normalizedOnset: onset + 1.2, frequency: nil, clarity: nil, reliable: false),
                PracticeAttack(id: 3, normalizedOnset: onset + 3.1, frequency: hz, clarity: 0.99, reliable: true),
                PracticeAttack(id: 4, normalizedOnset: onset + 5.5, frequency: hz, clarity: 0.99, reliable: true)],
            clipping: [], pitchContour: mode == "missing" ? nil : PitchContourTrace(frames: frames), analysisVersion: "fixture")
    }
    @Test func everyPlateauUsesActualPulseOneAttackAndOneCalibrationOffset() throws {
        for meter in TimeSignature.allCases {
            let input = try evidence(meter: meter), result = try AssessmentEngine.evaluate(input)
            #expect(result.validity == .valid && result.legatoChainScore == 100)
            #expect(result.parameters == .withLegatoChains && input.configuration.capabilityVersion == MonophonicCapability.legatoChainVersion)
            #expect(result.notes.count == 1 && result.matchedCount == 1)
            #expect(abs(try #require(result.notes.first?.timingErrorSeconds) - 0.07) < 1e-7)
            #expect(result.legatoChains?.notes.first?.normalizedStart == input.attacks[0].normalizedOnset)
            #expect(result.legatoChains?.notes.first?.semitoneOffsets == [0, 3, 7, 3, 0])
            #expect(result.extras.map(\.id) == [2, 3, 4] && result.scoredExtras.map(\.id) == [4])
            #expect(result.uncertainExtraCount == 0 && result.scoredExtras.first?.restID == "rest")
            #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        }
        let result = try AssessmentEngine.evaluate(evidence(calibrated: false))
        #expect(result.validity == .uncalibrated && result.legatoChainScore == 100 && result.timingScore == nil && result.overallScore == nil)
    }
    @Test func skippedSilentLateAndUnknownPlateausRemainDistinct() throws {
        for mode in ["skipped", "late", "stuck", "silence", "missing-middle", "unknown", "missing", "unconfirmed", "interrupted"] {
            let result = try AssessmentEngine.evaluate(evidence(mode: mode))
            if ["unknown", "missing", "unconfirmed", "interrupted"].contains(mode) {
                #expect(result.legatoChainScore == nil && result.overallScore == nil)
                #expect(result.validity == (mode == "interrupted" ? .interrupted : .insufficientSignal))
                if mode == "unknown" || mode == "missing" {
                    #expect(FeedbackEngine.recommendations(for: result).first?.eventIDs == ["chain"])
                }
            } else {
                #expect(result.validity == .valid && (result.legatoChainScore ?? 100) < 100)
                #expect(FeedbackEngine.recommendations(for: result).contains { $0.kind == .legatoChain && $0.eventIDs == ["chain"] })
                if mode == "silence" { #expect(result.legatoChainScore == 0) }
                if mode == "missing-middle" { #expect(result.legatoChains?.notes.first?.phases[2].silentFraction == 1) }
            }
        }
    }
    @Test func frozenOffsetsPhasesAndAlgorithmVersionsMustMatchTheExercise() throws {
        let result = try AssessmentEngine.evaluate(evidence())
        let data = try JSONEncoder().encode(result)
        let source = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for mutation in ["offset", "count", "version", "missing"] {
            var object = source
            if mutation == "version" {
                var parameters = try #require(object["parameters"] as? [String: Any]); parameters["version"] = "monophonic-assessment-6"; object["parameters"] = parameters
            } else if mutation == "missing" { object.removeValue(forKey: "legatoChains") }
            else {
                var chains = try #require(object["legatoChains"] as? [String: Any])
                var notes = try #require(chains["notes"] as? [[String: Any]])
                notes[0]["semitoneOffsets"] = mutation == "count" ? [0, 3, 7] : [0, 2, 7, 3, 0]
                chains["notes"] = notes; object["legatoChains"] = chains
            }
            #expect(throws: AssessmentError.invalidResult) { try JSONDecoder().decode(AssessedPractice.self, from: JSONSerialization.data(withJSONObject: object)) }
        }
    }
}

extension LegatoChainAssessmentTests {
    @Test func mixedMovingTechniquesKeepOnePerEventWeightAndFreezeAllResults() throws {
        let base = try FretPosition(string: 3, fret: 5)
        let events = try [
            MusicalEvent(id: "chain", startTick: 0, durationTicks: 3840, kind: .note, positions: [base],
                legatoChain: LegatoChain(targets: [.init(kind: .hammerOn, semitones: 2, startTick: 960), .init(kind: .pullOff, semitones: -2, startTick: 1920)])),
            MusicalEvent(id: "transition", startTick: 3840, durationTicks: 3840, kind: .note, positions: [base],
                pitchTransition: PitchTransition(kind: .hammerOn, semitones: 2, startTick: 960)),
            MusicalEvent(id: "bend", startTick: 7680, durationTicks: 3840, kind: .note, positions: [base],
                bend: PitchBend(semitones: 1, riseStartTick: 960, riseEndTick: 1920)),
            MusicalEvent(id: "vibrato", startTick: 11520, durationTicks: 3840, kind: .note, positions: [base],
                vibrato: PitchVibrato(extentCents: 50, startTick: 960, endTick: 2880, periodTicks: 480))]
        let endpoint = try CalibrationEndpoint(uid: "mixed-chain", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "mixed-chain", events: events), instrument: InstrumentProfile(), bpm: 60, route: route, calibration: calibration)
        let hz = 261.6255653005986, start = try config.expectedStart(renderEpochSeconds: 100)
        let frames = try (0...820).map { i -> SustainFrame in
            let time = Double(i) * 0.02 - 0.1, index = min(3, max(0, Int(floor(time / 4)))), age = time - Double(index) * 4
            let cents: Double
            switch index {
            case 0: cents = 0 // deliberately omit only the chain's intermediate D4
            case 1: cents = age < 1 ? 0 : 200
            case 2: cents = min(100, max(0, (age - 1) * 100))
            default: cents = (1..<3).contains(age) ? 25 * (1 - cos(4 * .pi * (age - 1))) : 0
            }
            return try SustainFrame(id: UInt64(i + 1), normalizedTime: start + time, state: .pitched, frequency: hz * pow(2, cents / 1200))
        }
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 30),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: (0..<4).map { try PracticeAttack(id: UInt64($0 + 1), normalizedOnset: start + Double($0) * 4, frequency: hz, clarity: 0.99, reliable: true) },
            clipping: [], pitchContour: PitchContourTrace(frames: frames), analysisVersion: "fixture")
        let result = try AssessmentEngine.evaluate(evidence)
        #expect(result.validity == .valid && result.parameters == .withLegatoChains)
        #expect(abs(try #require(result.legatoChainScore) - 200.0 / 3) < 1e-6)
        #expect(result.pitchTransitionScore == 100 && result.bendScore == 100 && result.vibratoScore == 100)
        #expect(result.overallScore == 96 && result.pitchScore == 100 && result.timingScore == 100)
        #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
    }
}
