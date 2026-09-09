import CoreAudio
import Foundation

public struct AudioDeviceDescriptor: Identifiable, Sendable, Equatable {
    public let hardwareID: AudioDeviceID
    public let uid: String
    public let name: String
    public let inputChannels: Int
    public let outputChannels: Int
    public let sampleRate: Double
    public let bufferFrames: UInt32
    public let transportType: UInt32
    public var isUSB: Bool { transportType == kAudioDeviceTransportTypeUSB }
    public var id: String { uid }
}

public enum AudioBackendError: Error, Sendable, Equatable {
    case system(OSStatus)
    case unavailableDevice
    case invalidChannel
    case invalidFormat
    case permissionDenied
    case allocationFailed
}

/// Read-only hardware discovery; does not request permission or modify system defaults.
public struct AudioDeviceService: Sendable {
    public init() {}

    public func devices() throws -> [AudioDeviceDescriptor] {
        var address = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard !ids.isEmpty else { return [] }
        try ids.withUnsafeMutableBytes {
            try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, $0.baseAddress!))
        }
        // Devices may disappear during enumeration. Skip only the vanished device.
        return ids.compactMap { id in
            guard let uid = try? string(id, kAudioDevicePropertyDeviceUID),
                  let name = try? string(id, kAudioObjectPropertyName),
                  let input = try? channels(id, scope: kAudioDevicePropertyScopeInput),
                  let output = try? channels(id, scope: kAudioDevicePropertyScopeOutput) else { return nil }
            return AudioDeviceDescriptor(hardwareID: id, uid: uid, name: name,
                inputChannels: input, outputChannels: output,
                sampleRate: (try? scalar(id, kAudioDevicePropertyNominalSampleRate, initial: 0.0)) ?? 0,
                bufferFrames: (try? scalar(id, kAudioDevicePropertyBufferFrameSize, initial: UInt32(0))) ?? 0,
                transportType: (try? scalar(id, kAudioDevicePropertyTransportType, initial: UInt32(0))) ?? 0)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func channels(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) throws -> Int {
        var property = address(kAudioDevicePropertyStreamConfiguration, scope: scope)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size))
        guard size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { memory.deallocate() }
        try check(AudioObjectGetPropertyData(id, &property, 0, nil, &size, memory))
        let buffers = UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private func string(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) throws -> String {
        var property = address(selector)
        var value: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try withUnsafeMutablePointer(to: &value) {
            try check(AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0))
        }
        guard let value else { throw AudioBackendError.unavailableDevice }
        // AudioHardwareBase.h specifies caller-owned CFObjects for name and UID.
        return value.takeRetainedValue() as String
    }

    private func scalar<T>(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector, initial: T) throws -> T {
        var property = address(selector), value = initial
        var size = UInt32(MemoryLayout<T>.size)
        try withUnsafeMutableBytes(of: &value) {
            try check(AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0.baseAddress!))
        }
        return value
    }

    private func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private func check(_ status: OSStatus) throws {
        if status != noErr { throw AudioBackendError.system(status) }
    }
}
