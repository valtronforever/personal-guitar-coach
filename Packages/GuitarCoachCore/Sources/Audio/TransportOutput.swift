import AVFAudio
import AudioToolbox
import Foundation

public enum TransportPlaybackPhase: Equatable, Sendable { case playing, completed, interrupted(AudioBackendError) }
public struct TransportPlaybackSnapshot: Equatable, Sendable {
    public let requestID: UUID
    public let phase: TransportPlaybackPhase
    public let position: TransportPosition
    public let sampleRate: Double
    public let renderedFrames: Int64
    public let scheduledStartHostSeconds: Double
    /// Anchor of the actual player timeline in the host clock; nil until a valid render timestamp arrives.
    public let renderAnchorHostSeconds: Double?
    /// Output presentation estimate; task 15 determines calibrated timestamp normalization.
    public let presentationLatency: Double
}

/// Audio-clock playback. A dedicated actor maintains a bounded one-second queue of sample-timed buffers.
/// SwiftUI never schedules a click. No application code or allocation runs in a render callback.
public actor TransportOutput {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var plan: TransportPlan?
    private var channel = 0
    private var nextFrame: Int64 = 0
    private var startHost: UInt64 = 0
    private var latency = 0.0
    private var tailFrames: Int64 = 0
    private var lastProgress = ContinuousClock.now
    private var lastFrame: Int64 = 0
    private var worker: Task<Void, Never>?
    private var state: TransportPlaybackSnapshot?
    public init() {}
    deinit { worker?.cancel() }

    public func start(device: AudioDeviceDescriptor, channel: Int, request: TransportRequest) throws {
        stop()
        guard channel > 0, channel <= device.outputChannels else { throw AudioBackendError.invalidChannel }
        let engine = AVAudioEngine()
        guard let unit = engine.outputNode.audioUnit else { throw AudioBackendError.unavailableDevice }
        var id = device.hardwareID
        let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global,
                                         0, &id, UInt32(MemoryLayout.size(ofValue: id)))
        guard status == noErr else { throw AudioBackendError.system(status) }
        let native = engine.outputNode.inputFormat(forBus: 0)
        guard native.sampleRate == device.sampleRate, (1...256).contains(Int(native.channelCount)),
              channel <= Int(native.channelCount),
              let format = AVAudioFormat(standardFormatWithSampleRate: native.sampleRate, channels: native.channelCount) else {
            throw AudioBackendError.invalidFormat
        }
        let plan = try TransportPlan(request: request, sampleRate: native.sampleRate)
        let player = AVAudioPlayerNode()
        engine.attach(player); engine.connect(player, to: engine.outputNode, format: format)
        self.engine = engine; self.player = player; self.format = format; self.plan = plan; self.channel = channel - 1
        do {
            try schedule(through: Int64(plan.sampleRate))
            try engine.start()
            latency = engine.outputNode.presentationLatency
            guard latency.isFinite, (0...5).contains(latency) else { throw AudioBackendError.invalidFormat }
            tailFrames = Int64((latency + 0.05) * plan.sampleRate) + Int64(device.bufferFrames)
            startHost = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.15)
            player.play(at: AVAudioTime(hostTime: startHost))
            lastProgress = .now; lastFrame = 0
            state = snapshot(plan: plan, frame: 0, anchor: nil, phase: .playing)
            worker = Task { [weak self] in
                while !Task.isCancelled {
                    guard await self?.pump() == true else { break }
                    do { try await Task.sleep(for: .milliseconds(20)) } catch { break }
                }
            }
        } catch { stop(); throw error }
    }

    public func read() -> TransportPlaybackSnapshot? { state }

    public func stop() {
        worker?.cancel(); worker = nil
        player?.stop(); engine?.stop()
        player = nil; engine = nil; format = nil; plan = nil
        state = nil; nextFrame = 0; startHost = 0; latency = 0; tailFrames = 0
    }

    private func pump() -> Bool {
        guard let plan, let player, let engine else { return false }
        guard engine.isRunning else { finish(.interrupted(.streamStalled)); return false }
        var frame: Int64 = 0
        var anchor: Double?
        if let nodeTime = player.lastRenderTime, let playerTime = player.playerTime(forNodeTime: nodeTime), playerTime.isSampleTimeValid {
            frame = max(0, playerTime.sampleTime)
            if nodeTime.isHostTimeValid { anchor = AVAudioTime.seconds(forHostTime: nodeTime.hostTime) - Double(playerTime.sampleTime) / plan.sampleRate }
        }
        if frame > lastFrame { lastFrame = frame; lastProgress = .now }
        if lastProgress.duration(to: .now) > .seconds(2) { finish(.interrupted(.streamStalled)); return false }
        if let end = plan.endFrame, frame >= end + tailFrames {
            state = snapshot(plan: plan, frame: frame, anchor: anchor, phase: .completed)
            finish(.completed); return false
        }
        guard frame < nextFrame else { finish(.interrupted(.dataLoss)); return false }
        do { try schedule(through: frame + Int64(plan.sampleRate)) }
        catch { finish(.interrupted(error as? AudioBackendError ?? .dataLoss)); return false }
        state = snapshot(plan: plan, frame: frame, anchor: anchor, phase: .playing)
        return true
    }

    private func schedule(through horizon: Int64) throws {
        guard let plan, let format, let player else { throw AudioBackendError.invalidFormat }
        let chunk = max(256, min(48000, Int(plan.sampleRate / 4)))
        while nextFrame < horizon {
            let samples = try plan.render(startFrame: nextFrame, count: chunk)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunk)),
                  let channels = buffer.floatChannelData else { throw AudioBackendError.invalidFormat }
            buffer.frameLength = AVAudioFrameCount(chunk)
            for index in 0..<Int(format.channelCount) { channels[index].initialize(repeating: 0, count: chunk) }
            for sample in 0..<chunk { channels[channel][sample] = samples[sample] }
            player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: nextFrame, atRate: plan.sampleRate), options: [], completionHandler: nil)
            nextFrame += Int64(chunk)
        }
    }

    private func snapshot(plan: TransportPlan, frame: Int64, anchor: Double?, phase: TransportPlaybackPhase) -> TransportPlaybackSnapshot {
        TransportPlaybackSnapshot(requestID: plan.request.id, phase: phase, position: plan.position(at: frame), sampleRate: plan.sampleRate,
            renderedFrames: frame, scheduledStartHostSeconds: AVAudioTime.seconds(forHostTime: startHost),
            renderAnchorHostSeconds: anchor, presentationLatency: latency)
    }
    private func finish(_ phase: TransportPlaybackPhase) {
        if let plan, let old = state {
            state = snapshot(plan: plan, frame: old.renderedFrames, anchor: old.renderAnchorHostSeconds, phase: phase)
        }
        player?.stop(); engine?.stop(); player = nil; engine = nil; format = nil; plan = nil; worker = nil
    }
}
