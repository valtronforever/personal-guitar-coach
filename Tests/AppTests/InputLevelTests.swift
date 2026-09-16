import Testing
import Foundation
import Audio
@testable import PersonalGuitarCoach

struct InputLevelTests {
    private func snapshot(_ peak: Float, rms: Float = 0.02, frames: UInt64 = 480,
                          invalid: UInt64 = 0) -> CaptureSnapshot {
        CaptureSnapshot(totalFrames: frames, totalPackets: 1, droppedPackets: 0,
            peak: peak, rms: rms, sampleRate: 48_000, lastHostTime: 1,
            hostTimeValid: true, invalidSamples: invalid)
    }

    @Test func logScaleMakesQuietInputVisibleAndBoundsGeometry() {
        let reading = InputLevelReading(snapshot: snapshot(0.01, rms: 0.005), active: true)
        #expect(abs(reading.peakDB! + 40) < 0.0001)
        #expect(abs(reading.rmsDB! + 46.0206) < 0.0001)
        #expect(abs(reading.fraction - 1.0 / 3) < 0.0001)
        #expect(reading.state == .weak)
        #expect(InputLevelReading(snapshot: snapshot(0, rms: 0), active: true).fraction == 0)
        #expect(InputLevelReading(snapshot: snapshot(2), active: true).fraction == 1)
    }

    @Test func gainZonesAndClippingMatchTheirDisplayedBoundaries() {
        let cases: [(Float, InputLevelReading.State)] = [
            (0, .silent), (0.0009, .silent), (0.001, .weak),
            (0.03, .weak), (Float(pow(10, -30.0 / 20)), .good),
            (0.5, .good), (Float(pow(10, -6.0 / 20)), .high),
            (0.994, .high), (0.995, .clipping), (1.0, .clipping), (2, .clipping)
        ]
        for (amplitude, expected) in cases {
            #expect(InputLevelReading(snapshot: snapshot(amplitude), active: true).state == expected)
        }
    }

    @Test func stoppedMissingAndInvalidCaptureNeverLooksHealthy() {
        let stopped = InputLevelReading(snapshot: snapshot(0.2), active: false)
        #expect(stopped.state == .inactive && stopped.peakDB == nil && stopped.fraction == 0)
        let invalid: [CaptureSnapshot?] = [nil, snapshot(0.2, frames: 0), snapshot(.nan),
            snapshot(.infinity), snapshot(-0.1), snapshot(0.2, rms: .nan), snapshot(0.2, invalid: 1)]
        for value in invalid {
            let reading = InputLevelReading(snapshot: value, active: true)
            #expect(reading.state == .unavailable && reading.peakDB == nil && reading.fraction == 0)
        }
    }

    @Test func workingAmplitudeDoesNotImplyCalibrationReadiness() {
        let capture = snapshot(0.2)
        #expect(InputLevelReading(snapshot: capture, active: true).state == .good)
        #expect(!PracticePreflightSignal.isReady(capture)) // No reliable pitch/time-span evidence.
    }
}
