import Foundation
import Testing
import Domain
@testable import Audio

private actor PermissionStub: AudioPermissionProviding {
    var permission: AudioPermissionStatus
    var requests = 0
    var gate: CheckedContinuation<Bool, Never>?
    init(_ permission: AudioPermissionStatus = .authorized) { self.permission = permission }
    func status() -> AudioPermissionStatus { permission }
    func request() async -> Bool {
        requests += 1
        return await withCheckedContinuation { gate = $0 }
    }
    func resolve(_ allowed: Bool) { permission = allowed ? .authorized : .denied; gate?.resume(returning: allowed); gate = nil }
    func waiting() -> Bool { gate != nil }
}

private actor RuntimeStub: AudioRuntime {
    var available = [RuntimeStub.device()]
    var starts: [Int] = []
    var outputStarts: [Int] = []
    var transports: [TransportRequest] = []
    var transportValue: TransportPlaybackSnapshot?
    var stops = 0
    var active = false
    var maximumActive = 0
    var value: CaptureSnapshot?
    var delayStart = false
    var failAfterStarting = false
    var gate: CheckedContinuation<Void, Never>?
    var hardwareChanges: [String] = []
    static func device(rate: Double = 44_100, buffer: UInt32 = 512, pid: Int32 = -1) -> AudioDeviceDescriptor {
        AudioDeviceDescriptor(hardwareID: 42, uid: "usb", name: "Synthetic two-channel interface", inputChannels: 2,
            outputChannels: 2, sampleRate: rate, bufferFrames: buffer, exclusivePID: pid)
    }
    func devices() -> [AudioDeviceDescriptor] { available }
    func capabilities(device: AudioDeviceDescriptor, channel: Int) -> AudioDeviceCapabilities {
        AudioDeviceCapabilities(sampleRates: [44_100...48_000], bufferRange: 64...1024, canSetSampleRate: true, canSetBufferFrames: true, inputGain: nil)
    }
    func startInput(device: AudioDeviceDescriptor, channel: Int) async throws -> AudioStreamFormat {
        if delayStart { delayStart = false; await withCheckedContinuation { gate = $0 } }
        maximumActive = max(maximumActive, active ? 2 : 1)
        active = true; starts.append(channel)
        if failAfterStarting { throw AudioBackendError.system(-50) }
        return AudioStreamFormat(sampleRate: device.sampleRate, inputChannels: UInt32(device.inputChannels))
    }
    func stopInput() { active = false; stops += 1 }
    func readInput() -> CaptureSnapshot? { value }
    func startClick(device: AudioDeviceDescriptor, channel: Int) { outputStarts.append(channel) }
    func stopClick() {}
    func startTransport(device: AudioDeviceDescriptor, channel: Int, request: TransportRequest) async {
        if delayStart { delayStart = false; await withCheckedContinuation { gate = $0 } }
        outputStarts.append(channel); transports.append(request)
        transportValue = TransportPlaybackSnapshot(requestID: request.id, phase: .playing,
            position: TransportPosition(tick: 0, loopIndex: 0, countInBeat: 1, completed: false), sampleRate: device.sampleRate,
            renderedFrames: 0, scheduledStartHostSeconds: 100, renderAnchorHostSeconds: nil, presentationLatency: 0.01)
    }
    func readTransport() -> TransportPlaybackSnapshot? { transportValue }
    func stopTransport() { transportValue = nil }
    func completeTransport() {
        guard let old = transportValue else { return }
        transportValue = TransportPlaybackSnapshot(requestID: old.requestID, phase: .completed,
            position: TransportPosition(tick: 960, loopIndex: 0, countInBeat: nil, completed: true), sampleRate: old.sampleRate,
            renderedFrames: 48000, scheduledStartHostSeconds: 100, renderAnchorHostSeconds: 100, presentationLatency: 0.01)
    }
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) { hardwareChanges.append("rate"); available = [Self.device(rate: rate)] }
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) { hardwareChanges.append("buffer"); available = [Self.device(buffer: frames)] }
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) { hardwareChanges.append("gain") }
    func setDevices(_ values: [AudioDeviceDescriptor]) { available = values }
    func setSnapshot(frames: UInt64, drops: UInt64 = 0, invalid: UInt64 = 0) {
        value = CaptureSnapshot(totalFrames: frames, totalPackets: frames / 512, droppedPackets: drops, peak: 0, rms: 0,
            sampleRate: 44_100, lastHostTime: frames + 1, hostTimeValid: true, invalidSamples: invalid)
    }
    func failNextStart() { failAfterStarting = true }
    func delayNextStart() { delayStart = true }
    func waiting() -> Bool { gate != nil }
    func release() { gate?.resume(); gate = nil }
}

struct AudioCoordinatorTests {
    @Test func repeatSegmentsRetainCaptureButResetOutputClockAndOwnership() async throws {
        let runtime = RuntimeStub(), coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route())
        let capture = UUID()
        try await coordinator.start(purpose: .practice, requestID: capture)
        let first = try preview(mode: .practice)
        try await coordinator.startTransport(first)
        await coordinator.stopTransport(requestID: first.id, keepingCapture: true)
        #expect(await runtime.active)
        #expect(await coordinator.snapshot().captureRequestID == capture)
        #expect(await coordinator.snapshot().transport == nil)
        #expect(await coordinator.snapshot().clock == nil)
        let second = try preview(mode: .practice)
        try await coordinator.startTransport(second)
        await coordinator.stopTransport(requestID: first.id, keepingCapture: true)
        #expect(await coordinator.snapshot().transportRequestID == second.id)
        #expect(await runtime.starts.count == 1)
        await coordinator.stopCapture(requestID: capture)
        #expect(await runtime.active == false)
    }

    @Test func cancelledCaptureLeaseCannotStopANewerCalibration() async throws {
        let runtime = RuntimeStub(), permissions = PermissionStub(.notDetermined)
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: permissions)
        await coordinator.configure(try route())
        let old = UUID(), current = UUID()
        let pending = Task { try await coordinator.start(purpose: .calibration, requestID: old) }
        while !(await permissions.waiting()) { await Task.yield() }
        await coordinator.stopCapture(requestID: old)
        await permissions.resolve(true)
        do { try await pending.value; Issue.record("Cancelled permission start succeeded") }
        catch { #expect(error as? AudioBackendError == .cancelled) }
        try await coordinator.start(purpose: .calibration, requestID: current)
        try await coordinator.startTransport(LoopbackProbe.request())
        await coordinator.stopCapture(requestID: old)
        #expect(await coordinator.snapshot().captureRequestID == current)
        #expect(await coordinator.snapshot().phase == .running)
        await coordinator.stopCapture(requestID: current)
        #expect(await coordinator.snapshot().phase == .idle)
    }

    @Test func outputProbeCannotLeakIntoTunerCapture() async throws {
        let runtime = RuntimeStub(), coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route())
        try await coordinator.startClick()
        await #expect(throws: AudioBackendError.inUse) { try await coordinator.start(purpose: .tuner) }
        #expect(await runtime.starts.isEmpty)
        await coordinator.stopClick()
        try await coordinator.start(purpose: .tuner)
        await coordinator.stop()
    }
    private func preview(mode: TransportMode = .preview) throws -> TransportRequest {
        try TransportRequest(exercise: Exercise(id: "preview", events: [MusicalEvent(id: "e", startTick: 0,
            durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)])]), tuning: .standard, bpm: 60, mode: mode)
    }
    @Test func previewDoesNotRequestCapturePermissionAndCompletesOnChosenOutput() async throws {
        let runtime = RuntimeStub(), permission = PermissionStub(.denied)
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: permission)
        await coordinator.configure(try route())
        let request = try preview(); try await coordinator.startTransport(request)
        await coordinator.refresh(); await coordinator.poll(now: .now.advanced(by: .seconds(10)))
        #expect(await coordinator.snapshot().phase == .running)
        #expect(await runtime.starts.isEmpty)
        #expect(await runtime.outputStarts == [2])
        #expect(await permission.requests == 0)
        await #expect(throws: AudioBackendError.inUse) { try await coordinator.start(purpose: .tuner) }
        await coordinator.stopActivity(.setup)
        #expect(await coordinator.snapshot().purpose == .preview)
        await runtime.completeTransport(); await coordinator.poll()
        #expect(await coordinator.snapshot().phase == .idle)
        #expect(await coordinator.snapshot().transport?.phase == .completed)
    }
    @Test func practiceOutputRequiresPracticeOwnerAndCannotUsePreviewTones() async throws {
        let runtime = RuntimeStub(), coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route())
        await #expect(throws: AudioBackendError.inUse) { try await coordinator.startTransport(preview(mode: .practice)) }
        try await coordinator.start(purpose: .practice)
        await #expect(throws: AudioBackendError.inUse) { try await coordinator.startTransport(preview()) }
        try await coordinator.startTransport(preview(mode: .practice))
        #expect(await runtime.transports.map(\.mode) == [.practice])
        await coordinator.stop()
        #expect(await runtime.transportValue == nil)
        #expect(await runtime.active == false)
    }
    @Test func cancelledPreviewCannotClearTheNextSegmentsBuffers() async throws {
        let runtime = RuntimeStub(), coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route()); await runtime.delayNextStart()
        let first = try preview(), second = try preview()
        let start = Task { try await coordinator.startTransport(first) }
        try await waitFor { await runtime.waiting() }
        let stop = Task { await coordinator.stopTransport(requestID: first.id) }
        try await waitFor { await coordinator.snapshot().purpose == nil }
        let restart = Task { try await coordinator.startTransport(second) }
        await runtime.release()
        await #expect(throws: AudioBackendError.cancelled) { try await start.value }
        await stop.value; try await restart.value
        await coordinator.stopTransport(requestID: first.id)
        #expect(await coordinator.snapshot().transportRequestID == second.id)
        #expect(await runtime.transportValue?.requestID == second.id)
        await coordinator.stop()
    }
    private func route(channel: Int = 2) throws -> AudioRouteSelection {
        try AudioRouteSelection(inputUID: "usb", inputChannel: channel, outputUID: "usb", outputChannel: 2)
    }
    private func waitFor(_ condition: @escaping @Sendable () async -> Bool) async throws {
        for _ in 0..<1000 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Expected asynchronous boundary was not reached")
    }
    @Test func explicitChannelsAndExclusivePurposePreventCompetingCaptures() async throws {
        let runtime = RuntimeStub(), permission = PermissionStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: permission)
        await coordinator.configure(try route())
        try await coordinator.start(purpose: .setup)
        #expect(await runtime.starts == [2])
        await #expect(throws: AudioBackendError.inUse) { try await coordinator.start(purpose: .tuner) }
        try await coordinator.startClick()
        #expect(await runtime.outputStarts == [2])
        await coordinator.stop()
        try await coordinator.start(purpose: .tuner)
        await #expect(throws: AudioBackendError.inUse) { try await coordinator.startClick() }
        await coordinator.stopActivity(.setup)
        #expect(await coordinator.snapshot().phase == .running)
        await coordinator.stop()
        #expect(await runtime.maximumActive == 1)
        #expect(await permission.requests == 0)
    }
    @Test func permissionDenialAndCancellationNeverStartHardware() async throws {
        let runtime = RuntimeStub(), denied = PermissionStub(.denied)
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: denied)
        await coordinator.configure(try route())
        await #expect(throws: AudioBackendError.permissionDenied) { try await coordinator.start(purpose: .setup) }
        #expect(await runtime.starts.isEmpty)
        let pending = PermissionStub(.notDetermined)
        let other = AudioSessionCoordinator(runtime: runtime, permissions: pending)
        await other.configure(try route())
        let start = Task { try await other.start(purpose: .setup) }
        try await waitFor { await pending.waiting() }
        await other.stop()
        await pending.resolve(true)
        await #expect(throws: AudioBackendError.cancelled) { try await start.value }
        #expect(await runtime.starts.isEmpty)
        #expect(await other.snapshot().phase == .idle)
    }
    @Test func cancelledSlowStartCannotStopTheNextStart() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route())
        await runtime.delayNextStart()
        let first = Task { try await coordinator.start(purpose: .setup) }
        try await waitFor { await runtime.waiting() }
        let stop = Task { await coordinator.stop() }
        try await waitFor { await coordinator.snapshot().phase == .idle }
        let second = Task { try await coordinator.start(purpose: .tuner) }
        await runtime.release()
        await #expect(throws: AudioBackendError.cancelled) { try await first.value }
        await stop.value; try await second.value
        #expect(await coordinator.snapshot().phase == .running)
        #expect(await runtime.active)
        #expect(await runtime.maximumActive == 1)
        await coordinator.stop()
    }
    @Test func deviceRemovalAndFormatChangeInterruptWithoutFallbackOrRestart() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route()); try await coordinator.start(purpose: .setup)
        await runtime.setDevices([]); await coordinator.refresh()
        #expect(await coordinator.snapshot().phase == .interrupted(.routeChanged))
        #expect(await coordinator.snapshot().selection.inputUID == "usb")
        await runtime.setDevices([RuntimeStub.device()]); await coordinator.refresh()
        #expect(await coordinator.snapshot().phase == .interrupted(.routeChanged))
        #expect(await runtime.starts == [2])
        try await coordinator.start(purpose: .setup)
        let revision = await coordinator.snapshot().routeRevision
        await runtime.setDevices([RuntimeStub.device(rate: 48_000)]); await coordinator.refresh()
        #expect(await coordinator.snapshot().routeRevision > revision)
        #expect(await coordinator.snapshot().phase == .interrupted(.routeChanged))
        #expect(await runtime.active == false)
    }
    @Test func healthySilenceDiffersFromStallAndDataLoss() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route()); try await coordinator.start(purpose: .setup)
        let now = ContinuousClock.now
        await runtime.setSnapshot(frames: 512); await coordinator.poll(now: now)
        await runtime.setSnapshot(frames: 1024); await coordinator.poll(now: now.advanced(by: .seconds(3)))
        #expect(await coordinator.snapshot().phase == .running)
        await coordinator.poll(now: now.advanced(by: .seconds(6)))
        #expect(await coordinator.snapshot().phase == .interrupted(.streamStalled))
        try await coordinator.start(purpose: .setup)
        await runtime.setSnapshot(frames: 512, drops: 1); await coordinator.poll()
        #expect(await coordinator.snapshot().phase == .interrupted(.dataLoss))
        #expect(await coordinator.snapshot().meters?.droppedPackets == 1)
        try await coordinator.start(purpose: .setup)
        await runtime.setSnapshot(frames: 512, invalid: 1); await coordinator.poll()
        #expect(await coordinator.snapshot().phase == .interrupted(.dataLoss))
    }
    @Test func unsupportedAndBusyDevicesAreRejectedBeforeStarting() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route())
        await runtime.setDevices([RuntimeStub.device(rate: 96_000)])
        await #expect(throws: AudioBackendError.invalidFormat) { try await coordinator.start(purpose: .setup) }
        await runtime.setDevices([RuntimeStub.device(pid: Int32.max)])
        await #expect(throws: AudioBackendError.busyDevice) { try await coordinator.start(purpose: .setup) }
        #expect(await runtime.starts.isEmpty)
    }
    @Test func hardwareChangesStopCaptureAndSleepDoesNotAutoResume() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route()); try await coordinator.start(purpose: .setup)
        try await coordinator.changeSampleRate(48_000)
        #expect(await runtime.active == false)
        #expect(await runtime.hardwareChanges == ["rate"])
        try await coordinator.start(purpose: .tuner)
        await coordinator.suspend(); await coordinator.refresh()
        #expect(await coordinator.snapshot().phase == .interrupted(.suspended))
        #expect(await runtime.active == false)
    }
    @Test func repeatedStartStopKeepsOnePipelineAndChannelChangesStayExplicit() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        for index in 0..<20 {
            await coordinator.configure(try route(channel: index % 2 + 1))
            try await coordinator.start(purpose: .setup)
            await coordinator.stop()
        }
        #expect(await runtime.starts == (0..<20).map { $0 % 2 + 1 })
        #expect(await runtime.maximumActive == 1)
        #expect(await runtime.active == false)
    }

    @Test func partialBackendFailureIsCleanedBeforeAnotherActivity() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route()); await runtime.failNextStart()
        await #expect(throws: AudioBackendError.system(-50)) { try await coordinator.start(purpose: .setup) }
        #expect(await runtime.active == false)
        #expect(await coordinator.snapshot().purpose == nil)
    }
    @Test func selectionChangePreservesItsInterruptionReason() async throws {
        let runtime = RuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PermissionStub())
        await coordinator.configure(try route()); try await coordinator.start(purpose: .setup)
        await coordinator.stop(reason: .routeChanged)
        await coordinator.configure(try route(channel: 1))
        #expect(await coordinator.snapshot().phase == .interrupted(.routeChanged))
        #expect(await coordinator.snapshot().selection.inputChannel == 1)
    }

    @Test func sleepWhileIdleDoesNotInventAnInterruptedCapture() async {
        let coordinator = AudioSessionCoordinator(runtime: RuntimeStub(), permissions: PermissionStub())
        await coordinator.suspend()
        #expect(await coordinator.snapshot().phase == .idle)
    }

}
