import Testing
import Foundation
import AVFAudio
@testable import Audio

struct ClockDriftTests {
    private func input(frame: UInt64, packet: UInt32 = 512, drift: Double = 0, analysisOrigin: Double? = nil) -> CaptureSnapshot {
        let analysis = analysisOrigin.map { origin in
            let frame = Int64(frame + UInt64(packet))
            let latest = PitchObservation(time: AnalysisTimestamp(frame: frame, sampleRate: 48000, hostSeconds: origin + Double(frame) / 48000),
                quality: .silence, pitch: nil, rms: 0, peak: 0, noiseFloor: 0, periodEvidence: nil)
            return AudioAnalysisSnapshot(algorithmVersion: MonophonicAnalyzer.algorithmVersion, latest: latest, events: [], totalEvents: 0,
                invalidSamples: 0, qualitySpans: [], totalQualitySpans: 0)
        }
        return CaptureSnapshot(totalFrames: frame + UInt64(packet), totalPackets: frame / UInt64(packet) + 1, droppedPackets: 0,
            peak: 0.1, rms: 0.05, sampleRate: 48000, lastHostTime: AVAudioTime.hostTime(forSeconds: 100 + Double(frame) / 48000 + drift),
            hostTimeValid: true, analysis: analysis, lastPacketFrames: packet)
    }
    private func output(_ id: UUID, frame: Int64, drift: Double = 0) -> TransportPlaybackSnapshot {
        TransportPlaybackSnapshot(requestID: id, phase: .playing, position: TransportPosition(tick: 0, loopIndex: 0, countInBeat: nil, completed: false),
            sampleRate: 48000, renderedFrames: frame, scheduledStartHostSeconds: 100, renderAnchorHostSeconds: 100 + drift, presentationLatency: 0)
    }
    @Test func preflightAndPreviousRepeatDriftRemainVisibleRelativeToAnalyzerOrigin() {
        var tracker = ClockDriftTracker(); let now = ContinuousClock.now
        for (index, drift) in [0.03, 0.06].enumerated() {
            let id = UUID(), frame = UInt64(index + 1) * 480000
            _ = tracker.consume(input: input(frame: frame, drift: drift, analysisOrigin: 100), output: output(id, frame: 0), now: now)
            let value = tracker.consume(input: input(frame: frame + 4800, drift: drift, analysisOrigin: 100),
                output: output(id, frame: 4800), now: now.advanced(by: .milliseconds(100)))
            #expect(abs((value.validatedDriftSeconds ?? 0) - drift) < 1e-6)
        }
    }
    @Test func firstPacketFrameAndStreamLocalAnchorsPreventFalseBufferOffset() {
        var tracker = ClockDriftTracker(); let id = UUID(), now = ContinuousClock.now
        #expect(tracker.consume(input: input(frame: 0), output: output(id, frame: 0), now: now).validatedDriftSeconds == nil)
        let steady = tracker.consume(input: input(frame: 4800, packet: 1024), output: output(id, frame: 4800), now: now.advanced(by: .milliseconds(100)))
        #expect(abs(steady.validatedDriftSeconds ?? 1) < 1e-6)
        let drifted = tracker.consume(input: input(frame: 9600, drift: 0.05), output: output(id, frame: 9600), now: now.advanced(by: .milliseconds(200)))
        #expect(abs((drifted.relativeDriftSeconds ?? 0) - 0.05) < 1e-6)
        let recovered = tracker.consume(input: input(frame: 14400), output: output(id, frame: 14400), now: now.advanced(by: .milliseconds(300)))
        #expect(abs(recovered.relativeDriftSeconds ?? 1) < 1e-6)
        #expect(abs((recovered.maximumAbsoluteDriftSeconds ?? 0) - 0.05) < 1e-6)
    }
    @Test func duplicateFramesCannotKeepClockEvidenceFreshAndResetRequiresNewSegment() {
        var tracker = ClockDriftTracker(); let id = UUID(), now = ContinuousClock.now
        _ = tracker.consume(input: input(frame: 0), output: output(id, frame: 0), now: now)
        _ = tracker.consume(input: input(frame: 4800), output: output(id, frame: 4800), now: now)
        let stale = tracker.consume(input: input(frame: 4800), output: output(id, frame: 4800), now: now.advanced(by: .milliseconds(501)))
        #expect(stale.validatedDriftSeconds == nil)
        let backwards = tracker.consume(input: input(frame: 0), output: output(id, frame: 9600), now: now)
        #expect(backwards.validatedDriftSeconds == nil)
        #expect(tracker.consume(input: input(frame: 14400), output: output(id, frame: 14400), now: now).validatedDriftSeconds == nil)
        let next = UUID()
        _ = tracker.consume(input: input(frame: 0), output: output(next, frame: 0), now: now)
        #expect(tracker.consume(input: input(frame: 4800), output: output(next, frame: 4800), now: now).validatedDriftSeconds != nil)
    }
}
