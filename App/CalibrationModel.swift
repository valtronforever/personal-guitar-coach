import SwiftUI
import Domain
import Audio

/// Owns one bounded capture lease. No result is saved until both passes agree and the user applies it.
@MainActor @Observable
final class CalibrationModel {
    enum Stage: String { case ready, signal, listening, playing, between, result }
    private(set) var stage: Stage = .ready
    private(set) var running = false
    private(set) var elapsedSeconds = 0.0
    private(set) var messageKey: String?
    private(set) var audioError: AudioBackendError?
    private(set) var candidate: CalibrationProfile?
    private(set) var passNumber = 1
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var captureID: UUID?
    private var firstClockDrift = 0.0
    private var first: PersonalSyncPass?
    private var frozenRoute: CalibrationRoute?
    private var frozenInstrument: InstrumentProfile?
    private var frozenString: Int?
    private var revision: UInt64?
    private var session: UUID?

    func start(audio: AudioSessionStore, store: CalibrationStore, instrument: InstrumentProfile, string: Int) {
        guard !running, store.loaded, !store.busy, let state = audio.state, let route = state.calibrationRoute,
              state.purpose == nil, !state.isClicking, !state.isStartingClick else { return }
        if stage != .between { reset() }
        if first == nil {
            frozenRoute = route; frozenInstrument = instrument; frozenString = string
            revision = state.routeRevision; session = audio.synchronizationSession
        }
        guard route == frozenRoute, instrument == frozenInstrument, string == frozenString,
              state.routeRevision == revision, audio.synchronizationSession == session else {
            reset(); messageKey = "sync.routeChanged"; return
        }
        let id = UUID(); captureID = id; running = true; elapsedSeconds = 0; messageKey = nil; audioError = nil
        candidate = nil; stage = .signal; passNumber = first == nil ? 1 : 2
        task = Task {
            do {
                let frequency = try instrument.tuning.frequency(at: FretPosition(string: string, fret: 0))
                let request = try PersonalSyncProbe.request(instrument: instrument, string: string)
                try await audio.coordinator.start(purpose: .calibration, requestID: id)
                let signalDeadline = ContinuousClock.now.advanced(by: .seconds(20))
                var baseline: AudioAnalysisSnapshot?
                while baseline == nil {
                    let current = try await checkedState(audio: audio, id: id)
                    if PracticePreflightSignal.isReady(current.meters), let pitch = current.meters?.analysis?.latest?.pitch,
                       abs(1200 * log2(pitch.frequency / frequency)) <= 50 {
                        baseline = current.meters?.analysis
                    } else if ContinuousClock.now >= signalDeadline { throw CalibrationError.insufficientEvidence }
                    if baseline == nil { try await Task.sleep(for: .milliseconds(50)) }
                }
                try await audio.coordinator.startTransport(request)
                stage = .listening
                var events: [DetectedNoteEvent] = [], lastEvent = baseline!.totalEvents, lastSpan = baseline!.totalQualitySpans
                var epoch: Double?, completedAt: ContinuousClock.Instant?
                var drift = 0.0
                var hadClock = false
                let deadline = ContinuousClock.now.advanced(by: .seconds(40))
                while true {
                    let current = try await checkedState(audio: audio, id: id)
                    guard ContinuousClock.now < deadline else { throw AudioBackendError.streamStalled }
                    if let analysis = current.meters?.analysis {
                        let newEvents = analysis.events.filter { $0.id > lastEvent }
                        let spans = analysis.qualitySpans.filter { $0.id > lastSpan }
                        guard analysis.invalidSamples == 0, analysis.totalEvents >= lastEvent, analysis.totalQualitySpans >= lastSpan,
                              analysis.totalEvents - lastEvent == UInt64(newEvents.count),
                              analysis.totalQualitySpans - lastSpan == UInt64(spans.count), events.count + newEvents.count <= 128,
                              !spans.contains(where: { $0.quality == .clipping || $0.quality == .invalid }) else {
                            throw CalibrationError.insufficientEvidence
                        }
                        events += newEvents; lastEvent = analysis.totalEvents; lastSpan = analysis.totalQualitySpans
                    }
                    guard let playback = current.transport, playback.requestID == request.id else { throw AudioBackendError.invalidFormat }
                    if epoch == nil { epoch = playback.renderAnchorHostSeconds }
                    elapsedSeconds = max(0, Double(playback.renderedFrames) / playback.sampleRate - (route.output.hardwareLatencySeconds ?? playback.presentationLatency))
                    if elapsedSeconds >= 4 { stage = .playing }
                    if playback.phase == .completed, completedAt == nil { completedAt = .now }
                    if let value = current.clock?.validatedDriftSeconds { drift = max(drift, abs(value)); hadClock = true }
                    else if hadClock { throw CalibrationError.insufficientEvidence }
                    if let completedAt, completedAt.duration(to: .now) >= .seconds(1.8 + (route.input.hardwareLatencySeconds ?? 0) + (route.output.hardwareLatencySeconds ?? 0)) {
                        guard let epoch, current.clock?.validatedDriftSeconds != nil, drift <= 0.02 else { throw CalibrationError.insufficientEvidence }
                        let expected = try (4..<20).map { try route.expectedTime(renderEpochSeconds: epoch, sampleFrame: Int64(Double($0) * route.output.sampleRate)) }
                        var observed: [Double] = []
                        for event in events {
                            guard let host = event.onset.hostSeconds else { throw CalibrationError.insufficientEvidence }
                            let time = try route.observedTime(inputHostSeconds: host)
                            if time >= expected[0] - 0.45 && time <= expected[15] + 0.45 {
                                guard event.quality == .reliable, let pitch = event.pitch, pitch.clarity >= 0.9,
                                      pitch.frequency.isFinite, abs(1200 * log2(pitch.frequency / frequency)) <= 50 else {
                                    throw CalibrationError.insufficientEvidence
                                }
                            }
                            observed.append(time)
                        }
                        let pass = try PersonalSyncPass(expected: expected, observed: observed)
                        if let first {
                            let evidence = try PersonalSyncEvidence(instrument: instrument, string: string,
                                offsets: [first.offset, pass.offset], spreads: [first.spread, pass.spread], drifts: [first.drift, pass.drift])
                            candidate = try CalibrationProfile(route: route, method: .personal, residualOffsetSeconds: evidence.offset,
                                uncertaintySeconds: evidence.uncertainty + max(firstClockDrift, drift), personalEvidence: evidence)
                            stage = .result
                        } else { first = pass; firstClockDrift = drift; stage = .between }
                        break
                    }
                    try await Task.sleep(for: .milliseconds(50))
                }
            } catch is CancellationError { reset(); messageKey = "sync.cancelled" }
            catch {
                reset(); messageKey = "sync.failed"
                audioError = error as? AudioBackendError
            }
            await audio.stopCapture(id: id)
            if captureID == id { captureID = nil; running = false; task = nil }
        }
    }
    private func checkedState(audio: AudioSessionStore, id: UUID) async throws -> AudioCoordinatorSnapshot {
        try Task.checkCancellation()
        await audio.coordinator.poll(); await audio.publish()
        try Task.checkCancellation()
        guard let state = audio.state, state.captureRequestID == id, state.phase == .running,
              state.calibrationRoute == frozenRoute, state.routeRevision == revision,
              audio.synchronizationSession == session else { throw AudioBackendError.routeChanged }
        if let meters = state.meters, meters.totalFrames > 0 {
            guard meters.hostTimeValid, meters.droppedPackets == 0, meters.discontinuities == 0,
                  meters.invalidSamples == 0, meters.peak < 0.995 else { throw CalibrationError.insufficientEvidence }
        }
        return state
    }
    func apply(audio: AudioSessionStore, store: CalibrationStore, instrument: InstrumentProfile) async {
        guard !running, let candidate, let revision, let session,
              candidate.route == audio.state?.calibrationRoute, revision == audio.state?.routeRevision,
              session == audio.synchronizationSession, frozenInstrument == instrument else {
            reset(); messageKey = "sync.routeChanged"; return
        }
        if await store.save(candidate) {
            // Save may suspend: a changed route never becomes eligible through a stale receipt.
            store.confirm(candidate, session: session, revision: revision)
            messageKey = "calibration.saved"
        } else { messageKey = "calibration.storageSave" }
    }
    func cancel(audio: AudioSessionStore) {
        task?.cancel()
        if let id = captureID { Task { await audio.stopCapture(id: id) } }
        else { reset() }
    }
    private func reset() {
        first = nil; firstClockDrift = 0; candidate = nil; frozenRoute = nil; frozenInstrument = nil; frozenString = nil
        messageKey = nil; audioError = nil
        revision = nil; session = nil; stage = .ready; passNumber = 1; elapsedSeconds = 0
    }
}
