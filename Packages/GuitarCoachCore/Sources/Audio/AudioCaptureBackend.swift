import AVFAudio
import RealtimeAudio

public struct CaptureSnapshot: Sendable {
    public let totalFrames: UInt64
    public let totalPackets: UInt64
    public let droppedPackets: UInt64
    public let peak: Float
    public let rms: Float
    public let sampleRate: Double
    public let lastHostTime: UInt64
    public let hostTimeValid: Bool
}

/// C owns the SPSC synchronization. The input unit is the sole producer and
/// PCMReader is the sole consumer. Destruction follows AudioOutputUnitStop.
private final class PCMStorage: @unchecked Sendable {
    let handle: OpaquePointer
    let maxFrames: UInt32 = 8192
    init() throws {
        guard let handle = GCRingCreate(64, maxFrames) else { throw AudioBackendError.allocationFailed }
        self.handle = handle
    }
    deinit { GCRingDestroy(handle) }
}

private final class InputUnit {
    let handle: OpaquePointer
    let storage: PCMStorage
    init(device: AudioDeviceDescriptor, channel: Int, storage: PCMStorage) throws {
        self.storage = storage
        var status: OSStatus = 0
        guard let handle = GCInputCreate(device.hardwareID, UInt32(channel - 1), storage.handle, &status) else {
            throw AudioBackendError.system(status)
        }
        self.handle = handle
    }
    deinit { GCInputDestroy(handle) }
}

/// Metrics are computed on this actor, never on the audio callback or MainActor.
private actor PCMReader {
    let storage: PCMStorage
    var scratch = [Float](repeating: 0, count: 8192)
    var totalFrames: UInt64 = 0
    var totalPackets: UInt64 = 0
    var last = GCPacketInfo()

    init(storage: PCMStorage) { self.storage = storage }

    func drain() -> CaptureSnapshot {
        var peak: Float = 0
        var squares: Double = 0
        var count = 0
        var info = GCPacketInfo()
        // Bound each drain even if the producer continues filling the ring.
        for _ in 0..<64 {
            let available = scratch.withUnsafeMutableBufferPointer {
                GCRingRead(storage.handle, $0.baseAddress!, UInt32($0.count), &info)
            }
            guard available else { break }
            for i in 0..<Int(info.frame_count) {
                let value = scratch[i]
                if value.isFinite {
                    peak = max(peak, abs(value))
                    squares += Double(value) * Double(value)
                }
            }
            count += Int(info.frame_count)
            totalFrames += UInt64(info.frame_count)
            totalPackets += 1
            last = info
        }
        return CaptureSnapshot(totalFrames: totalFrames, totalPackets: totalPackets,
            droppedPackets: GCRingDropped(storage.handle), peak: peak,
            rms: count > 0 ? Float((squares / Double(count)).squareRoot()) : 0,
            sampleRate: last.sample_rate, lastHostTime: last.host_time, hostTimeValid: last.host_time_valid)
    }
}

public actor AudioCaptureBackend {
    private var unit: InputUnit?
    private var reader: PCMReader?
    public private(set) var sampleRate: Double = 0
    public private(set) var channelCount: UInt32 = 0
    public var isRunning: Bool { unit != nil }

    public init() {}

    /// Channel is one-based in the user-facing API. No system default is changed.
    public func start(device: AudioDeviceDescriptor, channel: Int) throws {
        stop()
        guard channel > 0, channel <= device.inputChannels else { throw AudioBackendError.invalidChannel }
        let storage = try PCMStorage()
        let next = try InputUnit(device: device, channel: channel, storage: storage)
        let rate = GCInputSampleRate(next.handle)
        guard rate.isFinite, rate > 0 else { throw AudioBackendError.invalidFormat }
        let status = GCInputStart(next.handle)
        guard status == noErr else { throw AudioBackendError.system(status) }
        reader = PCMReader(storage: storage)
        sampleRate = rate
        channelCount = GCInputChannelCount(next.handle)
        unit = next
    }

    public func snapshot() async -> CaptureSnapshot? { await reader?.drain() }

    public func stop() {
        unit = nil // Stops and disposes AUHAL before its ring can be released.
        reader = nil
        sampleRate = 0
        channelCount = 0
    }
}
