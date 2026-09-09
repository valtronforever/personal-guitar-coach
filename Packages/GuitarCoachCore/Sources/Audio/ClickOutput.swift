import AVFAudio
import AudioToolbox

/// A fixed-tempo output probe. Full transport/count-in is implemented in task 14.
public actor ClickOutput {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    public private(set) var scheduledStartHostTime: UInt64 = 0
    public private(set) var sampleRate: Double = 0

    public init() {}

    public func start(device: AudioDeviceDescriptor, channel: Int = 1) throws {
        stop()
        guard channel > 0, channel <= device.outputChannels else { throw AudioBackendError.unavailableDevice }
        let engine = AVAudioEngine()
        guard let output = engine.outputNode.audioUnit else { throw AudioBackendError.unavailableDevice }
        var id = device.hardwareID
        let status = AudioUnitSetProperty(output, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout.size(ofValue: id)))
        guard status == noErr else { throw AudioBackendError.system(status) }
        let native = engine.outputNode.inputFormat(forBus: 0)
        let rate = native.sampleRate
        let channelCount = Int(native.channelCount)
        guard channel <= channelCount, channelCount > 0, channelCount <= 256 else { throw AudioBackendError.invalidChannel }
        guard rate.isFinite, (8_000...384_000).contains(rate),
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(channelCount)),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate / 2)),
              let channels = buffer.floatChannelData else { throw AudioBackendError.invalidFormat }
        buffer.frameLength = buffer.frameCapacity
        for index in 0..<channelCount {
            channels[index].initialize(repeating: 0, count: Int(buffer.frameLength))
        }
        let samples = channels[channel - 1]
        let clickFrames = Int(rate * 0.012)
        for i in 0..<Int(buffer.frameLength) {
            samples[i] = i < clickFrames
                ? Float(sin(2 * .pi * 1200 * Double(i) / rate) * (1 - Double(i) / Double(clickFrames)) * 0.12)
                : 0
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.outputNode, format: format)
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        try engine.start()
        let start = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.1)
        player.play(at: AVAudioTime(hostTime: start))
        self.engine = engine
        self.player = player
        self.sampleRate = rate
        scheduledStartHostTime = start
    }

    public func stop() {
        player?.stop()
        engine?.stop()
        player = nil
        engine = nil
        scheduledStartHostTime = 0
        sampleRate = 0
    }
}
