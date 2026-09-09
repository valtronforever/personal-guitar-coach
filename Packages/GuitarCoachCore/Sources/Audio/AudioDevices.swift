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
    public let isAlive: Bool
    public let exclusivePID: Int32
    public init(hardwareID: AudioDeviceID, uid: String, name: String, inputChannels: Int, outputChannels: Int,
                sampleRate: Double, bufferFrames: UInt32, transportType: UInt32 = 0, isAlive: Bool = true, exclusivePID: Int32 = -1) {
        self.hardwareID = hardwareID; self.uid = uid; self.name = name
        self.inputChannels = inputChannels; self.outputChannels = outputChannels; self.sampleRate = sampleRate
        self.bufferFrames = bufferFrames; self.transportType = transportType; self.isAlive = isAlive; self.exclusivePID = exclusivePID
    }
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
    case busyDevice, unsupportedControl, routeChanged, dataLoss, streamStalled, suspended, inUse, cancelled
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
                transportType: (try? scalar(id, kAudioDevicePropertyTransportType, initial: UInt32(0))) ?? 0,
                isAlive: (try? scalar(id, kAudioDevicePropertyDeviceIsAlive, initial: UInt32(0))) == 1,
                exclusivePID: (try? scalar(id, kAudioDevicePropertyHogMode, initial: Int32(-1))) ?? -1)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func capabilities(device: AudioDeviceDescriptor, inputChannel: Int) throws -> AudioDeviceCapabilities {
        let rates = (try? ranges(device.hardwareID, selector: kAudioDevicePropertyAvailableNominalSampleRates)) ?? []
        let buffer = (try? ranges(device.hardwareID, selector: kAudioDevicePropertyBufferFrameSizeRange))?.first
        let bufferRange: ClosedRange<UInt32>?
        if let buffer, buffer.lowerBound >= 1, buffer.upperBound <= Double(UInt32.max),
           buffer.lowerBound.rounded(.up) <= buffer.upperBound.rounded(.down) {
            bufferRange = UInt32(buffer.lowerBound.rounded(.up))...UInt32(buffer.upperBound.rounded(.down))
        } else { bufferRange = nil }
        var gain: AudioInputGain?
        for element in [UInt32(max(1, inputChannel)), kAudioObjectPropertyElementMain] {
            var property = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput)
            property.mElement = element
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectHasProperty(device.hardwareID, &property),
               AudioObjectGetPropertyData(device.hardwareID, &property, 0, nil, &size, &value) == noErr,
               value.isFinite, (0...1).contains(value) {
                gain = AudioInputGain(element: element, value: value, isSettable: settable(device.hardwareID, property))
                break
            }
        }
        return AudioDeviceCapabilities(sampleRates: rates, bufferRange: bufferRange,
            canSetSampleRate: settable(device.hardwareID, address(kAudioDevicePropertyNominalSampleRate)),
            canSetBufferFrames: settable(device.hardwareID, address(kAudioDevicePropertyBufferFrameSize)), inputGain: gain)
    }

    public func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) throws {
        guard rate.isFinite, try ranges(device.hardwareID, selector: kAudioDevicePropertyAvailableNominalSampleRates).contains(where: { $0.contains(rate) }) else {
            throw AudioBackendError.invalidFormat
        }
        try set(rate, device: device.hardwareID, property: address(kAudioDevicePropertyNominalSampleRate))
    }
    public func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) throws {
        guard frames > 0, try ranges(device.hardwareID, selector: kAudioDevicePropertyBufferFrameSizeRange).contains(where: { $0.contains(Double(frames)) }) else {
            throw AudioBackendError.invalidFormat
        }
        try set(frames, device: device.hardwareID, property: address(kAudioDevicePropertyBufferFrameSize))
    }
    public func setInputGain(_ gain: Float, device: AudioDeviceDescriptor, element: UInt32) throws {
        guard gain.isFinite, (0...1).contains(gain), element <= device.inputChannels else { throw AudioBackendError.invalidChannel }
        var property = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput)
        property.mElement = element
        try set(gain, device: device.hardwareID, property: property)
    }
    private func settable(_ id: AudioDeviceID, _ property: AudioObjectPropertyAddress) -> Bool {
        var property = property, value = DarwinBoolean(false)
        return AudioObjectHasProperty(id, &property) && AudioObjectIsPropertySettable(id, &property, &value) == noErr && value.boolValue
    }
    private func set<T>(_ value: T, device: AudioDeviceID, property: AudioObjectPropertyAddress) throws {
        guard settable(device, property) else { throw AudioBackendError.unsupportedControl }
        var property = property, value = value
        try withUnsafeBytes(of: &value) {
            try check(AudioObjectSetPropertyData(device, &property, 0, nil, UInt32($0.count), $0.baseAddress!))
        }
    }
    private func ranges(_ id: AudioDeviceID, selector: AudioObjectPropertySelector) throws -> [ClosedRange<Double>] {
        var property = address(selector), size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size))
        guard size > 0, size <= 65536, Int(size) % MemoryLayout<AudioValueRange>.size == 0 else { return [] }
        var values = [AudioValueRange](repeating: AudioValueRange(), count: Int(size) / MemoryLayout<AudioValueRange>.size)
        try values.withUnsafeMutableBytes {
            try check(AudioObjectGetPropertyData(id, &property, 0, nil, &size, $0.baseAddress!))
        }
        return values.compactMap { range in
            guard range.mMinimum.isFinite, range.mMaximum.isFinite, range.mMinimum > 0, range.mMinimum <= range.mMaximum else { return nil }
            return range.mMinimum...range.mMaximum
        }
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

public struct AudioInputGain: Equatable, Sendable {
    public let element: UInt32
    public let value: Float
    public let isSettable: Bool
}
public struct AudioDeviceCapabilities: Equatable, Sendable {
    public let sampleRates: [ClosedRange<Double>]
    public let bufferRange: ClosedRange<UInt32>?
    public let canSetSampleRate: Bool
    public let canSetBufferFrames: Bool
    public let inputGain: AudioInputGain?
}
