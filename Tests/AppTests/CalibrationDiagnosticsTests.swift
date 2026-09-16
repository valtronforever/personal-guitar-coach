import Foundation
import Testing
import Domain
import Audio
@testable import PersonalGuitarCoach

struct CalibrationDiagnosticsTests {
    @Test func normalGainIsNotReportedAsWeakAndSignalFailuresStayDistinct() {
        var report = CalibrationDiagnostics(passNumber: 1, targetFrequency: 65.4064)
        #expect(report.signalFailure.reason == .noSignal)
        report.maximumPeak = 0.01
        #expect(report.signalFailure.reason == .weakSignal)
        report.maximumPeak = 0.2
        #expect(report.signalFailure.reason == .unstableSignal)
        report.lastFrequency = 130.8128
        #expect(report.signalFailure.reason == .wrongPitch)
        #expect(abs(report.peakDB! + 13.9794) < 0.001)
    }
    @Test func selectedCStandardPitchCountsAllMeasuredAttacksIncludingUncertainAndWrong() throws {
        let endpoint = try CalibrationEndpoint(uid: "fixture", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let frequency = try TuningProfile.cStandard.frequency(at: FretPosition(string: 6, fret: 0))
        let expected = (4..<20).map { 100.0 + Double($0) }
        let events = (0..<21).map { index in
            let time = AnalysisTimestamp(frame: Int64(index * 48000), sampleRate: 48000, hostSeconds: 100 + Double(index))
            return DetectedNoteEvent(id: UInt64(index + 1), onset: time, resolvedAt: time,
                quality: index == 6 ? .unstable : .reliable,
                pitch: index == 6 ? nil : DetectedPitch(frequency: index == 5 ? frequency * 2 : frequency, clarity: 0.98))
        }
        var report = CalibrationDiagnostics(passNumber: 1, targetFrequency: frequency)
        let observed = try report.analyze(events: events, expected: expected, route: route)
        #expect(observed.count == 21) // Listening/tail preserved for the common timing validator.
        #expect(report.measuredAttacks == 16 && report.matchingAttacks == 14)
        #expect(report.wrongAttacks == 1 && report.uncertainAttacks == 1)
        #expect(report.noteFailure?.reason == .wrongNotes)
        _ = try report.analyze(events: [], expected: expected, route: route)
        #expect(report.measuredAttacks == 0 && report.matchingAttacks == 0 && report.noteFailure == nil)
    }
}
