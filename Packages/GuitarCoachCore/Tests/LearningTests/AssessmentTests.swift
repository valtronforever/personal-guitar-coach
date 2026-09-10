import Foundation
import Testing
import Domain
@testable import Learning

struct AssessmentTests {
    private func input(count: Int = 8, bpm: Double = 60, ticks: Int64 = 960, rests: Bool = false,
                       shifts: [Int: Double] = [:], semitones: [Int: Double] = [:], missing: Set<Int> = [],
                       unreliable: Set<Int> = [], extras: [Double] = [], offset: Double = 0,
                       calibrated: Bool = true, drift: Double? = 0, phase: PracticePhase = .completed,
                       confirmed: Bool = true, clipped: Bool = false, noisy: Bool = false) throws -> PracticeEvidence {
        var events: [MusicalEvent] = []
        for index in 0..<count {
            let isRest = rests && index % 2 == 1
            let kind: MusicalEventKind = isRest ? .rest : .note
            let positions: [FretPosition] = isRest ? [] : [try FretPosition(string: 6, fret: index % 5)]
            let event = try MusicalEvent(id: "n\(index)", startTick: Int64(index) * ticks,
                durationTicks: ticks, kind: kind, positions: positions)
            events.append(event)
        }
        let endpoint = try CalibrationEndpoint(uid: "usb", channel: 1, sampleRate: 48000, bufferFrames: 512,
            deviceLatencyFrames: 240, streamLatencyFrames: 240)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let calibration = try calibrated ? CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: offset,
            uncertaintySeconds: 0.015, evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12,
                missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0)) : nil
        let configuration = try PracticeConfiguration(exercise: Exercise(id: "golden", events: events),
            instrument: InstrumentProfile(), bpm: bpm, route: route, calibration: calibration)
        let start = try configuration.expectedStart(renderEpochSeconds: 100)
        let step = Double(ticks) / 960 * 60 / bpm
        var attacks: [PracticeAttack] = []
        for i in 0..<count where !missing.contains(i) && events[i].kind == .note {
            let frequency = try configuration.instrument.tuning.pitch(at: events[i].positions[0]).frequency(referenceA4: 440)
            attacks.append(try PracticeAttack(id: UInt64(i + 1), normalizedOnset: start + Double(i) * step + (shifts[i] ?? 0) + offset,
                frequency: unreliable.contains(i) ? nil : frequency * pow(2, (semitones[i] ?? 0) / 12),
                clarity: unreliable.contains(i) ? nil : 0.98, reliable: !unreliable.contains(i)))
        }
        for (index, time) in extras.enumerated() {
            attacks.append(try PracticeAttack(id: UInt64(count + index + 1), normalizedOnset: start + time + offset,
                frequency: 110, clarity: 0.98, reliable: true))
        }
        attacks.sort { $0.normalizedOnset < $1.normalizedOnset }
        let interval = try PracticeClippingInterval(start: start + offset, end: start + Double(count) * step + offset)
        return try PracticeEvidence(id: UUID(), configuration: configuration, startedAt: Date(timeIntervalSince1970: 1),
            finishedAt: Date(timeIntervalSince1970: 20), phase: phase, reason: phase == .completed ? nil : .dataLoss,
            signalConfirmed: confirmed, renderEpochSeconds: confirmed ? 100 : nil, maximumClockDriftSeconds: drift,
            attacks: attacks, clipping: clipped ? [interval] : [],
            uncertainSignal: noisy ? [PracticeUncertainSpan(interval: interval, reason: .ambiguous)] : [], analysisVersion: "fixture-analysis-1")
    }
    @Test func perfectAndCompensatedSignedLatencyReach100WithoutDoubleCompensation() throws {
        for offset in [-0.05, 0, 0.05] {
            let input = try input(offset: offset), result = try AssessmentEngine.evaluate(input)
            #expect(result.overallScore == 100 && result.validity == .valid)
            #expect(result.matchedCount == 8 && result.missedCount == 0 && result.extras.isEmpty)
            #expect(abs(result.meanSignedTimingSeconds ?? 1) < 1e-9)
            #expect(try AssessmentEngine.evaluate(input) == result)
        }
    }
    @Test func halfStepAndOctaveErrorsCannotChangeTheTimeAssignment() throws {
        for semitone in [1.0, 12.0, -12.0] {
            let result = try AssessmentEngine.evaluate(input(semitones: Dictionary(uniqueKeysWithValues: (0..<8).map { ($0, semitone) })))
            #expect(result.pitchScore == 0 && result.overallScore == 40)
            #expect(result.notes.compactMap(\.attackID) == (1...8).map(UInt64.init))
        }
    }
    @Test func lateEarlyAndDroppedMiddleKeepMonotonicOneToOneAssignments() throws {
        let result = try AssessmentEngine.evaluate(input(shifts: [0: -0.05, 1: 0.05], missing: [3]))
        #expect(result.notes[3].attackID == nil && result.missedCount == 1 && result.matchedCount == 7)
        #expect(result.notes[4].attackID == 5)
        #expect(abs((result.notes[0].timingErrorSeconds ?? 0) + 0.05) < 1e-9)
        #expect(abs((result.notes[1].timingErrorSeconds ?? 0) - 0.05) < 1e-9)
        #expect(result.overallScore == 83)
        let shifted = try AssessmentEngine.evaluate(input(shifts: Dictionary(uniqueKeysWithValues: (0..<8).map { ($0, 0.4) })))
        #expect(shifted.matchedCount == 0 && shifted.overallScore == 0 && shifted.extras.count == 8)
    }
    @Test func extrasAndRestViolationsReduceTheScore() throws {
        let result = try AssessmentEngine.evaluate(input(rests: true, extras: [1.1, 3.1]))
        #expect(result.expectedCount == 4 && result.matchedCount == 4)
        #expect(result.extras.map(\.restID) == ["n1", "n3"] && result.overallScore == 93)
        let duplicate = try AssessmentEngine.evaluate(input(extras: [0.02]))
        #expect(duplicate.matchedCount == 8 && duplicate.extras.count == 1)
        #expect(Set(duplicate.notes.compactMap(\.attackID)).count == 8 && duplicate.overallScore == 98)
    }
    @Test func uncertaintyRemainsInDenominatorAndTooMuchSignalAmbiguityIsUnscored() throws {
        let small = try AssessmentEngine.evaluate(input(unreliable: [2]))
        #expect(small.uncertainCount == 1 && small.expectedCount == 8 && small.overallScore == 88)
        let large = try AssessmentEngine.evaluate(input(unreliable: [2, 3]))
        #expect(large.validity == .insufficientSignal && large.overallScore == nil && large.pitchScore == nil)
        let clipped = try AssessmentEngine.evaluate(input(clipped: true))
        #expect(clipped.validity == .insufficientSignal && clipped.uncertainCount == 8)
        let noisyWithoutAttacks = try AssessmentEngine.evaluate(input(missing: Set(0..<8), noisy: true))
        #expect(noisyWithoutAttacks.validity == .insufficientSignal && noisyWithoutAttacks.uncertainCount == 8)
        // Reliable resolved attacks supersede ordinary transient uncertainty, but never clipping.
        #expect(try AssessmentEngine.evaluate(input(noisy: true)).overallScore == 100)
    }
    @Test func healthySilenceMissingInputAndPartialAreDifferentOutcomes() throws {
        let silence = try AssessmentEngine.evaluate(input(missing: Set(0..<8)))
        #expect(silence.validity == .valid && silence.overallScore == 0 && silence.missedCount == 8)
        let failed = try AssessmentEngine.evaluate(input(missing: Set(0..<8), phase: .preflightFailed, confirmed: false))
        #expect(failed.validity == .insufficientSignal && failed.overallScore == nil)
        for phase in [PracticePhase.paused, .cancelled, .interrupted] {
            let result = try AssessmentEngine.evaluate(input(phase: phase))
            #expect(result.validity == .interrupted && result.overallScore == nil && result.pitchScore == nil)
        }
    }
    @Test func uncalibratedAndUncertainClocksAllowOnlyPitch() throws {
        for input in [try input(calibrated: false), try input(drift: nil), try input(drift: 0.02)] {
            let result = try AssessmentEngine.evaluate(input)
            #expect(result.validity == .uncalibrated && result.pitchScore == 100 && result.overallScore == nil && result.timingScore == nil)
            #expect(result.notes.allSatisfy { $0.timingErrorSeconds == nil })
        }
        let short = try AssessmentEngine.evaluate(input(bpm: 150, ticks: 480, drift: 0.001))
        #expect(abs(short.rhythmToleranceSeconds - 0.09) < 1e-9)
        #expect(short.validity == .uncalibrated) // 15 ms + 30 ms + 1 ms drift exceeds half the 90 ms tolerance.
    }
    @Test func observationsOutsideGuardsAreExcludedAndDecodingValidatesInputs() throws {
        let evidence = try input(extras: [-0.2, 9]), result = try AssessmentEngine.evaluate(evidence)
        #expect(result.overallScore == 100 && result.extras.isEmpty)
        #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        #expect(throws: PracticeError.invalidEvidence) { try PracticeAttack(id: 1, normalizedOnset: .nan, frequency: 100, clarity: 0.9, reliable: true) }
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        json["overallScore"] = 101
        #expect(throws: AssessmentError.invalidResult) { try JSONDecoder().decode(AssessedPractice.self, from: JSONSerialization.data(withJSONObject: json)) }
    }
    @Test func maximumBoundIsDeterministicAndRepeatedPitchDoesNotMergeAttacks() throws {
        let large = try input(count: 1024, bpm: 120, extras: (0..<1024).map { Double($0) * 0.5 + 0.25 })
        let result = try AssessmentEngine.evaluate(large)
        #expect(result.matchedCount == 1024 && result.extras.count == 1024)
        let repeatedResult = try AssessmentEngine.evaluate(large)
        #expect(result.overallScore == 90 && result == repeatedResult)
        let repeated = try input(semitones: Dictionary(uniqueKeysWithValues: (0..<8).map { ($0, -Double($0 % 5)) }))
        let evaluated = try AssessmentEngine.evaluate(repeated)
        #expect(evaluated.matchedCount == 8 && evaluated.notes.compactMap(\.attackID) == (1...8).map(UInt64.init))
    }

}
