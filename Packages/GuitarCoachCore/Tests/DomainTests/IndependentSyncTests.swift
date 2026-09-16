import Foundation
import Testing
@testable import Domain

struct IndependentSyncTests {
    private func endpoint(_ uid: String = "headphones") throws -> CalibrationEndpoint {
        try CalibrationEndpoint(uid: uid, channel: 1, sampleRate: 48000, bufferFrames: 512)
    }
    @Test func signedSettingsSumOnceAndRoundTripWithTheirEvidence() throws {
        let endpoint = try endpoint(), route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test")
        for outputSeconds in [-0.15, 0, 0.2] {
            let output = try OutputAlignmentProfile(output: endpoint, evidence: SyncPassEvidence(offset: outputSeconds, spread: 0.01, drift: 0.002), clockDriftSeconds: 0.003)
            let evidence = try InstrumentSyncEvidence(instrument: InstrumentProfile(tuning: .cStandard), string: 6, outputSetting: output, guitar: SyncPassEvidence(offset: 0.04, spread: 0.005, drift: -0.001))
            #expect(abs(evidence.uncertainty - 0.031) < 1e-9)
            let profile = try CalibrationProfile(route: route, method: .personal, residualOffsetSeconds: evidence.offset, uncertaintySeconds: evidence.uncertainty, instrumentEvidence: evidence)
            #expect(abs(try profile.timingError(observedNormalizedTime: 100 + outputSeconds + 0.04, expectedNormalizedTime: 100)) < 1e-9)
            #expect(try JSONDecoder().decode(CalibrationProfile.self, from: JSONEncoder().encode(profile)) == profile)
            #expect(profile.personalInstrument == InstrumentProfile(tuning: .cStandard))
            #expect(throws: CalibrationError.invalidProfile) { try CalibrationProfile(route: route, method: .personal, residualOffsetSeconds: evidence.offset + outputSeconds + 0.1, uncertaintySeconds: evidence.uncertainty, instrumentEvidence: evidence) }
        }
    }
    @Test func invalidOrAmbiguousEvidenceCannotEnableTiming() throws {
        let endpoint = try endpoint(), route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test")
        let pass = try SyncPassEvidence(offset: 0.1, spread: 0, drift: 0)
        let output = try OutputAlignmentProfile(output: self.endpoint("different"), evidence: pass)
        let guitar = try InstrumentSyncEvidence(instrument: InstrumentProfile(), string: 3, outputSetting: output, guitar: pass)
        #expect(throws: CalibrationError.invalidProfile) { try CalibrationProfile(route: route, method: .personal, residualOffsetSeconds: guitar.offset, uncertaintySeconds: guitar.uncertainty, instrumentEvidence: guitar) }
        let legacy = try PersonalSyncEvidence(instrument: InstrumentProfile(), string: 3, offsets: [0.1, 0.1], spreads: [0, 0], drifts: [0, 0])
        #expect(throws: CalibrationError.invalidProfile) { try CalibrationProfile(route: route, method: .personal, residualOffsetSeconds: guitar.offset, uncertaintySeconds: guitar.uncertainty, personalEvidence: legacy, instrumentEvidence: guitar) }
        for value in [Double.nan, .infinity, -0.001, 0.021] {
            #expect(throws: CalibrationError.insufficientEvidence) { try OutputAlignmentProfile(output: endpoint, evidence: pass, clockDriftSeconds: value) }
        }
        for version in ["future", "personal-two-pass-16-v1"] {
            let changed = String(decoding: try JSONEncoder().encode(output), as: UTF8.self).replacingOccurrences(of: OutputAlignmentProfile.version, with: version)
            #expect(throws: CalibrationError.invalidProfile) { try JSONDecoder().decode(OutputAlignmentProfile.self, from: Data(changed.utf8)) }
        }
    }
    @Test func practiceCanFreezeOutputOnlyButCannotMixDifferentOutputEvidence() throws {
        let endpoint = try endpoint(), route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test")
        let exercise = try Exercise(id: "independent", events: [MusicalEvent(id: "n", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 0)])])
        let output = try OutputAlignmentProfile(output: endpoint, evidence: SyncPassEvidence(offset: 0.2, spread: 0, drift: 0))
        let configuration = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60, route: route, outputAlignment: output)
        #expect(configuration.calibration == nil && configuration.outputAlignment == output)
        #expect(configuration.visualOutputLatency(fallback: 0.12) == 0)
        #expect(try JSONDecoder().decode(PracticeConfiguration.self, from: JSONEncoder().encode(configuration)) == configuration)
        let guitar = try InstrumentSyncEvidence(instrument: InstrumentProfile(), string: 3, outputSetting: output, guitar: SyncPassEvidence(offset: 0.03, spread: 0, drift: 0))
        let profile = try CalibrationProfile(route: route, method: .personal, residualOffsetSeconds: guitar.offset, uncertaintySeconds: guitar.uncertainty, instrumentEvidence: guitar)
        #expect(throws: CalibrationError.invalidProfile) { try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60, route: route, calibration: profile) }
        let changed = try OutputAlignmentProfile(id: output.id, output: endpoint, evidence: SyncPassEvidence(offset: 0.1, spread: 0, drift: 0))
        #expect(throws: CalibrationError.invalidProfile) { try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60, route: route, calibration: profile, outputAlignment: changed) }
        let legacy = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60, route: route)
        #expect(try JSONDecoder().decode(PracticeConfiguration.self, from: JSONEncoder().encode(legacy)).outputAlignment == nil)
        #expect(legacy.visualOutputLatency(fallback: 0.12) == 0.12)
    }
    @Test func manualSpecificationRemovesAlreadyReportedDelayAndKeepsItsProvenance() throws {
        let output = try CalibrationEndpoint(uid: "bt", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 2400, streamLatencyFrames: 2400)
        let total = try OutputAlignmentProfile(output: output, manual: ManualOutputAlignment(seconds: 0.25, reference: .total))
        #expect(abs(total.seconds - 0.15) < 1e-9 && total.evidence == nil && total.isManual)
        let correction = try OutputAlignmentProfile(output: output, manual: ManualOutputAlignment(seconds: -0.05, reference: .additional))
        #expect(correction.seconds == -0.05)
        for value in [total, correction] {
            #expect(try JSONDecoder().decode(OutputAlignmentProfile.self, from: JSONEncoder().encode(value)) == value)
        }
        #expect(throws: CalibrationError.invalidProfile) { try ManualOutputAlignment(seconds: -0.1, reference: .total) }
        #expect(throws: CalibrationError.invalidProfile) { try ManualOutputAlignment(seconds: .nan, reference: .additional) }
        let manual = try ManualInstrumentSyncEvidence(instrument: InstrumentProfile(), outputSetting: total, remainingOffset: -0.02)
        #expect(abs(manual.offset - 0.13) < 1e-9)
        #expect(throws: CalibrationError.invalidProfile) { try ManualInstrumentSyncEvidence(instrument: InstrumentProfile(), outputSetting: total, remainingOffset: 1) }
        let route = try CalibrationRoute(input: output, output: output, backendVersion: "manual-test")
        let profile = try CalibrationProfile(route: route, method: .manualPersonal, residualOffsetSeconds: manual.offset, uncertaintySeconds: ManualInstrumentSyncEvidence.scoringAllowance, manualInstrumentEvidence: manual)
        #expect(try JSONDecoder().decode(CalibrationProfile.self, from: JSONEncoder().encode(profile)) == profile)
        #expect(profile.personalInstrument == InstrumentProfile() && profile.outputSetting == total)
        #expect(profile.rhythmCapability(route: route, toleranceSeconds: 0.2, durationSeconds: 20, clockDriftSeconds: 0) == .approximate)
        #expect(throws: CalibrationError.invalidProfile) { try CalibrationProfile(route: route, method: .manualPersonal, residualOffsetSeconds: 0, uncertaintySeconds: 0) }
    }

}
