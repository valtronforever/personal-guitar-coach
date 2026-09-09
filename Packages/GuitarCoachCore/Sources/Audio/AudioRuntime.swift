import AVFoundation
import Domain

public enum AudioPermissionStatus: String, Sendable { case notDetermined, authorized, denied, restricted }
public protocol AudioPermissionProviding: Sendable {
    func status() async -> AudioPermissionStatus
    func request() async -> Bool
}
public struct SystemAudioPermission: AudioPermissionProviding {
    public init() {}
    public func status() async -> AudioPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .restricted
        }
    }
    public func request() async -> Bool { await AVCaptureDevice.requestAccess(for: .audio) }
}

public struct AudioStreamFormat: Equatable, Sendable {
    public let sampleRate: Double
    public let inputChannels: UInt32
    public init(sampleRate: Double, inputChannels: UInt32) { self.sampleRate = sampleRate; self.inputChannels = inputChannels }
}

/// Coordinator serializes hardware mutations; implementations perform no work on MainActor.
public protocol AudioRuntime: Sendable {
    func devices() async throws -> [AudioDeviceDescriptor]
    func capabilities(device: AudioDeviceDescriptor, channel: Int) async throws -> AudioDeviceCapabilities
    func startInput(device: AudioDeviceDescriptor, channel: Int) async throws -> AudioStreamFormat
    func stopInput() async
    func readInput() async -> CaptureSnapshot?
    func startClick(device: AudioDeviceDescriptor, channel: Int) async throws
    func stopClick() async
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) async throws
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) async throws
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) async throws
}

public actor LiveAudioRuntime: AudioRuntime {
    private let hardware = AudioDeviceService()
    private let capture = AudioCaptureBackend()
    private let click = ClickOutput()
    public init() {}
    public func devices() throws -> [AudioDeviceDescriptor] { try hardware.devices() }
    public func capabilities(device: AudioDeviceDescriptor, channel: Int) throws -> AudioDeviceCapabilities {
        try hardware.capabilities(device: device, inputChannel: channel)
    }
    public func startInput(device: AudioDeviceDescriptor, channel: Int) async throws -> AudioStreamFormat {
        try await capture.start(device: device, channel: channel)
        return await AudioStreamFormat(sampleRate: capture.sampleRate, inputChannels: capture.channelCount)
    }
    public func stopInput() async { await capture.stop() }
    public func readInput() async -> CaptureSnapshot? { await capture.snapshot() }
    public func startClick(device: AudioDeviceDescriptor, channel: Int) async throws { try await click.start(device: device, channel: channel) }
    public func stopClick() async { await click.stop() }
    public func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) throws { try hardware.setSampleRate(rate, device: device) }
    public func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) throws { try hardware.setBufferFrames(frames, device: device) }
    public func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) throws { try hardware.setInputGain(value, device: device, element: element) }
}
