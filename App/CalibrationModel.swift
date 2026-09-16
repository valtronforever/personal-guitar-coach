import SwiftUI
import Domain
import Audio

/// Independent output-only taps or guitar capture. Only Apply persists a valid combined compensation.
@MainActor @Observable
final class CalibrationModel {
    enum Stage: String { case ready, signal, listening, playing, result }
    private(set) var stage: Stage = .ready
    private(set) var running = false
    private(set) var elapsedSeconds = 0.0
    private(set) var messageKey: String?
    private(set) var audioError: AudioBackendError?
    private(set) var candidate: CalibrationProfile?
    private(set) var passNumber = 1
    private(set) var diagnostics: CalibrationDiagnostics?
    private(set) var failure: CalibrationFailure?
    private(set) var timelines: [SyncTimelineRun] = []
    private(set) var routeDescription = ""
    private(set) var targetDescription = ""
    private(set) var source: SyncTimelineRun.Source = .guitar
    private(set) var outputCandidate: OutputAlignmentProfile?
    private var outputSetting: OutputAlignmentProfile?
    private var frozenOutput: CalibrationEndpoint?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var captureID: UUID?
    @ObservationIgnored private var transportID: UUID?
    private var frozenRoute: CalibrationRoute?
    private var frozenInstrument: InstrumentProfile?
    private var frozenString: Int?
    private var revision: UInt64?
    private var session: UUID?
    private var invalidated = false
    private var inputFailure: CalibrationFailure?
    var canTap: Bool { running && source == .taps && (stage == .listening || stage == .playing) }

    func start(audio: AudioSessionStore, store: CalibrationStore, instrument: InstrumentProfile, string: Int, source: SyncTimelineRun.Source = .guitar) {
        guard !running, store.loaded, !store.busy, let state = audio.state, let output = state.outputEndpoint,
              source == .taps || state.calibrationRoute != nil,
              state.purpose == nil, !state.isClicking, !state.isStartingClick else { return }
        reset(); self.source = source
        frozenRoute = state.calibrationRoute; frozenOutput = output; frozenInstrument = instrument; frozenString = string
        revision = state.routeRevision; session = audio.synchronizationSession
        outputSetting = store.outputProfile(for: output)
        routeDescription = (audio.selectedInput?.name ?? "—") + " → " + (audio.selectedOutput?.name ?? "—")
        targetDescription = (try? instrument.tuning.pitch(at: FretPosition(string: string, fret: 0)).name()) ?? "—"
        let guitar = source == .guitar
        running = true; invalidated = false; inputFailure = nil; elapsedSeconds = 0; messageKey = nil; audioError = nil; failure = nil
        candidate = nil; outputCandidate = nil; diagnostics = nil; passNumber = guitar ? 2 : 1
        stage = guitar ? .signal : .listening
        timelines.removeAll { $0.source == source }
        timelines.append(SyncTimelineRun(source: source, alignment: guitar ? outputSetting?.seconds ?? 0 : 0))
        timelines[timelines.count - 1].context = routeDescription + (guitar ? " · " + targetDescription : "")
        task = Task {
            do {
                try Task.checkCancellation()
                if guitar { try await runGuitar(audio: audio, instrument: instrument, string: string, route: frozenRoute!) }
                else { try await runTaps(audio: audio, instrument: instrument, string: string, output: output) }
                finishTimeline(.completed)
            } catch {
                candidate = nil; outputCandidate = nil
                let cancelled = inputFailure == nil && (error is CancellationError || (error as? AudioBackendError) == .cancelled)
                finishTimeline(invalidated ? .stale : (cancelled ? .cancelled : .failed))
                if invalidated { messageKey = "sync.routeChanged" }
                else if cancelled { messageKey = "sync.cancelled" }
                else {
                    failure = inputFailure ?? error as? CalibrationFailure; audioError = error as? AudioBackendError
                    messageKey = failure?.messageKey ?? (audioError == nil ? "sync.failure.unknown" : "sync.failure.audio")
                }
                stage = .ready
            }
            if let id = captureID { await audio.stopCapture(id: id) }
            if let id = transportID { await audio.stopTransport(id: id) }
            captureID = nil; transportID = nil; running = false; task = nil
        }
    }

    func tap(hostSeconds: Double) {
        guard canTap, let index = timelines.indices.last else { return }
        guard hostSeconds.isFinite, hostSeconds >= 0 else { rejectTapTimestamp(); return }
        guard timelines[index].events.count < 128 else { inputFailure = .init(reason: .dataLoss); task?.cancel(); return }
        guard timelines[index].events.last.map({ hostSeconds > $0.time }) ?? true else { rejectTapTimestamp(); return }
        timelines[index].events.append(SyncTimelineEvent(id: UInt64(timelines[index].events.count + 1), time: hostSeconds, kind: .tap))
    }

    private func runTaps(audio: AudioSessionStore, instrument: InstrumentProfile, string: Int, output: CalibrationEndpoint) async throws {
        let request = try PersonalSyncProbe.request(instrument: instrument, string: string, mode: .preview)
        transportID = request.id
        try await audio.coordinator.startTransport(request)
        let deadline = ContinuousClock.now.advanced(by: .seconds(40))
        var epoch: Double?, drift = 0.0, completedAt: ContinuousClock.Instant?
        while true {
            let state = try await checkedRoute(audio)
            guard ContinuousClock.now < deadline else { throw AudioBackendError.streamStalled }
            guard let playback = state.transport, playback.requestID == request.id else { throw AudioBackendError.invalidFormat }
            if let anchor = playback.renderAnchorHostSeconds {
                if epoch == nil { epoch = anchor }
                drift = max(drift, abs(anchor - epoch!))
            }
            if let epoch { updateTimelineOrigin(epoch + (output.hardwareLatencySeconds ?? 0)) }
            updateCursor(playback, output: output, alignment: 0)
            if playback.phase == .completed, completedAt == nil { completedAt = .now }
            // Keep accepting taps for the final click after the output-only renderer has drained.
            if let completedAt, completedAt.duration(to: .now) >= .seconds(0.5) {
                guard let epoch else { throw CalibrationFailure(reason: .clockUnavailable) }
                guard drift <= 0.02 else { throw CalibrationFailure(reason: .clockDrift) }
                let expected = (4..<20).map { epoch + (output.hardwareLatencySeconds ?? 0) + Double($0) }
                let observed = timelines.last!.events.map(\.time)
                let timing = PersonalSyncPassAnalysis(expected: expected, observed: observed)
                diagnostics = CalibrationDiagnostics(passNumber: 1, targetFrequency: 0)
                diagnostics?.phase = .playing; diagnostics?.measuredAttacks = timing.attackCount
                diagnostics?.timing = timing; diagnostics?.clockDrift = drift
                let evidence = try accepted(timing)
                outputCandidate = try OutputAlignmentProfile(output: output, evidence: evidence, clockDriftSeconds: drift); stage = .result
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func runGuitar(audio: AudioSessionStore, instrument: InstrumentProfile, string: Int, route: CalibrationRoute) async throws {
        let alignment = outputSetting?.seconds ?? 0
        let id = UUID(); captureID = id
        let frequency = try instrument.tuning.frequency(at: FretPosition(string: string, fret: 0))
        diagnostics = CalibrationDiagnostics(passNumber: 2, targetFrequency: frequency)
        try await audio.coordinator.start(purpose: .calibration, requestID: id)
        let signalDeadline = ContinuousClock.now.advanced(by: .seconds(20))
        var baseline: AudioAnalysisSnapshot?
        while baseline == nil {
            let state = try await checkedCapture(audio, id: id)
            if PracticePreflightSignal.isReady(state.meters), let pitch = state.meters?.analysis?.latest?.pitch,
               abs(1200 * log2(pitch.frequency / frequency)) <= 50 { baseline = state.meters?.analysis }
            else if ContinuousClock.now >= signalDeadline { throw diagnostics!.signalFailure }
            if baseline == nil { try await Task.sleep(for: .milliseconds(50)) }
        }
        let request = try PersonalSyncProbe.request(instrument: instrument, string: string)
        transportID = request.id
        try await audio.coordinator.startTransport(request); stage = .listening
        var events: [DetectedNoteEvent] = [], lastEvent = baseline!.totalEvents, lastSpan = baseline!.totalQualitySpans
        var epoch: Double?, completedAt: ContinuousClock.Instant?, hadClock = false
        var drift = 0.0
        let deadline = ContinuousClock.now.advanced(by: .seconds(40))
        while true {
            let state = try await checkedCapture(audio, id: id)
            guard ContinuousClock.now < deadline else { throw AudioBackendError.streamStalled }
            if let analysis = state.meters?.analysis {
                let newEvents = analysis.events.filter { $0.id > lastEvent }
                let spans = analysis.qualitySpans.filter { $0.id > lastSpan }
                guard analysis.invalidSamples == 0, analysis.totalEvents >= lastEvent, analysis.totalQualitySpans >= lastSpan,
                      analysis.totalEvents - lastEvent == UInt64(newEvents.count),
                      analysis.totalQualitySpans - lastSpan == UInt64(spans.count), events.count + newEvents.count <= 128,
                      !spans.contains(where: { $0.quality == .clipping || $0.quality == .invalid }) else {
                    throw CalibrationFailure(reason: spans.contains(where: { $0.quality == .clipping }) ? .clipping : .dataLoss)
                }
                events += newEvents; lastEvent = analysis.totalEvents; lastSpan = analysis.totalQualitySpans
            }
            guard let playback = state.transport, playback.requestID == request.id else { throw AudioBackendError.invalidFormat }
            if epoch == nil { epoch = playback.renderAnchorHostSeconds }
            updateCursor(playback, output: route.output, alignment: alignment)
            diagnostics?.phase = stage
            if let epoch {
                updateTimelineOrigin(try route.expectedTime(renderEpochSeconds: epoch, sampleFrame: 0))
                let expected = try expectedTimes(route, epoch: epoch, alignment: alignment)
                _ = try diagnostics?.analyze(events: events, expected: expected, route: route)
                timelines[timelines.count - 1].events = try events.map { event in
                    guard let host = event.onset.hostSeconds else { throw CalibrationFailure(reason: .timestamps) }
                    let time = try route.observedTime(inputHostSeconds: host)
                    let kind: SyncTimelineEvent.Kind
                    if event.quality == .reliable, let pitch = event.pitch, pitch.clarity >= 0.9 {
                        kind = abs(1200 * log2(pitch.frequency / frequency)) <= 50 ? .matching : .wrong
                    } else { kind = .uncertain }
                    return SyncTimelineEvent(id: event.id, time: time, kind: kind)
                }
            }
            if playback.phase == .completed, completedAt == nil { completedAt = .now }
            if let value = state.clock?.validatedDriftSeconds { drift = max(drift, abs(value)); hadClock = true; diagnostics?.clockDrift = drift }
            else if hadClock { throw CalibrationFailure(reason: .clockUnavailable) }
            if let completedAt, completedAt.duration(to: .now) >= .seconds(1.8 + (route.input.hardwareLatencySeconds ?? 0) + (route.output.hardwareLatencySeconds ?? 0)) {
                guard let epoch, state.clock?.validatedDriftSeconds != nil else { throw CalibrationFailure(reason: .clockUnavailable) }
                guard drift <= 0.02 else { throw CalibrationFailure(reason: .clockDrift) }
                let expected = try expectedTimes(route, epoch: epoch, alignment: alignment)
                let observed = try diagnostics!.analyze(events: events, expected: expected, route: route)
                if let failure = diagnostics?.noteFailure { throw failure }
                let timing = PersonalSyncPassAnalysis(expected: expected, observed: observed); diagnostics?.timing = timing
                let guitar = try accepted(timing)
                let evidence = try InstrumentSyncEvidence(instrument: instrument, string: string, outputSetting: outputSetting, guitar: guitar)
                candidate = try CalibrationProfile(route: route, method: .personal, residualOffsetSeconds: evidence.offset,
                    uncertaintySeconds: evidence.uncertainty + drift, instrumentEvidence: evidence)
                stage = .result; return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
    private func accepted(_ timing: PersonalSyncPassAnalysis) throws -> SyncPassEvidence {
        if let rejection = timing.rejection { throw CalibrationFailure(reason: CalibrationFailure.Reason(rawValue: rejection.rawValue) ?? .unknown) }
        guard let offset = timing.offset, let spread = timing.spread, let drift = timing.drift else { throw CalibrationFailure(reason: .unknown) }
        return try SyncPassEvidence(offset: offset, spread: spread, drift: drift)
    }
    private func expectedTimes(_ route: CalibrationRoute, epoch: Double, alignment: Double) throws -> [Double] {
        try (4..<20).map { try route.expectedTime(renderEpochSeconds: epoch, sampleFrame: Int64(Double($0) * route.output.sampleRate)) + alignment }
    }
    private func updateTimelineOrigin(_ origin: Double) { timelines[timelines.count - 1].origin = origin }
    private func updateCursor(_ playback: TransportPlaybackSnapshot, output: CalibrationEndpoint, alignment: Double) {
        elapsedSeconds = max(0, Double(playback.renderedFrames) / playback.sampleRate - (output.hardwareLatencySeconds ?? 0) - alignment)
        timelines[timelines.count - 1].cursor = min(20, elapsedSeconds)
        if elapsedSeconds >= 4 { stage = .playing }
    }
    private func finishTimeline(_ status: SyncTimelineRun.Status) {
        guard !timelines.isEmpty else { return }
        timelines[timelines.count - 1].status = status; timelines[timelines.count - 1].cursor = nil
    }
    private func checkedRoute(_ audio: AudioSessionStore) async throws -> AudioCoordinatorSnapshot {
        try Task.checkCancellation(); await audio.coordinator.poll(); await audio.publish(); try Task.checkCancellation()
        guard let state = audio.state else { throw AudioBackendError.unavailableDevice }
        switch state.phase { case let .failed(error), let .interrupted(error): throw error; default: break }
        guard state.outputEndpoint == frozenOutput, (source == .taps || state.calibrationRoute == frozenRoute), state.routeRevision == revision, audio.synchronizationSession == session else { throw AudioBackendError.routeChanged }
        return state
    }
    private func checkedCapture(_ audio: AudioSessionStore, id: UUID) async throws -> AudioCoordinatorSnapshot {
        let state = try await checkedRoute(audio); diagnostics?.observe(state.meters)
        guard state.captureRequestID == id, state.phase == .running else { throw AudioBackendError.routeChanged }
        if let meters = state.meters, meters.totalFrames > 0 {
            guard meters.peak.isFinite, meters.invalidSamples == 0, meters.droppedPackets == 0, meters.discontinuities == 0 else { throw CalibrationFailure(reason: .dataLoss) }
            guard meters.peak < 0.995 else { throw CalibrationFailure(reason: .clipping) }
            guard meters.hostTimeValid else { throw CalibrationFailure(reason: .timestamps) }
        }
        return state
    }
    func apply(audio: AudioSessionStore, store: CalibrationStore, instrument: InstrumentProfile) async {
        guard !running, let candidate, let revision, let session,
              candidate.route == audio.state?.calibrationRoute, revision == audio.state?.routeRevision,
              session == audio.synchronizationSession, frozenInstrument == instrument,
              outputSetting?.id == store.outputProfile(for: frozenOutput)?.id else {
            invalidate(audio: audio); return
        }
        guard candidate.isNonnegativeSetting else { messageKey = "sync.nonnegative.measurement"; return }
        if await store.save(candidate) {
            // Save may suspend: a changed route never becomes eligible through a stale receipt.
            store.confirm(candidate, session: session, revision: revision)
            messageKey = "calibration.saved"
        } else { messageKey = "calibration.storageSave" }
    }
    func applyOutput(audio: AudioSessionStore, store: CalibrationStore) async {
        guard !running, audio.state?.purpose == nil, audio.state?.isClicking != true, audio.state?.isStartingClick != true, let outputCandidate,
              audio.state?.outputEndpoint == outputCandidate.output, revision == audio.state?.routeRevision,
              session == audio.synchronizationSession else { invalidate(audio: audio); return }
        guard outputCandidate.isNonnegativeSetting else { messageKey = "sync.nonnegative.measurement"; return }
        if await store.saveOutput(outputCandidate) { messageKey = "calibration.saved" }
        else { messageKey = "calibration.storageSave" }
    }
    func applyManualOutput(_ value: OutputAlignmentProfile, audio: AudioSessionStore, store: CalibrationStore) async {
        guard value.isNonnegativeSetting else { messageKey = "sync.manual.invalid"; return }
        guard !running, value.isManual, audio.state?.purpose == nil, audio.state?.isClicking != true,
              audio.state?.isStartingClick != true, value.output == audio.state?.outputEndpoint else { return }
        if await store.saveOutput(value) {
            outputCandidate = nil; invalidateInstrument(audio: audio); messageKey = "calibration.saved"
        } else { messageKey = "calibration.storageSave" }
    }
    func applyManualInstrument(_ remainingOffset: Double, audio: AudioSessionStore, store: CalibrationStore, instrument: InstrumentProfile) async {
        guard remainingOffset.isFinite, (0...1).contains(remainingOffset) else { messageKey = "sync.manual.invalid"; return }
        guard !running, let state = audio.state, let route = state.calibrationRoute,
              state.purpose == nil, !state.isClicking, !state.isStartingClick else { return }
        let session = audio.synchronizationSession
        do {
            let evidence = try ManualInstrumentSyncEvidence(instrument: instrument, outputSetting: store.outputProfile(for: route.output), remainingOffset: remainingOffset)
            let value = try CalibrationProfile(route: route, method: .manualPersonal, residualOffsetSeconds: evidence.offset,
                uncertaintySeconds: ManualInstrumentSyncEvidence.scoringAllowance, manualInstrumentEvidence: evidence)
            if await store.save(value) {
                store.confirm(value, session: session, revision: state.routeRevision)
                candidate = nil; messageKey = "calibration.saved"
            } else { messageKey = "calibration.storageSave" }
        } catch { messageKey = "sync.manual.invalid" }
    }
    func cancel(audio: AudioSessionStore) {
        task?.cancel() // UUID-owned cleanup runs in the task; charts remain available for screenshots.
    }
    func rejectTapTimestamp() {
        guard canTap else { return }
        inputFailure = .init(reason: .timestamps); task?.cancel()
    }
    /// Settings may change while this sheet is closed; retained evidence must show its stale context on reopen.
    func refreshContext(audio: AudioSessionStore, store: CalibrationStore, instrument: InstrumentProfile, string: Int) {
        guard frozenOutput != nil else { return }
        guard frozenOutput == audio.state?.outputEndpoint, revision == audio.state?.routeRevision,
              session == audio.synchronizationSession else { invalidate(audio: audio); return }
        if frozenInstrument != instrument || frozenString != string || outputSetting != store.outputProfile(for: frozenOutput) {
            invalidateInstrument(audio: audio)
        }
    }
    func invalidateInstrument(audio: AudioSessionStore) {
        candidate = nil
        for index in timelines.indices where timelines[index].source == .guitar {
            timelines[index].status = .stale; timelines[index].cursor = nil
        }
        if source == .guitar {
            invalidated = true; task?.cancel()
            if !running { stage = .ready }
        }
    }
    func invalidate(audio: AudioSessionStore) {
        invalidated = true; candidate = nil; outputCandidate = nil; task?.cancel()
        for index in timelines.indices { timelines[index].status = .stale; timelines[index].cursor = nil }
        if !running { stage = .ready; messageKey = "sync.routeChanged" }
    }
    private func reset() {
        candidate = nil; outputCandidate = nil; outputSetting = nil; frozenOutput = nil; diagnostics = nil; failure = nil
        frozenRoute = nil; frozenInstrument = nil; frozenString = nil; revision = nil; session = nil
        messageKey = nil; audioError = nil; stage = .ready; passNumber = 1; elapsedSeconds = 0
    }
}
