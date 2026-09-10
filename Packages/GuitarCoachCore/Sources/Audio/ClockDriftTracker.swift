import Foundation
import AVFAudio

public struct ClockDriftSnapshot: Equatable, Sendable {
    public let relativeDriftSeconds: Double?
    public let maximumAbsoluteDriftSeconds: Double?
    public let observedSeconds: Double
    public let isFresh: Bool
    public var validatedDriftSeconds: Double? { isFresh && observedSeconds >= 0.1 ? maximumAbsoluteDriftSeconds : nil }
}

/// Compares each stream's frame-to-host mapping with its own initial anchor. It never compares device sample counters.
public struct ClockDriftTracker: Sendable {
    private var requestID: UUID?
    private var inputBase: Double?
    private var outputBase: Double?
    private var inputDelta: Double?
    private var outputDelta: Double?
    private var firstInputFrame: UInt64?
    private var firstOutputFrame: Int64?
    private var lastInputFrame: UInt64?
    private var lastOutputFrame: Int64?
    private var inputFreshAt: ContinuousClock.Instant?
    private var outputFreshAt: ContinuousClock.Instant?
    private var maximum = 0.0
    private var invalid = false
    public init() {}
    public mutating func reset() { self = ClockDriftTracker() }

    public mutating func consume(input: CaptureSnapshot?, output: TransportPlaybackSnapshot?,
                                 now: ContinuousClock.Instant = .now) -> ClockDriftSnapshot {
        guard let input, let output else {
            if inputBase != nil && outputBase != nil { invalid = true }
            return unavailable
        }
        if requestID != output.requestID { reset(); requestID = output.requestID }
        guard input.hostTimeValid, input.lastPacketFrames > 0, input.totalFrames >= UInt64(input.lastPacketFrames),
              input.sampleRate.isFinite, input.sampleRate > 0, output.sampleRate.isFinite, output.sampleRate > 0, output.renderedFrames >= 0,
              let anchor = output.renderAnchorHostSeconds, anchor.isFinite,
              input.droppedPackets == 0, input.discontinuities == 0, input.invalidSamples == 0 else {
            if inputBase != nil && outputBase != nil { invalid = true }
            return unavailable
        }
        let inputFrame = input.totalFrames - UInt64(input.lastPacketFrames)
        if let lastInputFrame, inputFrame < lastInputFrame { invalid = true }
        if let lastOutputFrame, output.renderedFrames < lastOutputFrame { invalid = true }
        if inputFrame != lastInputFrame {
            let inputAnchor = AVAudioTime.seconds(forHostTime: input.lastHostTime) - Double(inputFrame) / input.sampleRate
            if inputBase == nil { inputBase = inputAnchor; firstInputFrame = inputFrame }
            inputDelta = inputAnchor - inputBase!
            lastInputFrame = inputFrame; inputFreshAt = now
        }
        if output.renderedFrames != lastOutputFrame {
            if outputBase == nil { outputBase = anchor; firstOutputFrame = output.renderedFrames }
            outputDelta = anchor - outputBase!
            lastOutputFrame = output.renderedFrames; outputFreshAt = now
        }
        guard !invalid, let inputDelta, let outputDelta, let inputFreshAt, let outputFreshAt else { return unavailable }
        let drift = inputDelta - outputDelta
        guard drift.isFinite else { invalid = true; return unavailable }
        maximum = max(maximum, abs(drift))
        let duration = min(Double(inputFrame - (firstInputFrame ?? inputFrame)) / input.sampleRate,
                           Double(output.renderedFrames - (firstOutputFrame ?? output.renderedFrames)) / output.sampleRate)
        let outputFresh = output.phase == .completed || outputFreshAt.duration(to: now) <= .milliseconds(500)
        let phaseValid = output.phase == .playing || output.phase == .completed
        return ClockDriftSnapshot(relativeDriftSeconds: drift, maximumAbsoluteDriftSeconds: maximum, observedSeconds: duration,
            isFresh: phaseValid && inputFreshAt.duration(to: now) <= .milliseconds(500) && outputFresh)
    }
    private var unavailable: ClockDriftSnapshot {
        ClockDriftSnapshot(relativeDriftSeconds: nil, maximumAbsoluteDriftSeconds: nil, observedSeconds: 0, isFresh: false)
    }
}
