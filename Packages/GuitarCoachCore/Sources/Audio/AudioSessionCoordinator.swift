import Foundation
import Domain

public enum AudioPurpose: String, Sendable { case setup, tuner, practice, calibration, preview }
public enum AudioSessionPhase: Equatable, Sendable {
    case idle, requestingPermission, starting, running
    case interrupted(AudioBackendError), failed(AudioBackendError)
    public var isStarting: Bool { self == .starting || self == .requestingPermission }
}
public struct AudioCoordinatorSnapshot: Sendable, Equatable {
    public let selection: AudioRouteSelection
    public let devices: [AudioDeviceDescriptor]
    public let capabilities: AudioDeviceCapabilities?
    public let permission: AudioPermissionStatus
    public let phase: AudioSessionPhase
    public let purpose: AudioPurpose?
    public let meters: CaptureSnapshot?
    public let isClicking: Bool
    public let isStartingClick: Bool
    public let transportRequestID: UUID?
    public let transport: TransportPlaybackSnapshot?
    public let routeRevision: UInt64
}

/// The sole owner of input and click lifetimes. Permission awaits do not hold the hardware queue.
/// Hardware mutations execute in order, so a cancelled start cannot stop a later successful start.
public actor AudioSessionCoordinator {
    private let runtime: any AudioRuntime
    private let permissions: any AudioPermissionProviding
    private var operationTail: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var clickGeneration: UInt64 = 0
    private var refreshGeneration: UInt64 = 0
    private var selection = AudioRouteSelection.unselected
    private var devices: [AudioDeviceDescriptor] = []
    private var capabilities: AudioDeviceCapabilities?
    private var permission: AudioPermissionStatus = .notDetermined
    private var phase: AudioSessionPhase = .idle
    private var purpose: AudioPurpose?
    private var meters: CaptureSnapshot?
    private var activeInput: AudioDeviceDescriptor?
    private var activeOutput: AudioDeviceDescriptor?
    private var isClicking = false
    private var isStartingClick = false
    private var routeRevision: UInt64 = 0
    private var lastFrameTime: ContinuousClock.Instant?
    private var lastFrameCount: UInt64 = 0
    private var isReading = false
    private var transportRequestID: UUID?
    private var transport: TransportPlaybackSnapshot?

    public init(runtime: any AudioRuntime = LiveAudioRuntime(), permissions: any AudioPermissionProviding = SystemAudioPermission()) {
        self.runtime = runtime; self.permissions = permissions
    }

    public func snapshot() -> AudioCoordinatorSnapshot {
        AudioCoordinatorSnapshot(selection: selection, devices: devices, capabilities: capabilities, permission: permission,
            phase: phase, purpose: purpose, meters: meters, isClicking: isClicking,
            isStartingClick: isStartingClick, transportRequestID: transportRequestID, transport: transport, routeRevision: routeRevision)
    }

    public func configure(_ next: AudioRouteSelection) async {
        guard selection != next else { return }
        selection = next; capabilities = nil; routeRevision &+= 1
        let reason: AudioBackendError?
        if phase == .running || phase.isStarting || isClicking { reason = .routeChanged }
        else if case let .interrupted(existing) = phase { reason = existing }
        else { reason = nil }
        await stop(reason: reason)
        await refresh()
    }

    /// Never substitutes another UID when a selected device disappears.
    public func refresh() async {
        refreshGeneration &+= 1
        let ticket = refreshGeneration
        let selected = selection
        do {
            let found = try await runtime.devices()
            let authorization = await permissions.status()
            guard ticket == refreshGeneration, selected == selection else { return }
            let previousInput = devices.first { $0.uid == selected.inputUID }
            let previousOutput = devices.first { $0.uid == selected.outputUID }
            if streamChanged(previousInput, found.first { $0.uid == selected.inputUID }) ||
               streamChanged(previousOutput, found.first { $0.uid == selected.outputUID }) { routeRevision &+= 1 }
            devices = found; permission = authorization
            if let input = found.first(where: { $0.uid == selected.inputUID }) {
                let value = try await runtime.capabilities(device: input, channel: selected.inputChannel)
                guard ticket == refreshGeneration, selected == selection else { return }
                capabilities = value
            } else { capabilities = nil }
            if let activeInput, !found.contains(where: { sameStream($0, activeInput) && $0.isAlive }) {
                await stop(reason: .routeChanged)
            } else if let activeOutput, !found.contains(where: { sameStream($0, activeOutput) && $0.isAlive }) {
                await stop(reason: .routeChanged)
            } else if activeInput != nil && phase == .running && authorization != .authorized {
                await stop(reason: .permissionDenied)
            }
        } catch {
            if ticket == refreshGeneration {
                if phase == .running || isClicking { await stop(reason: .unavailableDevice) }
                else if !phase.isStarting { phase = .failed(Self.backendError(error)) }
            }
        }
    }

    public func start(purpose requested: AudioPurpose) async throws {
        guard requested != .preview else { throw AudioBackendError.invalidFormat }
        guard purpose == nil, !phase.isStarting, !isStartingClick, !isClicking || requested == .setup else { throw AudioBackendError.inUse }
        generation &+= 1
        let ticket = generation, route = selection
        purpose = requested; phase = .requestingPermission; meters = nil
        do {
            permission = await permissions.status()
            if permission == .notDetermined {
                _ = await permissions.request()
                guard ticket == generation else { throw AudioBackendError.cancelled }
                permission = await permissions.status()
            }
            guard ticket == generation else { throw AudioBackendError.cancelled }
            guard permission == .authorized else { throw AudioBackendError.permissionDenied }
            let found = try await runtime.devices()
            guard ticket == generation else { throw AudioBackendError.cancelled }
            let device = try Self.input(for: route, in: found)
            phase = .starting
            let runtime = runtime
            let operation = enqueue { [weak self] in
                guard await self?.isCurrent(ticket) == true else { throw AudioBackendError.cancelled }
                await runtime.stopInput()
                do {
                    let actual = try await runtime.startInput(device: device, channel: route.inputChannel)
                    guard actual.sampleRate == device.sampleRate, actual.inputChannels == device.inputChannels else { throw AudioBackendError.invalidFormat }
                    return actual
                } catch { await runtime.stopInput(); throw error }
            }
            _ = try await operation.value
            guard ticket == generation else { throw AudioBackendError.cancelled }
            devices = found; activeInput = device; phase = .running
            lastFrameTime = .now; lastFrameCount = 0
        } catch {
            if ticket == generation { phase = .failed(Self.backendError(error)); purpose = nil; activeInput = nil }
            throw Self.backendError(error)
        }
    }

    public func suspend() async {
        guard phase == .running || phase.isStarting || isClicking || isStartingClick else { return }
        await stop(reason: .suspended)
    }

    /// A disappearing feature may only stop the activity it owns.
    public func stopActivity(_ expected: AudioPurpose) async {
        guard purpose == expected || (expected == .setup && purpose == nil) else { return }
        await stop()
    }

    public func stop(reason: AudioBackendError? = nil) async {
        generation &+= 1; clickGeneration &+= 1
        phase = reason.map(AudioSessionPhase.interrupted) ?? .idle
        purpose = nil; activeInput = nil; activeOutput = nil; transportRequestID = nil
        if reason == nil { meters = nil; transport = nil }
        isClicking = false; isStartingClick = false; lastFrameTime = nil; lastFrameCount = 0
        let runtime = runtime
        let operation = enqueue { await runtime.stopInput(); await runtime.stopClick(); await runtime.stopTransport() }
        _ = try? await operation.value
    }

    /// Silence has healthy arriving frames. A stalled stream or dropped data is an interruption.
    public func poll(now: ContinuousClock.Instant = .now) async {
        guard phase == .running, !isReading else { return }
        isReading = true
        defer { isReading = false }
        let ticket = generation
        if purpose != .preview {
            let value = await runtime.readInput()
            guard ticket == generation, phase == .running else { return }
            if let value {
                meters = value
                if value.droppedPackets > 0 || value.invalidSamples > 0 || value.discontinuities > 0 { await stop(reason: .dataLoss); return }
                if value.totalFrames > lastFrameCount { lastFrameCount = value.totalFrames; lastFrameTime = now }
                if value.totalFrames > 0 && (!value.hostTimeValid || value.sampleRate != activeInput?.sampleRate) {
                    await stop(reason: .invalidFormat); return
                }
            }
            if let lastFrameTime, lastFrameTime.duration(to: now) > .seconds(2) { await stop(reason: .streamStalled); return }
        }
        if activeOutput != nil, !isClicking {
            let value = await runtime.readTransport()
            guard ticket == generation, phase == .running else { return }
            if let value {
                transport = value
                switch value.phase {
                case let .interrupted(error): await stop(reason: error)
                case .completed where purpose == .preview:
                    await stop(); transport = value
                default: break
                }
            }
        }
    }

    /// Preview is output-only and requires no microphone permission. Practice keeps its existing capture owner.
    public func startTransport(_ request: TransportRequest) async throws {
        let preview = request.mode == .preview
        guard !isClicking, !isStartingClick, activeOutput == nil,
              preview ? (purpose == nil && !phase.isStarting) : (purpose == .practice && phase == .running) else {
            throw AudioBackendError.inUse
        }
        if preview { generation &+= 1; purpose = .preview; phase = .starting; meters = nil }
        clickGeneration &+= 1
        let ticket = generation, outputTicket = clickGeneration, route = selection, runtime = runtime
        isStartingClick = true; transport = nil; transportRequestID = request.id
        do {
            let found = try await runtime.devices()
            guard isCurrent(ticket, output: outputTicket) else { throw AudioBackendError.cancelled }
            let device = try Self.output(for: route, in: found)
            try await enqueue { [weak self] in
                guard await self?.isCurrent(ticket, output: outputTicket) == true else { throw AudioBackendError.cancelled }
                do { try await runtime.startTransport(device: device, channel: route.outputChannel, request: request) }
                catch { await runtime.stopTransport(); throw error }
            }.value
            guard isCurrent(ticket, output: outputTicket) else { throw AudioBackendError.cancelled }
            devices = found; activeOutput = device; isStartingClick = false; phase = .running
            let value = await runtime.readTransport()
            if isCurrent(ticket, output: outputTicket) { transport = value }
        } catch {
            if isCurrent(ticket, output: outputTicket) { await stop(reason: Self.backendError(error)) }
            throw Self.backendError(error)
        }
    }

    public func stopTransport(requestID: UUID) async {
        guard transportRequestID == requestID else { return }
        await stop()
    }

    public func startClick() async throws {
        guard purpose == nil || purpose == .setup, !phase.isStarting, !isStartingClick, !isClicking else { throw AudioBackendError.inUse }
        clickGeneration &+= 1
        let ticket = generation, outputTicket = clickGeneration, route = selection
        isStartingClick = true
        do {
            let found = try await runtime.devices()
            guard ticket == generation, outputTicket == clickGeneration else { throw AudioBackendError.cancelled }
            let device = try Self.output(for: route, in: found)
            let runtime = runtime
            let operation = enqueue { [weak self] in
                guard await self?.isCurrent(ticket, output: outputTicket) == true else { throw AudioBackendError.cancelled }
                do { try await runtime.startClick(device: device, channel: route.outputChannel) }
                catch { await runtime.stopClick(); throw error }
            }
            try await operation.value
            guard ticket == generation, outputTicket == clickGeneration else { throw AudioBackendError.cancelled }
            activeOutput = device; isClicking = true; isStartingClick = false
        } catch {
            if ticket == generation, outputTicket == clickGeneration { isStartingClick = false }
            throw Self.backendError(error)
        }
    }

    public func stopClick() async {
        guard purpose == nil || purpose == .setup else { return }
        clickGeneration &+= 1; isClicking = false; isStartingClick = false; activeOutput = nil
        let runtime = runtime
        _ = try? await enqueue { await runtime.stopClick() }.value
    }

    public func changeSampleRate(_ rate: Double) async throws {
        try await changeHardware { runtime, device in try await runtime.setSampleRate(rate, device: device) }
    }
    public func changeBufferFrames(_ frames: UInt32) async throws {
        try await changeHardware { runtime, device in try await runtime.setBufferFrames(frames, device: device) }
    }
    public func changeInputGain(_ value: Float, element: UInt32) async throws {
        try await changeHardware { runtime, device in try await runtime.setInputGain(value, device: device, element: element) }
    }
    private func changeHardware(_ operation: @escaping @Sendable (any AudioRuntime, AudioDeviceDescriptor) async throws -> Void) async throws {
        await stop(reason: .routeChanged)
        let ticket = generation, route = selection, runtime = runtime
        let found = try await runtime.devices()
        guard ticket == generation else { throw AudioBackendError.cancelled }
        // Format changes may repair an unsupported rate, so validate availability/channel without rate restriction.
        let device = try Self.input(for: route, in: found, validateRate: false)
        try await enqueue { [weak self] in
            guard await self?.isCurrent(ticket) == true else { throw AudioBackendError.cancelled }
            try await operation(runtime, device)
        }.value
        routeRevision &+= 1
        await refresh()
    }

    private func isCurrent(_ ticket: UInt64, output: UInt64? = nil) -> Bool {
        ticket == generation && (output == nil || output == clickGeneration)
    }
    private func enqueue<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) -> Task<T, Error> {
        let previous = operationTail
        let task = Task { await previous?.value; return try await operation() }
        operationTail = Task { _ = try? await task.value }
        return task
    }
    private func streamChanged(_ before: AudioDeviceDescriptor?, _ after: AudioDeviceDescriptor?) -> Bool {
        switch (before, after) {
        case (nil, nil): false
        case let (before?, after?): !sameStream(before, after) || before.isAlive != after.isAlive
        default: true
        }
    }
    private func sameStream(_ lhs: AudioDeviceDescriptor, _ rhs: AudioDeviceDescriptor) -> Bool {
        lhs.uid == rhs.uid && lhs.hardwareID == rhs.hardwareID && lhs.inputChannels == rhs.inputChannels &&
        lhs.outputChannels == rhs.outputChannels && lhs.sampleRate == rhs.sampleRate && lhs.bufferFrames == rhs.bufferFrames
    }
    private static func input(for route: AudioRouteSelection, in devices: [AudioDeviceDescriptor], validateRate: Bool = true) throws -> AudioDeviceDescriptor {
        guard let device = devices.first(where: { $0.uid == route.inputUID }), device.isAlive else { throw AudioBackendError.unavailableDevice }
        guard route.inputChannel <= device.inputChannels else { throw AudioBackendError.invalidChannel }
        guard device.exclusivePID == -1 || device.exclusivePID == ProcessInfo.processInfo.processIdentifier else { throw AudioBackendError.busyDevice }
        if validateRate { guard MonophonicCapability.sampleRates.contains(device.sampleRate), (1...8192).contains(device.bufferFrames) else { throw AudioBackendError.invalidFormat } }
        return device
    }
    private static func output(for route: AudioRouteSelection, in devices: [AudioDeviceDescriptor]) throws -> AudioDeviceDescriptor {
        guard let device = devices.first(where: { $0.uid == route.outputUID }), device.isAlive else { throw AudioBackendError.unavailableDevice }
        guard route.outputChannel <= device.outputChannels else { throw AudioBackendError.invalidChannel }
        guard device.exclusivePID == -1 || device.exclusivePID == ProcessInfo.processInfo.processIdentifier else { throw AudioBackendError.busyDevice }
        return device
    }
    private static func backendError(_ error: Error) -> AudioBackendError { error as? AudioBackendError ?? .unavailableDevice }
}
