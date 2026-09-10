import Foundation
import Testing
@testable import Domain

struct CalibrationTests {
    private func route(outputUID: String = "usb", rate: Double = 48000, buffer: UInt32 = 512) throws -> CalibrationRoute {
        try CalibrationRoute(input: CalibrationEndpoint(uid: "usb", channel: 2, sampleRate: 48000, bufferFrames: buffer,
            deviceLatencyFrames: 240, streamLatencyFrames: 240, safetyOffsetFrames: 128),
            output: CalibrationEndpoint(uid: outputUID, channel: 1, sampleRate: rate, bufferFrames: 512,
                deviceLatencyFrames: 480, streamLatencyFrames: 480, safetyOffsetFrames: 256), backendVersion: "test-backend-1")
    }
    private func evidence() throws -> CalibrationEvidence {
        try CalibrationEvidence(algorithmVersion: "pulse-test-1", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
            durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0)
    }
    @Test func positiveAndNegativeResidualsCompensateExactlyOnce() throws {
        let route = try route()
        let expected = try route.expectedTime(renderEpochSeconds: 100, sampleFrame: 48000)
        #expect(abs(expected - 101.02) < 1e-9)
        for offset in [-0.05, 0.05] {
            let profile = try CalibrationProfile(route: route, method: .manual, residualOffsetSeconds: offset, uncertaintySeconds: 0.2)
            let observed = try route.observedTime(inputHostSeconds: expected + 0.01 + offset)
            #expect(abs(try profile.timingError(observedNormalizedTime: observed, expectedNormalizedTime: expected)) < 1e-9)
            #expect(abs(try profile.timingError(observedNormalizedTime: observed + 0.03, expectedNormalizedTime: expected) - 0.03) < 1e-9)
        }
        // Changing the buffer invalidates identity but never subtracts another buffer from a data timestamp.
        let changedBuffer = try self.route(buffer: 1024)
        #expect(try changedBuffer.observedTime(inputHostSeconds: 100) == route.observedTime(inputHostSeconds: 100))
        #expect(changedBuffer.signature != route.signature)
    }
    @Test func matchingRouteMeasuredUncertaintyAndFreshClocksAreAllRequired() throws {
        let route = try route()
        let profile = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0.02, uncertaintySeconds: 0.015, evidence: evidence())
        #expect(profile.rhythmCapability(route: route, toleranceSeconds: 0.1, durationSeconds: 60, clockDriftSeconds: 0) == .available)
        #expect(profile.rhythmCapability(route: route, toleranceSeconds: 0.1, durationSeconds: 60, clockDriftSeconds: 0.006) == .uncertain)
        #expect(profile.rhythmCapability(route: route, toleranceSeconds: 0.1, durationSeconds: 60, clockDriftSeconds: nil) == .missingClock)
        #expect(try profile.rhythmCapability(route: self.route(rate: 44100), toleranceSeconds: 0.1, durationSeconds: 60, clockDriftSeconds: 0) == .routeMismatch)
        for method in [CalibrationMethod.manual, .estimated] {
            let unmeasured = try CalibrationProfile(route: route, method: method, residualOffsetSeconds: 0, uncertaintySeconds: 0)
            #expect(unmeasured.rhythmCapability(route: route, toleranceSeconds: 0.1, durationSeconds: 10, clockDriftSeconds: 0) == .unmeasured)
        }
    }
    @Test func separateDevicesNeedEvidenceForTheAttemptDuration() throws {
        let route = try route(outputUID: "second-device")
        let profile = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.015, evidence: evidence())
        #expect(profile.rhythmCapability(route: route, toleranceSeconds: 0.1, durationSeconds: 20, clockDriftSeconds: 0) == .available)
        #expect(profile.rhythmCapability(route: route, toleranceSeconds: 0.1, durationSeconds: 900, clockDriftSeconds: 0) == .durationUnverified)
    }
    @Test func unknownHardwareLatencyRemainsUnknownAndCorruptDecodingRejects() throws {
        let endpoint = try CalibrationEndpoint(uid: "unknown", channel: 1, sampleRate: 48000, bufferFrames: 512)
        #expect(endpoint.hardwareLatencySeconds == nil)
        let encoded = try JSONEncoder().encode(endpoint)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["sampleRate"] = -1
        let corrupt = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: CalibrationError.invalidRoute) { try JSONDecoder().decode(CalibrationEndpoint.self, from: corrupt) }
        let profile = try CalibrationProfile(route: route(), method: .manual, residualOffsetSeconds: 0, uncertaintySeconds: 0.2)
        #expect(throws: CalibrationError.invalidTimestamp) { try profile.timingError(observedNormalizedTime: 1e308, expectedNormalizedTime: -1e308) }
        #expect(throws: CalibrationError.invalidProfile) { try CalibrationProfile(route: route(), method: .measured,
            residualOffsetSeconds: 0, uncertaintySeconds: 0.001, evidence: evidence()) }
    }
    @Test func profileRoundTripPreservesSignatureAndEvidence() throws {
        let profile = try CalibrationProfile(route: route(), method: .measured, residualOffsetSeconds: -0.05, uncertaintySeconds: 0.015, evidence: evidence())
        let restored = try JSONDecoder().decode(CalibrationProfile.self, from: JSONEncoder().encode(profile))
        #expect(restored == profile && restored.route.signature == profile.route.signature)
    }
}
