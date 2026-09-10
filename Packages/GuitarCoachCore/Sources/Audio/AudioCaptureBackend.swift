import AVFAudio
import RealtimeAudio

public struct CaptureSnapshot: Sendable, Equatable {
    public let totalFrames: UInt64
    public let totalPackets: UInt64
    public let droppedPackets: UInt64
    public let peak: Float
    public let rms: Float
    public let sampleRate: Double
    public let lastHostTime: UInt64
    public let hostTimeValid: Bool
    public let lastSampleTime: Double
    public let sampleTimeValid: Bool
    public let invalidSamples: UInt64
    public let discontinuities: UInt64
    /// The host/sample timestamps label the first frame of this last packet, not totalFrames.
    public let lastPacketFrames: UInt32
    public let analysis: AudioAnalysisSnapshot?
    public init(totalFrames: UInt64, totalPackets: UInt64, droppedPackets: UInt64, peak: Float, rms: Float,
                sampleRate: Double, lastHostTime: UInt64, hostTimeValid: Bool, lastSampleTime: Double = 0,
                sampleTimeValid: Bool = false, invalidSamples: UInt64 = 0, discontinuities: UInt64 = 0,
                analysis: AudioAnalysisSnapshot? = nil, lastPacketFrames: UInt32 = 0) {
        self.totalFrames = totalFrames; self.totalPackets = totalPackets; self.droppedPackets = droppedPackets
        self.peak = peak; self.rms = rms; self.sampleRate = sampleRate; self.lastHostTime = lastHostTime
        self.hostTimeValid = hostTimeValid; self.lastSampleTime = lastSampleTime; self.sampleTimeValid = sampleTimeValid
        self.invalidSamples = invalidSamples; self.discontinuities = discontinuities
        self.analysis = analysis; self.lastPacketFrames = lastPacketFrames
    }
}

/// C owns the SPSC synchronization. The input unit is the sole producer and
/// PCMReader is the sole consumer. Destruction follows AudioOutputUnitStop.
final class PCMStorage: @unchecked Sendable {
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
actor PCMReader {
    let storage: PCMStorage
    var scratch = [Float](repeating: 0, count: 8192)
    var totalFrames: UInt64 = 0
    var totalPackets: UInt64 = 0
    var last = GCPacketInfo()
    var invalidSamples: UInt64 = 0
    var discontinuities: UInt64 = 0
    let analyzer: MonophonicAnalyzer
    var latest: CaptureSnapshot?

    init(storage: PCMStorage, sampleRate: Double) throws {
        self.storage = storage; analyzer = try MonophonicAnalyzer(sampleRate: sampleRate)
    }

    func run() async {
        while !Task.isCancelled {
            drain()
            do { try await Task.sleep(for: .milliseconds(5)) } catch { break }
        }
    }

    func snapshot() -> CaptureSnapshot? { latest }

    func drain() {
        var peak: Float = 0
        var squares: Double = 0
        var count = 0
        var info = GCPacketInfo()
        // Bound each drain even if the producer continues filling the ring.
        for _ in 0..<64 {
            guard !Task.isCancelled else { break }
            let available = scratch.withUnsafeMutableBufferPointer {
                GCRingRead(storage.handle, $0.baseAddress!, UInt32($0.count), &info)
            }
            guard available else { break }
            if !info.host_time_valid || info.sample_rate != analyzer.sampleRate { discontinuities += 1 }
            if info.sample_time_valid && !info.sample_time.isFinite { discontinuities += 1 }
            if totalPackets > 0, info.sample_time_valid, last.sample_time_valid,
               abs(info.sample_time - last.sample_time - Double(last.frame_count)) > 0.5 { discontinuities += 1 }
            for i in 0..<Int(info.frame_count) {
                let value = scratch[i]
                if value.isFinite {
                    peak = max(peak, abs(value))
                    squares += Double(value) * Double(value)
                } else { invalidSamples += 1 }
            }
            scratch.withUnsafeBufferPointer { samples in
                analyzer.process(.init(rebasing: samples[0..<Int(info.frame_count)]),
                    startHostSeconds: info.host_time_valid ? AVAudioTime.seconds(forHostTime: info.host_time) : nil)
            }
            count += Int(info.frame_count)
            totalFrames += UInt64(info.frame_count)
            totalPackets += 1
            last = info
        }
        guard count > 0 else { return }
        latest = CaptureSnapshot(totalFrames: totalFrames, totalPackets: totalPackets,
            droppedPackets: GCRingDropped(storage.handle), peak: peak,
            rms: count > 0 ? Float((squares / Double(count)).squareRoot()) : 0,
            sampleRate: last.sample_rate, lastHostTime: last.host_time, hostTimeValid: last.host_time_valid,
            lastSampleTime: last.sample_time, sampleTimeValid: last.sample_time_valid,
            invalidSamples: invalidSamples, discontinuities: discontinuities, analysis: analyzer.snapshot(), lastPacketFrames: last.frame_count)
    }
}

public actor AudioCaptureBackend {
    private var unit: InputUnit?
    private var reader: PCMReader?
    private var worker: Task<Void, Never>?
    public private(set) var sampleRate: Double = 0
    public private(set) var channelCount: UInt32 = 0
    public var isRunning: Bool { unit != nil }

    public init() {}
    deinit { worker?.cancel() }

    /// Channel is one-based in the user-facing API. No system default is changed.
    public func start(device: AudioDeviceDescriptor, channel: Int) throws {
        stop()
        guard channel > 0, channel <= device.inputChannels else { throw AudioBackendError.invalidChannel }
        let storage = try PCMStorage()
        let next = try InputUnit(device: device, channel: channel, storage: storage)
        let rate = GCInputSampleRate(next.handle)
        guard rate.isFinite, rate > 0 else { throw AudioBackendError.invalidFormat }
        let nextReader = try PCMReader(storage: storage, sampleRate: rate)
        let status = GCInputStart(next.handle)
        guard status == noErr else { throw AudioBackendError.system(status) }
        reader = nextReader
        worker = Task { await nextReader.run() }
        sampleRate = rate
        channelCount = GCInputChannelCount(next.handle)
        unit = next
    }

    public func snapshot() async -> CaptureSnapshot? { await reader?.snapshot() }

    public func stop() {
        worker?.cancel(); worker = nil
        unit = nil // Stops and disposes AUHAL before its ring can be released.
        reader = nil
        sampleRate = 0
        channelCount = 0
    }
}
