import Testing
import Foundation
@testable import Audio

struct PracticePreflightTests {
    @Test func realAnalyzerNeedsSustainedCleanEvidenceAndRejectsClippingSilenceAndLoss() throws {
        let analyzer = try MonophonicAnalyzer(sampleRate: 48000)
        var total: UInt64 = 0
        func feed(seconds: Double, amplitude: Double) {
            let count = Int(seconds * 48000), origin = total
            let samples = (0..<count).map { Float(amplitude * sin(2 * .pi * 110 * Double(origin + UInt64($0)) / 48000)) }
            samples.withUnsafeBufferPointer { analyzer.process($0, startHostSeconds: 100 + Double(origin) / 48000) }
            total += UInt64(count)
        }
        func capture(drops: UInt64 = 0) -> CaptureSnapshot {
            CaptureSnapshot(totalFrames: total, totalPackets: total / 512, droppedPackets: drops, peak: 0.2, rms: 0.1,
                sampleRate: 48000, lastHostTime: total, hostTimeValid: true, analysis: analyzer.snapshot(), lastPacketFrames: 512)
        }
        feed(seconds: 0.12, amplitude: 0.2)
        #expect(!PracticePreflightSignal.isReady(capture()))
        feed(seconds: 0.8, amplitude: 0.2)
        #expect(PracticePreflightSignal.isReady(capture()))
        #expect(!PracticePreflightSignal.isReady(capture(drops: 1)))
        feed(seconds: 0.3, amplitude: 1.5)
        #expect(!PracticePreflightSignal.isReady(capture()))
        feed(seconds: 0.5, amplitude: 0)
        #expect(!PracticePreflightSignal.isReady(capture()))
    }
}
