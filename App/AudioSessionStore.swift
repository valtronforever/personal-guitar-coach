import SwiftUI
import AppKit
import Audio
import Domain
import Persistence

private enum AudioWorkspaceEvent: Sendable { case sleep, wake }

@MainActor @Observable
final class AudioSessionStore {
    let coordinator: AudioSessionCoordinator
    @ObservationIgnored private let repository: (any AudioSettingsRepository)?
    @ObservationIgnored private var monitor: AudioHardwareMonitor?
    @ObservationIgnored private var isMonitoring = false
    @ObservationIgnored private var monitoringTask: Task<Void, Never>?
    private(set) var state: AudioCoordinatorSnapshot?
    private(set) var hasLoaded = false
    private(set) var loadFailed = false
    private(set) var isBusy = false
    private(set) var error: AudioBackendError?
    private(set) var storageError: String?
    var selection: AudioRouteSelection { state?.selection ?? .unselected }
    var inputs: [AudioDeviceDescriptor] { state?.devices.filter { $0.inputChannels > 0 } ?? [] }
    var outputs: [AudioDeviceDescriptor] { state?.devices.filter { $0.outputChannels > 0 } ?? [] }
    var selectedInput: AudioDeviceDescriptor? { inputs.first { $0.uid == selection.inputUID } }
    var selectedOutput: AudioDeviceDescriptor? { outputs.first { $0.uid == selection.outputUID } }
    var canEdit: Bool { hasLoaded && !loadFailed && !isBusy }

    init(repository: (any AudioSettingsRepository)?, coordinator: AudioSessionCoordinator = AudioSessionCoordinator()) {
        self.repository = repository; self.coordinator = coordinator
    }

    func load() async {
        guard !isBusy, !hasLoaded || loadFailed else { return }
        isBusy = true
        defer { isBusy = false; hasLoaded = true }
        do {
            guard let repository else { throw StorageError.corruptDocument }
            let saved = try await repository.loadAudioSelection()
            await coordinator.configure(saved)
            await coordinator.refresh()
            loadFailed = false; storageError = nil
        } catch { loadFailed = true; storageError = "audio.storageLoadFailed" }
        await publish()
    }

    func activate() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { await run() }
    }

    func shutdown() async {
        monitoringTask?.cancel()
        await monitoringTask?.value
        monitoringTask = nil
    }

    /// Polling only displays meters and checks liveness; it is never a musical clock.
    private func run() async {
        guard !isMonitoring else { return }
        isMonitoring = true
        let monitor = AudioHardwareMonitor(); self.monitor = monitor
        await load(); await publish()
        let changes = Task { [weak self, coordinator] in
            for await _ in monitor.changes {
                guard !Task.isCancelled else { break }
                await coordinator.refresh(); await self?.publish()
            }
        }
        // Discard Notification inside its callback; older Swift SDKs do not mark it Sendable.
        let events = AsyncStream<AudioWorkspaceEvent>.makeStream(bufferingPolicy: .bufferingNewest(8))
        let center = NSWorkspace.shared.notificationCenter
        let sleepToken = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
            events.continuation.yield(.sleep)
        }
        let wakeToken = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
            events.continuation.yield(.wake)
        }
        let powerEvents = Task { [weak self, coordinator] in
            for await event in events.stream {
                guard !Task.isCancelled else { break }
                await coordinator.suspend()
                if event == .wake { await coordinator.refresh() }
                await self?.publish() // Explicit Start is required after wake.
            }
        }
        var count = 0
        while !Task.isCancelled {
            if count % 20 == 0 { await coordinator.refresh() }
            await coordinator.poll(); await publish()
            count = (count + 1) % 20
            do { try await Task.sleep(for: .milliseconds(50)) } catch { break }
        }
        changes.cancel(); powerEvents.cancel()
        center.removeObserver(sleepToken); center.removeObserver(wakeToken)
        events.continuation.finish()
        await coordinator.stop(); await monitor.stop()
        self.monitor = nil; isMonitoring = false
    }

    func publish() async {
        let next = await coordinator.snapshot()
        if state != next { state = next }
        await monitor?.watch(deviceIDs: Set(next.devices.filter { $0.uid == next.selection.inputUID || $0.uid == next.selection.outputUID }.map(\.hardwareID)))
    }

    func select(inputUID: String? = nil, inputChannel: Int? = nil, outputUID: String? = nil, outputChannel: Int? = nil) async {
        guard canEdit, let repository else { return }
        isBusy = true; error = nil; storageError = nil
        defer { isBusy = false }
        do {
            let next = try AudioRouteSelection(inputUID: inputUID.map { $0.isEmpty ? nil : $0 } ?? selection.inputUID,
                inputChannel: inputChannel ?? (inputUID == nil ? selection.inputChannel : 1),
                outputUID: outputUID.map { $0.isEmpty ? nil : $0 } ?? selection.outputUID,
                outputChannel: outputChannel ?? (outputUID == nil ? selection.outputChannel : 1))
            await coordinator.stop(reason: state?.phase == .running || state?.isClicking == true ? .routeChanged : nil)
            try await repository.saveAudioSelection(next)
            await coordinator.configure(next)
        } catch { storageError = "audio.storageSaveFailed" }
        await publish()
    }

    func start(purpose: AudioPurpose = .setup, requestID: UUID = UUID()) async {
        error = nil
        do { try await coordinator.start(purpose: purpose, requestID: requestID) }
        catch { if let value = error as? AudioBackendError, value != .cancelled { self.error = value } }
        await publish()
    }
    func stopCapture(id: UUID) async { await coordinator.stopCapture(requestID: id); await publish() }
    func stop() async { await coordinator.stop(); error = nil; await publish() }
    func stop(purpose: AudioPurpose) async { await coordinator.stopActivity(purpose); await publish() }
    func startTransport(_ request: TransportRequest) async {
        error = nil
        do { try await coordinator.startTransport(request) }
        catch { if let value = error as? AudioBackendError, value != .cancelled { self.error = value } }
        await publish()
    }
    func stopTransport(id: UUID) async { await coordinator.stopTransport(requestID: id); await publish() }
    func dismissSetup() async {
        await coordinator.stopActivity(.setup)
        await publish()
    }
    func toggleClick() async {
        error = nil
        if state?.isClicking == true { await coordinator.stopClick() }
        else {
            do { try await coordinator.startClick() }
            catch { if let value = error as? AudioBackendError, value != .cancelled { self.error = value } }
        }
        await publish()
    }
    func refresh() async { await coordinator.refresh(); await publish() }
    func setRate(_ value: Double) async { await changeHardware { try await $0.changeSampleRate(value) } }
    func setBuffer(_ value: UInt32) async { await changeHardware { try await $0.changeBufferFrames(value) } }
    func setGain(_ value: Float, element: UInt32) async { await changeHardware { try await $0.changeInputGain(value, element: element) } }
    private func changeHardware(_ operation: (AudioSessionCoordinator) async throws -> Void) async {
        guard canEdit else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do { try await operation(coordinator) } catch { self.error = error as? AudioBackendError ?? .unsupportedControl }
        await publish()
    }
}
