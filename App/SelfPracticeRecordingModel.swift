import Foundation
import Observation
import Audio
import Domain

@MainActor @Observable final class SelfPracticeRecordingModel {
    enum Phase: String { case idle, preparing, recording, draining, review, failed }
    private(set) var phase = Phase.idle
    private(set) var snapshot: AudioCoordinatorSnapshot?
    private(set) var displayTick: Double?
    private(set) var take: SelfPracticeTake?
    private(set) var savedURL: URL?
    private(set) var backendError: AudioBackendError?
    private(set) var errorKey: String?
    private(set) var saving = false
    @ObservationIgnored private var task: Task<Void,Never>?
    @ObservationIgnored private var exportTask: Task<Void,Error>?
    private var captureID: UUID?
    @ObservationIgnored private var coordinator: AudioSessionCoordinator?
    @ObservationIgnored private var wantsStop = false
    var isBusy: Bool { captureID != nil }

    func start(context: SelfPracticeRecordingContext, bpm: Double, coordinator: AudioSessionCoordinator, outputAlignment: OutputAlignmentProfile?) {
        guard !isBusy, !saving else { return }
        let transport: TransportRequest
        do { transport = try context.transport(bpm: bpm) }
        catch { errorKey = "selfRecording.tooLong"; return }
        self.coordinator = coordinator
        let id = UUID(); captureID = id; wantsStop = false; phase = .preparing
        errorKey = nil; backendError = nil; take = nil; savedURL = nil; snapshot = nil; displayTick = nil
        task = Task {
            do {
                try Task.checkCancellation()
                try await coordinator.start(purpose: .practice, requestID: id)
                try Task.checkCancellation()
                let initial = await coordinator.snapshot()
                guard initial.captureRequestID == id, initial.phase == .running else { throw AudioBackendError.cancelled }
                let capturedAt = Date()
                try await coordinator.beginRecording(requestID: id)
                let deadline = ContinuousClock.now.advanced(by: .seconds(145))
                try await coordinator.startTransport(transport)
                var completedAt: ContinuousClock.Instant?, epoch: Double?, finalState: AudioCoordinatorSnapshot?
                var completed = false
                var displayPlan: TransportPlan?
                while true {
                    try Task.checkCancellation()
                    guard ContinuousClock.now < deadline else { throw AudioBackendError.streamStalled }
                    await coordinator.poll()
                    let state = await coordinator.snapshot(); snapshot = state
                    if case let .interrupted(error) = state.phase { throw error }
                    if case let .failed(error) = state.phase { throw error }
                    guard state.phase == .running, state.captureRequestID == id,
                          state.routeRevision == initial.routeRevision, state.selection == initial.selection,
                          let playback = state.transport, playback.requestID == transport.id else { throw AudioBackendError.routeChanged }
                    if let anchor = playback.renderAnchorHostSeconds { epoch = anchor }
                    let alignment = outputAlignment?.output == state.outputEndpoint ? outputAlignment : nil
                    let reported = state.outputEndpoint?.hardwareLatencySeconds ?? (alignment == nil ? playback.presentationLatency : 0)
                    if displayPlan == nil { displayPlan = try TransportPlan(request: transport, sampleRate: playback.sampleRate) }
                    displayTick = displayPlan?.audibleTimelineTick(renderedFrames: playback.renderedFrames,
                        outputLatencySeconds: reported, visualAlignmentSeconds: alignment?.seconds ?? 0)
                    if epoch != nil && phase == .preparing { phase = .recording }
                    if wantsStop, epoch != nil { finalState = state; break }
                    if playback.phase == .completed {
                        if completedAt == nil { completedAt = .now; phase = .draining }
                        let tail = 2 + (state.calibrationRoute?.input.hardwareLatencySeconds ?? 0) + max(0,reported) + max(0,alignment?.seconds ?? 0)
                        guard tail.isFinite, tail <= 12 else { throw AudioBackendError.invalidFormat }
                        if let completedAt, completedAt.duration(to: .now) >= .seconds(tail), epoch != nil {
                            completed = true; finalState = state; break
                        }
                    }
                    try await Task.sleep(for: .milliseconds(50))
                }
                guard let epoch, let finalState else { throw AudioBackendError.invalidFormat }
                let recording = try await coordinator.endRecording(requestID: id)
                try Task.checkCancellation()
                let result = try SelfPracticeTake(context: context, recording: recording, transport: transport,
                    epoch: epoch, route: finalState, outputAlignment: outputAlignment?.output == finalState.outputEndpoint ? outputAlignment : nil,
                    completed: completed, capturedAt: capturedAt)
                if captureID == id { take = result; phase = .review }
            } catch {
                if captureID == id {
                    if error is CancellationError || error as? AudioBackendError == .cancelled { phase = .idle }
                    else { phase = .failed; backendError = error as? AudioBackendError; errorKey = "selfRecording.failed" }
                }
            }
            await coordinator.stopCapture(requestID: id)
            if captureID == id { captureID = nil; task = nil; displayTick = nil }
        }
    }
    func stopAndReview() { if phase == .recording || phase == .draining { wantsStop = true } }
    func cancel() {
        task?.cancel(); exportTask?.cancel()
        // The coordinator's request guard prevents this sheet from stopping a later owner.
        if let captureID, let coordinator { Task { await coordinator.stopCapture(requestID: captureID) } }
    }
    func save(to url: URL) async {
        guard !isBusy, !saving, let take else { return }
        saving = true; errorKey = nil
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() }; saving = false; exportTask = nil }
        let worker = Task.detached { try take.export(to: url) }; exportTask = worker
        do { try await worker.value; savedURL = url }
        catch { if !(error is CancellationError) { errorKey = "selfRecording.saveFailed" } }
    }
}
