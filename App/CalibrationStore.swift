import SwiftUI
import Domain
import Audio
import Persistence

@MainActor @Observable
final class CalibrationStore {
    @ObservationIgnored private let repository: (any CalibrationRepository)?
    private(set) var profiles: [CalibrationProfile] = []
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var errorKey: String?
    init(repository: (any CalibrationRepository)?) { self.repository = repository }
    func profile(for route: CalibrationRoute?) -> CalibrationProfile? {
        guard let route else { return nil }
        return profiles.first { $0.route == route }
    }
    func load() async {
        guard !busy, !loaded else { return }
        busy = true; defer { busy = false }
        do {
            guard let repository else { throw StorageError.corruptDocument }
            profiles = try await repository.loadCalibrationProfiles(); loaded = true; errorKey = nil
        } catch { errorKey = "calibration.storageLoad" }
    }
    @discardableResult func save(_ value: CalibrationProfile) async -> Bool {
        guard loaded, !busy, let repository else { return false }
        busy = true; defer { busy = false }
        do {
            try await repository.saveCalibration(value, replacing: profile(for: value.route)?.id)
            profiles.removeAll { $0.route == value.route }; profiles.append(value); errorKey = nil
            return true
        } catch { errorKey = "calibration.storageSave"; return false }
    }
    func forget(_ value: CalibrationProfile) async {
        guard loaded, !busy, let repository else { return }
        busy = true; defer { busy = false }
        do { try await repository.removeCalibration(id: value.id); profiles.removeAll { $0.id == value.id }; errorKey = nil }
        catch { errorKey = "calibration.storageSave" }
    }
}

@MainActor @Observable
final class CalibrationModel {
    private(set) var running = false
    private(set) var elapsedSeconds = 0.0
    private(set) var messageKey: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var captureID: UUID?

    func start(audio: AudioSessionStore, store: CalibrationStore, long: Bool) {
        guard !running, store.loaded, !store.busy, let route = audio.state?.calibrationRoute else { return }
        let id = UUID(); captureID = id; running = true; elapsedSeconds = 0; messageKey = nil
        task = Task {
            do {
                let request = try LoopbackProbe.request(long: long)
                try await audio.coordinator.start(purpose: .calibration, requestID: id)
                try Task.checkCancellation()
                try await audio.coordinator.startTransport(request)
                var onsets: [Double] = [], lastEvent: UInt64 = 0, lastSpan: UInt64 = 0
                var epoch: Double?, completedAt: ContinuousClock.Instant?
                var drift = 0.0
                let startedAt = ContinuousClock.now
                while true {
                    try Task.checkCancellation()
                    guard startedAt.duration(to: .now) < .seconds(long ? 920 : 45) else { throw CalibrationError.insufficientEvidence }
                    let state = await audio.coordinator.snapshot()
                    guard state.captureRequestID == id, state.phase == .running, state.calibrationRoute == route else {
                        throw CalibrationError.insufficientEvidence
                    }
                    if let analysis = state.meters?.analysis {
                        let newEvents = analysis.events.filter { $0.id > lastEvent }
                        let newSpans = analysis.qualitySpans.filter { $0.id > lastSpan }
                        guard analysis.invalidSamples == 0, analysis.totalEvents >= lastEvent, analysis.totalQualitySpans >= lastSpan,
                              analysis.totalEvents - lastEvent == UInt64(newEvents.count),
                              analysis.totalQualitySpans - lastSpan == UInt64(newSpans.count),
                              !newSpans.contains(where: { $0.quality == .clipping || $0.quality == .invalid }) else {
                            throw CalibrationError.insufficientEvidence
                        }
                        for event in newEvents {
                            guard let host = event.onset.hostSeconds, onsets.count < 512 else { throw CalibrationError.insufficientEvidence }
                            onsets.append(try route.observedTime(inputHostSeconds: host))
                        }
                        lastEvent = analysis.totalEvents; lastSpan = analysis.totalQualitySpans
                    }
                    if let playback = state.transport, playback.requestID == request.id {
                        if epoch == nil { epoch = playback.renderAnchorHostSeconds }
                        elapsedSeconds = Double(playback.renderedFrames) / playback.sampleRate
                        if playback.phase == .completed, completedAt == nil { completedAt = .now }
                    }
                    if let clock = state.clock?.validatedDriftSeconds { drift = max(drift, abs(clock)) }
                    if let completedAt, completedAt.duration(to: .now) >= .seconds(1.4 + (route.input.hardwareLatencySeconds ?? 0)) {
                        guard let epoch, state.clock?.validatedDriftSeconds != nil else { throw CalibrationError.insufficientEvidence }
                        let expected = try request.exercise.events.map {
                            try route.expectedTime(renderEpochSeconds: epoch, sampleFrame: Int64((Double($0.startTick) / 960 * route.output.sampleRate).rounded()))
                        }
                        let observed = onsets
                        let estimate = try await Task.detached { try LoopbackEstimator.estimate(expected: expected, observed: observed) }.value
                        try Task.checkCancellation()
                        let finalState = await audio.coordinator.snapshot()
                        guard finalState.captureRequestID == id, finalState.phase == .running, finalState.calibrationRoute == route else {
                            throw CalibrationError.insufficientEvidence
                        }
                        let profile = try CalibrationProfile(route: route, method: .measured,
                            residualOffsetSeconds: estimate.residualOffsetSeconds,
                            uncertaintySeconds: estimate.uncertaintySeconds + drift, evidence: estimate.evidence)
                        await audio.stopCapture(id: id)
                        try Task.checkCancellation()
                        messageKey = await store.save(profile) ? "calibration.saved" : "calibration.storageSave"
                        break
                    }
                    try await Task.sleep(for: .milliseconds(50))
                }
            } catch is CancellationError { }
            catch { if !Task.isCancelled { messageKey = "calibration.failed" } }
            await audio.stopCapture(id: id)
            if captureID == id { captureID = nil; running = false; task = nil }
        }
    }

    func cancel(audio: AudioSessionStore) {
        task?.cancel()
        if let id = captureID { Task { await audio.stopCapture(id: id) } }
        // Keep the lease until its task has completed; a second run cannot overlap its cleanup.
    }
}
