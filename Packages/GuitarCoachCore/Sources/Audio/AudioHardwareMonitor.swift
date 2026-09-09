import CoreAudio
import Foundation

/// HAL property callbacks only enqueue a coalesced change signal; discovery happens on a worker.
public actor AudioHardwareMonitor {
    public nonisolated let changes: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private var registrations: [Registration] = []
    private var watched: Set<AudioDeviceID>?

    public init() {
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        changes = stream.stream; continuation = stream.continuation
    }

    public func watch(deviceIDs: Set<AudioDeviceID>) {
        guard watched != deviceIDs else { return }
        watched = deviceIDs; registrations = []
        add(AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDevices)
        for id in deviceIDs {
            for selector in [kAudioDevicePropertyDeviceIsAlive, kAudioDevicePropertyNominalSampleRate,
                             kAudioDevicePropertyBufferFrameSize, kAudioDevicePropertyHogMode,
                             kAudioDevicePropertyStreams, kAudioDevicePropertyStreamConfiguration] {
                add(id, selector: selector)
            }
        }
    }

    public func stop() { registrations = []; watched = nil; continuation.finish() }

    private func add(_ id: AudioObjectID, selector: AudioObjectPropertySelector) {
        let property = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeWildcard,
                                                  mElement: kAudioObjectPropertyElementWildcard)
        if let item = Registration(id: id, property: property, continuation: continuation) { registrations.append(item) }
        // Periodic discovery remains a fallback for drivers without notifications for a property.
    }
}

private final class Registration {
    let id: AudioObjectID
    var property: AudioObjectPropertyAddress
    let queue = DispatchQueue(label: "coach.audio.hardware-notification", qos: .utility)
    let block: AudioObjectPropertyListenerBlock
    init?(id: AudioObjectID, property: AudioObjectPropertyAddress, continuation: AsyncStream<Void>.Continuation) {
        self.id = id; self.property = property
        block = { _, _ in continuation.yield(()) }
        guard AudioObjectAddPropertyListenerBlock(id, &self.property, queue, block) == noErr else { return nil }
    }
    deinit { AudioObjectRemovePropertyListenerBlock(id, &property, queue, block) }
}
