import Foundation
import Testing
import Domain
@testable import Audio

struct PersonalSyncTests {
    private let expected = (4..<20).map { 100.0 + Double($0) }
    @Test func signedOffsetsAndHardwareNormalizationAreAppliedOnce() throws {
        let input = try CalibrationEndpoint(uid: "guitar", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 4800, streamLatencyFrames: 0)
        let output = try CalibrationEndpoint(uid: "headphones", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 12000, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: input, output: output, backendVersion: "fixture")
        let beats = try (4..<20).map { try route.expectedTime(renderEpochSeconds: 100, sampleFrame: Int64($0 * 48000)) }
        for offset in [-0.3, -0.05, 0.05, 0.3] {
            let onsets = try beats.map { try route.observedTime(inputHostSeconds: $0 + offset + 0.1) }
            let pass = try PersonalSyncPass(expected: beats, observed: onsets)
            #expect(abs(pass.offset - offset) < 1e-9 && pass.spread < 1e-9)
        }
    }
    @Test func omissionsExtrasWholeBeatAliasesAndUnstablePlayingFail() throws {
        for observations in [Array(expected.dropFirst()), Array(expected.dropLast()), 
                             expected.map { $0 + 1 }, expected.enumerated().map { $0.element + ($0.offset.isMultiple(of: 2) ? 0.1 : -0.1) },
                             expected.enumerated().map { $0.element + Double($0.offset) * 0.01 }] {
            #expect(throws: CalibrationError.insufficientEvidence) { try PersonalSyncPass(expected: expected, observed: observations) }
        }
        let extra = (expected + [expected[5] + 0.1]).sorted()
        #expect(throws: CalibrationError.insufficientEvidence) { try PersonalSyncPass(expected: expected, observed: extra) }
        #expect(throws: CalibrationError.insufficientEvidence) { try PersonalSyncPass(expected: expected, observed: [Double.nan]) }
    }
    @Test func twoPassAgreementAndPersistedEvidenceAreValidated() throws {
        let a = try PersonalSyncPass(expected: expected, observed: expected.map { $0 + 0.1 })
        let b = try PersonalSyncPass(expected: expected, observed: expected.map { $0 + 0.12 })
        let evidence = try PersonalSyncEvidence(instrument: InstrumentProfile(tuning: .cStandard), string: 3,
            offsets: [a.offset, b.offset], spreads: [a.spread, b.spread], drifts: [a.drift, b.drift])
        #expect(abs(evidence.offset - 0.11) < 1e-9)
        #expect(try JSONDecoder().decode(PersonalSyncEvidence.self, from: JSONEncoder().encode(evidence)) == evidence)
        #expect(throws: CalibrationError.insufficientEvidence) {
            try PersonalSyncEvidence(instrument: InstrumentProfile(), string: 3, offsets: [0.1, 0.2], spreads: [0, 0], drifts: [0, 0])
        }
        var document = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(evidence)) as? [String: Any])
        document["offsets"] = []
        #expect(throws: (any Error).self) { try JSONDecoder().decode(PersonalSyncEvidence.self, from: JSONSerialization.data(withJSONObject: document)) }
    }
    @Test func probeUsesCurrentStringAndDisplayUsesOnlyOutputDelay() throws {
        let instrument = InstrumentProfile(tuning: .cStandard)
        let request = try PersonalSyncProbe.request(instrument: instrument, string: 3)
        #expect(request.tuning == .cStandard && request.exercise.events.count == 20 && request.mode == .calibration)
        #expect(request.exercise.events.allSatisfy { $0.positions == [try! FretPosition(string: 3, fret: 0)] })
        let plan = try TransportPlan(request: request, sampleRate: 48000)
        #expect(plan.audiblePosition(renderedFrames: 60000, outputLatencySeconds: 0.25).tick == 960)
        #expect(plan.audiblePosition(renderedFrames: 0, outputLatencySeconds: 0.25).tick == 0)
    }
}
