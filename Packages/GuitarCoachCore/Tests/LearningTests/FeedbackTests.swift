import Foundation
import Testing
import Domain
@testable import Learning

struct FeedbackTests {
    private func report(count: Int = 16, changes: [Int: Double] = [:], timing: [Int: Double] = [:], missing: Set<Int> = [],
                        uncertain: Set<Int> = [], rests: Bool = false, extras: [Double] = [], calibrated: Bool = true,
                        phase: PracticePhase = .completed, reason: PracticeStopReason? = nil, clipped: Bool = false,
                        bpm: Double = 60) throws -> AssessedPractice {
        var events: [MusicalEvent] = []
        for index in 0..<count {
            let isRest = rests && index % 2 == 1
            let positions: [FretPosition] = isRest ? [] : [try FretPosition(string: 6, fret: index % 4)]
            events.append(try MusicalEvent(id: "n\(index)", startTick: Int64(index) * 960, durationTicks: 960,
                kind: isRest ? .rest : .note, positions: positions))
        }
        let endpoint = try CalibrationEndpoint(uid: "feedback-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512,
            deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let profile = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "fixture", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: Exercise(id: "feedback-fixture", events: events), instrument: InstrumentProfile(),
            bpm: bpm, route: route, calibration: calibrated ? profile : nil,
            lesson: PracticeLessonReference(id: "lesson", version: 1))
        let start = try config.expectedStart(renderEpochSeconds: 100), step = 60 / bpm
        var attacks: [PracticeAttack] = []
        for (index, event) in events.enumerated() where event.kind == .note && !missing.contains(index) {
            let target = try config.instrument.tuning.frequency(at: event.positions[0])
            attacks.append(try PracticeAttack(id: UInt64(index + 1), normalizedOnset: start + Double(index) * step + (timing[index] ?? 0),
                frequency: uncertain.contains(index) ? nil : target * pow(2, (changes[index] ?? 0) / 1200),
                clarity: uncertain.contains(index) ? nil : 0.99, reliable: !uncertain.contains(index)))
        }
        for (index, time) in extras.enumerated() {
            attacks.append(try PracticeAttack(id: UInt64(count + index + 1), normalizedOnset: start + time, frequency: 110, clarity: 0.99, reliable: true))
        }
        attacks.sort { $0.normalizedOnset < $1.normalizedOnset }
        let clipping = try clipped ? [PracticeClippingInterval(start: start, end: start + Double(count) * step)] : []
        return try AssessmentEngine.evaluate(PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 100),
            finishedAt: Date(timeIntervalSince1970: 150), phase: phase, reason: reason, signalConfirmed: true,
            renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: attacks, clipping: clipping, analysisVersion: "fixture-1"))
    }
    private func advice(_ result: AssessedPractice) -> [PracticeRecommendation] { FeedbackEngine.recommendations(for: result) }
    @Test func timingRequiresThreeErrorsInOneDirectionAndReliableCalibration() throws {
        #expect(try !advice(report(timing: [2: 0.15, 3: 0.15])).contains { $0.kind == .late })
        let result = try report(timing: [2: 0.15, 3: 0.15, 4: 0.15, 5: -0.15])
        let late = try #require(advice(result).first { $0.kind == .late })
        #expect(late.eventIDs == ["n2", "n3", "n4"] && late.attackIDs == [3, 4, 5])
        #expect(late.evidenceCount == 3 && late.denominator == 8 && late.firstBar == 1 && late.lastBar == 2 && late.bpm == 50)
        #expect(try !advice(report(timing: [2: 0.15, 3: 0.15, 4: 0.15, 5: -0.15, 6: -0.15])).contains { $0.kind == .late })
        let uncalibrated = try advice(report(timing: [2: 0.15, 3: 0.15, 4: 0.15], calibrated: false))
        #expect(uncalibrated.first?.kind == .calibration && !uncalibrated.contains { $0.kind == .late || $0.kind == .early })
        #expect(try advice(report(timing: [2: -0.15, 3: -0.15, 4: -0.15])).contains { $0.kind == .early })
    }
    @Test func pitchEvidenceNeedsRepeatedTargetAndTunerNeedsThreeDistinctTargets() throws {
        #expect(try !advice(report(changes: [0: 100, 1: 100])).contains { $0.kind == .pitch })
        let repeated = try #require(advice(report(changes: [0: 100, 4: 100])).first { $0.kind == .pitch })
        #expect(repeated.eventIDs == ["n0", "n4"] && repeated.evidenceCount == 2)
        #expect(try !advice(report(changes: [0: 30, 4: 30, 8: 30])).contains { $0.kind == .tuning })
        #expect(try advice(report(changes: [0: 30, 1: 30, 2: 30])).contains { $0.kind == .tuning && $0.action == .tuner })
        #expect(try !advice(report(changes: [0: 30, 1: 30, 2: -30])).contains { $0.kind == .tuning })
    }
    @Test func MissingAndRestAdviceReferencesExactEvidenceAndRespectsMinimumTempo() throws {
        let missing = try #require(advice(report(missing: [2, 3], bpm: 40)).first { $0.kind == .missed })
        #expect(missing.eventIDs == ["n2", "n3"] && missing.attackIDs.isEmpty && missing.bpm == 40)
        #expect(try !advice(report(missing: [2], uncertain: [3])).contains { $0.kind == .missed })
        let rest = try #require(advice(report(rests: true, extras: [1.1, 3.1])).first { $0.kind == .rests })
        #expect(rest.eventIDs == ["n1", "n3"] && rest.attackIDs == [17, 18] && rest.evidenceCount == 2 && rest.denominator == 2)
    }
    @Test func BadInputAndPartialEvidenceNeverYieldPerformanceAdvice() throws {
        let clipped = try report(changes: [0: 100, 4: 100], clipped: true)
        #expect(advice(clipped).map(\.kind) == [.inputLevel] && advice(clipped)[0].evidenceCount == 1)
        let uncertain = try report(uncertain: [0, 1, 2, 3])
        #expect(advice(uncertain).map(\.kind) == [.signal])
        #expect(try advice(report(phase: .interrupted, reason: .dataLoss)).map(\.kind) == [.interrupted])
        #expect(try advice(report(phase: .paused, reason: .paused)).map(\.kind) == [.restart])
    }
    @Test func AdviceIsDeterministicBoundedAndUsesActualWholeBarFragments() throws {
        let result = try report(count: 32, changes: [20: 100, 24: 100], missing: [16, 17], calibrated: false)
        let items = advice(result)
        #expect(items.count == 3 && items.first?.kind == .calibration && items == advice(result))
        for item in items where item.action == .repeatFragment {
            #expect(item.sourceAttemptID == result.id && item.lastBar - item.firstBar < 4)
            let bars = item.firstBar...item.lastBar
            #expect(item.eventIDs.allSatisfy { id in
                result.evidence.configuration.selectedEvents.contains { $0.id == id && bars.contains(Int($0.startTick / 3840) + 1) }
            })
            #expect(item.evidenceCount == item.eventIDs.count)
        }
        let neutral = try advice(report(count: 32))
        #expect(neutral.map(\.kind) == [.repeatFragment] && neutral[0].bpm == 60 && neutral[0].firstBar == 1 && neutral[0].lastBar == 8)
    }
    private func edited(_ result: AssessedPractice, _ edit: (inout [String: Any]) -> Void) throws -> AssessedPractice {
        var value = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
        edit(&value)
        return try JSONDecoder().decode(AssessedPractice.self, from: JSONSerialization.data(withJSONObject: value))
    }
    @Test func ComparisonUsesFrozenConditionsAndNeverRanksPartialResults() throws {
        let original = try report()
        func evidenceField(_ name: String, _ value: Any) throws -> AssessedPractice {
            try edited(original) { root in
                var evidence = root["evidence"] as! [String: Any]; evidence[name] = value; root["evidence"] = evidence
            }
        }
        let earlier = try edited(original) { root in
            var evidence = root["evidence"] as! [String: Any]
            evidence["id"] = UUID().uuidString; evidence["startedAt"] = (evidence["startedAt"] as! Double) - 1
            root["evidence"] = evidence
        }
        #expect(PracticeComparison.compatible(original, earlier))
        #expect(PracticeComparison.previous(to: original, in: [original, earlier])?.id == earlier.id)
        #expect(PracticeComparison.best(for: original, in: [original, earlier])?.id == earlier.id)
        #expect(try !PracticeComparison.compatible(original, evidenceField("analysisVersion", "fixture-2")))
        for path in ["exercise", "tuning", "bpm", "source", "capabilityVersion", "countInBars", "calibration", "route", "range"] {
            let changed = try edited(original) { root in
                var evidence = root["evidence"] as! [String: Any], config = evidence["configuration"] as! [String: Any]
                var instrument = config["instrument"] as! [String: Any]
                switch path {
                case "exercise": var value = config["exercise"] as! [String: Any]; value["version"] = 2; config["exercise"] = value
                case "tuning": var value = instrument["tuning"] as! [String: Any]; value["revision"] = 2; instrument["tuning"] = value
                case "source": instrument["source"] = "acousticMicrophone"
                case "capabilityVersion": config[path] = "historical-capability"
                case "countInBars": config[path] = 2; evidence["renderEpochSeconds"] = 96.0
                case "calibration":
                    var value = config["calibration"] as! [String: Any]; value["id"] = UUID().uuidString; config["calibration"] = value
                case "route":
                    var route = config["route"] as! [String: Any], input = route["input"] as! [String: Any]
                    input["bufferFrames"] = 256; route["input"] = input; config["route"] = route
                    var calibration = config["calibration"] as! [String: Any]; calibration["route"] = route; config["calibration"] = calibration
                case "range":
                    // Add a final written rest and include it in the selected range; target notes/attacks stay unchanged.
                    var exercise = config["exercise"] as! [String: Any], events = exercise["events"] as! [[String: Any]]
                    events.append(["id": "final-rest", "startTick": 15360, "durationTicks": 3840, "kind": "rest", "positions": []])
                    exercise["events"] = events; config["exercise"] = exercise
                    config["range"] = [0, 19200]
                default: config[path] = 60.01 // Small change keeps the archived observation window structurally valid.
                }
                config["instrument"] = instrument; evidence["configuration"] = config; root["evidence"] = evidence
            }
            #expect(!PracticeComparison.compatible(original, changed))
        }
        let mirrored = try edited(original) { root in
            var e = root["evidence"] as! [String: Any], c = e["configuration"] as! [String: Any], i = c["instrument"] as! [String: Any]
            i["orientation"] = "leftHanded"; c["instrument"] = i; e["configuration"] = c; root["evidence"] = e
        }
        #expect(PracticeComparison.compatible(original, mirrored))
        let partial = try report(phase: .paused, reason: .paused)
        #expect(!PracticeComparison.compatible(partial, partial) && PracticeComparison.best(for: partial, in: [original, partial]) == nil)
        let pitchOnly = try report(calibrated: false)
        #expect(!PracticeComparison.compatible(original, pitchOnly) && PracticeComparison.score(pitchOnly) == pitchOnly.pitchScore)
    }
}
