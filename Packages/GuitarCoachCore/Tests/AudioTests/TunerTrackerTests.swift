import Testing
import Foundation
import Domain
@testable import Audio

@Suite struct TunerTrackerTests {
    private func feed(_ tracker: inout TunerTracker, hz: Double, from start: Double = 0, steps: Int = 8) {
        for i in 0..<steps { tracker.update(frequency: hz, clarity: 0.99, quality: .reliable, streamTime: start + Double(i) * 0.05) }
    }

    @Test func detuningBandUsesRawPitchAndRequiresThreeHundredMilliseconds() throws {
        for cents in [-50.0, -25, -10, -5, 0, 5, 10, 25, 50] {
            var tracker = try TunerTracker(mode: .manual(string: 6))
            let hz = try Pitch(midi: 40).frequency() * pow(2, cents / 1200)
            feed(&tracker, hz: hz, steps: 6)
            #expect(tracker.reading.feedback != .inTune)
            feed(&tracker, hz: hz, from: 0.3, steps: 2)
            #expect(tracker.reading.feedback == (abs(cents) <= 5 ? .inTune : cents < 0 ? .flat : .sharp))
            #expect(abs((tracker.reading.cents ?? 10000) - cents) < 1e-6)
            #expect(tracker.reading.detectedPitch?.midi == (try Pitch.nearest(to: hz).midi))
        }
    }

    @Test func silenceClippingLowConfidenceAndInterveningBadFramesRevokeConfirmation() throws {
        for quality in [SignalQuality.silence, .clipping, .unstable, .ambiguous, .quiet, .outOfRange] {
            var tracker = try TunerTracker(mode: .manual(string: 5))
            feed(&tracker, hz: 110)
            #expect(tracker.reading.feedback == .inTune)
            tracker.update(frequency: nil, clarity: nil, quality: quality, streamTime: 0.4)
            #expect(tracker.reading.feedback != .inTune && tracker.reading.frequency == nil)
        }
        var tracker = try TunerTracker(mode: .manual(string: 5))
        feed(&tracker, hz: 110)
        tracker.update(frequency: 110, clarity: 0.99, quality: .reliable, streamTime: 0.4, interrupted: true)
        #expect(tracker.reading.feedback == .centering)
        tracker.update(frequency: 110, clarity: 0.5, quality: .reliable, streamTime: 0.45)
        #expect(tracker.reading.feedback == .unstable)
    }

    @Test func duplicateSnapshotsGapsAndBoundaryJitterCannotInventStability() throws {
        var tracker = try TunerTracker(mode: .manual(string: 5))
        for _ in 0..<20 { tracker.update(frequency: 110, clarity: 1, quality: .reliable, streamTime: 0) }
        #expect(tracker.reading.feedback == .centering)
        tracker.update(frequency: 110, clarity: 1, quality: .reliable, streamTime: 1)
        #expect(tracker.reading.feedback == .centering)
        feed(&tracker, hz: 110, from: 1.05)
        #expect(tracker.reading.feedback == .inTune)
        tracker.update(frequency: 110 * pow(2, 5.1/1200), clarity: 1, quality: .reliable, streamTime: 1.45)
        #expect(tracker.reading.feedback == .sharp)
        #expect(abs(tracker.reading.indicatorCents ?? 100) < 1) // Smoothing never preserves green.
        for i in 0..<12 {
            let cents = i.isMultiple(of: 2) ? 4.9 : 5.1
            tracker.update(frequency: 110 * pow(2, cents/1200), clarity: 1, quality: .reliable, streamTime: 1.5 + Double(i) * 0.05)
            #expect(tracker.reading.feedback != .inTune)
        }
    }

    @Test func automaticHarmonicsRequireExplicitStringAndManualOctavesStayWrong() throws {
        var automatic = try TunerTracker()
        let highE = try Pitch(midi: 64).frequency()
        feed(&automatic, hz: highE)
        #expect(automatic.reading.feedback == .chooseString)
        #expect(automatic.reading.detectedPitch?.midi == 64)
        try automatic.configure(tuning: .standard, mode: .manual(string: 6))
        feed(&automatic, hz: highE)
        #expect(automatic.reading.feedback == .sharp && abs((automatic.reading.cents ?? 0) - 2400) < 1e-6)
        try automatic.configure(tuning: .standard, mode: .manual(string: 1))
        feed(&automatic, hz: highE)
        #expect(automatic.reading.feedback == .inTune)
        try automatic.configure(tuning: .standard, mode: .automatic)
        feed(&automatic, hz: 110)
        #expect(automatic.reading.targetString == 5 && automatic.reading.feedback == .inTune)
    }

    @Test func dropDAndReferenceChangeResetAndRecomputeEveryTarget() throws {
        var tracker = try TunerTracker(tuning: .dropD, mode: .manual(string: 6))
        #expect(tracker.reading.targetPitch?.midi == 38)
        let custom = try TuningProfile(id: "a450", name: "A450", strings: TuningProfile.standard.strings, referenceA4: 450)
        for string in 1...6 {
            try tracker.configure(tuning: custom, mode: .manual(string: string))
            #expect(tracker.reading.feedback == .waiting)
            #expect(tracker.reading.targetFrequency == (try custom.strings[string - 1].openPitch.frequency(referenceA4: 450)))
        }
        #expect(throws: MusicError.invalidString) { try tracker.configure(tuning: custom, mode: .manual(string: 0)) }
    }
}
