import SwiftUI
import Domain
import Audio

@MainActor @Observable
final class PracticeModel {
    @ObservationIgnored private let audio: AudioSessionStore
    @ObservationIgnored private let calibration: CalibrationStore
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var captureID: UUID?
    @ObservationIgnored private var collector: PracticeEvidenceCollector?
    @ObservationIgnored private var renderEpoch: Double?
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var signalConfirmed = false
    @ObservationIgnored private var maximumDrift: Double?
    @ObservationIgnored private var clockInvalid = false
    @ObservationIgnored private var pendingConfigurationReset = false
    @ObservationIgnored private var publishedAttemptID: UUID?
    @ObservationIgnored private var lastLiveFrame: Int64?
    @ObservationIgnored private var lastLiveUpdate: ContinuousClock.Instant?
    @ObservationIgnored var onAttemptFinished: ((PracticeEvidence) async -> Void)?
    private(set) var machine = PracticeStateMachine()
    private(set) var request: PracticeRequest?
    private(set) var bpm = 60.0
    private(set) var firstBar = 1
    private(set) var lastBar = 1
    private(set) var repeatEnabled = false
    private(set) var clickVolume = 0.3
    private(set) var isBusy = false
    private(set) var cursorTick: Int64?
    private(set) var countInBeat: Int?
    private(set) var latestFrequency: Double?
    private(set) var latestEvidence: PracticeEvidence?
    private(set) var completedCount = 0
    private(set) var errorKey: String?
    private(set) var backendError: AudioBackendError?
    var physicallyTuned = false
    var phase: PracticePhase { machine.phase }
    var barCount: Int { max(1, Int(((request?.exercise.durationTicks ?? 1) - 1) / (request?.exercise.timeSignature.ticksPerBar ?? 3840)) + 1) }
    var activeEvent: MusicalEvent? {
        guard phase == .running, let cursorTick else { return nil }
        return machine.configuration?.selectedEvents.first { $0.startTick <= cursorTick && cursorTick < $0.endTick }
    }
    var expectedPositions: [FretPosition] {
        if phase == .running { return activeEvent?.positions ?? [] }
        guard phase != .finalizing, let exercise = request?.exercise else { return [] }
        let lower = Int64(firstBar - 1) * exercise.timeSignature.ticksPerBar
        let upper = Int64(lastBar).multipliedReportingOverflow(by: exercise.timeSignature.ticksPerBar)
        let end = upper.overflow ? exercise.durationTicks : min(exercise.durationTicks, upper.partialValue)
        return exercise.events.first { $0.startTick >= lower && $0.startTick < end && $0.kind == .note }?.positions ?? []
    }
    init(audio: AudioSessionStore, calibration: CalibrationStore) { self.audio = audio; self.calibration = calibration }

    func configure(_ request: PracticeRequest?) {
        guard self.request != request else { return }
        stop(.changedExercise); self.request = request
        if isBusy { pendingConfigurationReset = true } else { machine = PracticeStateMachine() }
        bpm = request?.exercise.defaultBPM ?? 60; firstBar = 1; lastBar = barCount
        physicallyTuned = false; latestEvidence = nil; completedCount = 0; errorKey = nil
    }
    func setTempo(_ value: Double) {
        guard value.isFinite, let exercise = request?.exercise, (exercise.minimumBPM...exercise.maximumBPM).contains(value) else {
            errorKey = "practice.error.tempo"; return
        }
        guard bpm != value else { return }; stop(.changedTempo); bpm = value
    }
    func setBars(first: Int, last: Int) {
        let lower = max(1, min(first, barCount)), upper = max(lower, min(last, barCount))
        guard lower != firstBar || upper != lastBar else { return }
        stop(.changedRange); firstBar = lower; lastBar = upper
    }
    func seekBar(_ bar: Int, extending: Bool) {
        stop(.changedRange)
        setBars(first: extending ? min(firstBar, bar) : bar, last: extending ? max(lastBar, bar) : bar)
    }
    var selectedEventIDs: Set<String> {
        if phase.active { return Set(activeEvent.map { [$0.id] } ?? []) }
        guard let exercise = request?.exercise else { return [] }
        let lower = Int64(firstBar - 1) * exercise.timeSignature.ticksPerBar
        let upper = Int64(lastBar).multipliedReportingOverflow(by: exercise.timeSignature.ticksPerBar)
        let end = upper.overflow ? exercise.durationTicks : min(exercise.durationTicks, upper.partialValue)
        return Set(exercise.events.filter { $0.startTick >= lower && $0.startTick < end }.map(\.id))
    }
    func setRepeat(_ value: Bool) { repeatEnabled = value }
    func setClickVolume(_ value: Double) { guard value.isFinite, !isBusy else { return }; clickVolume = min(1, max(0, value)) }
    func instrumentWillChange(_ value: InstrumentProfile) {
        guard let old = machine.configuration?.instrument else { physicallyTuned = false; return }
        if old.tuning != value.tuning || old.source != value.source {
            physicallyTuned = false; stop(.changedInstrument)
        }
    }
    func pause() {
        let bar = request?.exercise.timeSignature.ticksPerBar ?? 3840
        let resumeBar = cursorTick.map { Int($0 / bar) + 1 }
        stop(.paused)
        if let resumeBar { firstBar = min(lastBar, max(firstBar, resumeBar)) }
    }
    func stop(_ reason: PracticeStopReason = .userCancelled) {
        guard isBusy else { return }
        machine.stop(reason); task?.cancel()
        if let id = captureID { Task { await audio.stopCapture(id: id) } }
    }

    func start(instrument: InstrumentProfile) {
        guard !isBusy, let request else { return }
        errorKey = nil; backendError = nil
        guard let route = audio.state?.calibrationRoute else { errorKey = "practice.error.route"; return }
        let configuration: PracticeConfiguration
        do {
            let bar = request.exercise.timeSignature.ticksPerBar
            let upper = Int64(lastBar).multipliedReportingOverflow(by: bar)
            let endTick = upper.overflow ? request.exercise.durationTicks : min(request.exercise.durationTicks, upper.partialValue)
            configuration = try PracticeConfiguration(exercise: request.exercise, instrument: instrument, bpm: bpm,
                range: Int64(firstBar - 1) * bar..<endTick,
                route: route, calibration: calibration.profile(for: route),
                lesson: PracticeLessonReference(id: request.lessonID, version: request.lessonVersion))
            try machine.begin(configuration)
        } catch { errorKey = Self.configurationError(error); return }
        latestEvidence = nil
        guard physicallyTuned else { machine.stop(.tuningNotConfirmed); return }
        let id = UUID(); captureID = id; isBusy = true; signalConfirmed = false
        cursorTick = nil; countInBeat = nil; latestFrequency = nil; latestEvidence = nil; completedCount = 0
        resetAttempt()
        task = Task {
            do {
                try await audio.coordinator.start(purpose: .practice, requestID: id)
                try Task.checkCancellation()
                try await preflight(configuration: configuration, captureID: id)
                signalConfirmed = true
                repeat {
                    try Task.checkCancellation()
                    if phase == .completed { try machine.begin(configuration); resetAttempt() }
                    try await playAttempt(configuration: configuration, captureID: id)
                    if !repeatEnabled { break }
                } while true
            } catch {
                if machine.phase.active {
                    if let backend = error as? AudioBackendError { backendError = backend; machine.stop(Self.stopReason(backend)) }
                    else { machine.stop(error is CancellationError ? .userCancelled : .evidenceOverflow) }
                }
                await publishEvidence()
            }
            await audio.stopCapture(id: id)
            if pendingConfigurationReset { machine = PracticeStateMachine(); latestEvidence = nil; pendingConfigurationReset = false }
            if captureID == id { captureID = nil; isBusy = false; task = nil; cursorTick = nil; countInBeat = nil; latestFrequency = nil }
        }
    }

    private func resetAttempt() {
        collector = nil; renderEpoch = nil; startedAt = Date(); maximumDrift = nil; clockInvalid = false
        publishedAttemptID = nil; lastLiveFrame = nil; lastLiveUpdate = nil
    }
    private func checkedState(_ id: UUID, configuration: PracticeConfiguration) async throws -> AudioCoordinatorSnapshot {
        try Task.checkCancellation()
        let state = await audio.coordinator.snapshot()
        guard state.captureRequestID == id, state.phase == .running, state.calibrationRoute == configuration.route else {
            if case let .interrupted(error) = state.phase { throw error }
            if case let .failed(error) = state.phase { throw error }
            if state.phase == .idle { throw AudioBackendError.cancelled }
            throw AudioBackendError.routeChanged
        }
        return state
    }
    private func preflight(configuration: PracticeConfiguration, captureID: UUID) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while true {
            let state = try await checkedState(captureID, configuration: configuration)
            updateLive(state)
            if PracticePreflightSignal.isReady(state.meters) { return }
            if ContinuousClock.now >= deadline { machine.stop(.noTestSignal); throw PracticeError.invalidEvidence }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
    private func playAttempt(configuration: PracticeConfiguration, captureID: UUID) async throws {
        let initial = try await checkedState(captureID, configuration: configuration)
        guard let baseline = initial.meters?.analysis else { throw AudioBackendError.invalidFormat }
        collector = PracticeEvidenceCollector(configuration: configuration, baseline: baseline)
        let transport = try TransportRequest(exercise: configuration.exercise, tuning: configuration.instrument.tuning,
            bpm: configuration.bpm, range: configuration.range, countInBars: configuration.countInBars,
            loops: false, mode: .practice, clickVolume: clickVolume, toneVolume: 0)
        try machine.preflightPassed()
        try await audio.coordinator.startTransport(transport)
        let deadline = ContinuousClock.now.advanced(by: .seconds(configuration.countInSeconds + configuration.durationSeconds + 30))
        var completedAt: ContinuousClock.Instant?
        while true {
            let state = try await checkedState(captureID, configuration: configuration)
            updateLive(state)
            guard let playback = state.transport, playback.requestID == transport.id else { throw AudioBackendError.invalidFormat }
            if renderEpoch == nil { renderEpoch = playback.renderAnchorHostSeconds }
            cursorTick = playback.position.tick; countInBeat = playback.position.countInBeat
            if playback.position.countInBeat == nil && phase == .countIn { try machine.beginPlaying() }
            if let renderEpoch, let analysis = state.meters?.analysis { try collector?.consume(analysis, renderEpochSeconds: renderEpoch) }
            if let drift = state.clock?.validatedDriftSeconds { maximumDrift = max(maximumDrift ?? 0, abs(drift)) }
            else if maximumDrift != nil { clockInvalid = true }
            if playback.phase == .completed {
                if phase == .countIn { try machine.beginPlaying() }
                if phase == .running { try machine.beginFinalizing(); completedAt = .now }
                if let completedAt, completedAt.duration(to: .now) >= .seconds(configuration.finalDrainSeconds),
                   let renderEpoch, try collector?.hasResolvedTail(renderEpochSeconds: renderEpoch) == true {
                    try machine.complete(); completedCount += 1
                    await publishEvidence()
                    await audio.stopTransport(id: transport.id, keepingCapture: true)
                    return
                }
            }
            if ContinuousClock.now >= deadline { throw AudioBackendError.streamStalled }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
    private func updateLive(_ state: AudioCoordinatorSnapshot) {
        let latest = state.meters?.analysis?.latest
        if let frame = latest?.time.frame, frame != lastLiveFrame { lastLiveFrame = frame; lastLiveUpdate = .now }
        let fresh = lastLiveUpdate.map { $0.duration(to: .now) <= .milliseconds(200) } ?? false
        latestFrequency = fresh && latest?.quality == .reliable ? latest?.pitch?.frequency : nil
    }
    private func publishEvidence() async {
        guard let id = machine.attemptID, publishedAttemptID != id, let configuration = machine.configuration else { return }
        do {
            let value = try PracticeEvidence(id: id, configuration: configuration, startedAt: startedAt, finishedAt: max(Date(), startedAt),
                phase: phase, reason: machine.reason, signalConfirmed: signalConfirmed, renderEpochSeconds: renderEpoch,
                maximumClockDriftSeconds: clockInvalid ? nil : maximumDrift, attacks: collector?.attacks ?? [],
                clipping: collector?.clipping ?? [], uncertainSignal: collector?.uncertainSignal ?? [], analysisVersion: collector?.analysisVersion ?? MonophonicAnalyzer.algorithmVersion)
            publishedAttemptID = id
            if !pendingConfigurationReset { latestEvidence = value }
            await onAttemptFinished?(value)
        } catch { errorKey = "practice.error.evidence" }
    }
    private static func stopReason(_ error: AudioBackendError) -> PracticeStopReason {
        switch error {
        case .routeChanged, .unavailableDevice: .routeChanged
        case .permissionDenied: .permissionDenied
        case .suspended: .suspended
        case .dataLoss: .dataLoss
        case .streamStalled: .streamStalled
        case .invalidFormat, .invalidChannel: .invalidFormat
        case .cancelled: .userCancelled
        default: .audioFailure
        }
    }
    private static func configurationError(_ error: Error) -> String {
        if let music = error as? MusicError {
            switch music {
            case .tuningMismatch: return "practice.error.tuning"
            case .invalidTempo: return "practice.error.tempo"
            case .unsupportedPitch, .unsupportedDuration: return "practice.error.capability"
            default: return "practice.error.exercise"
            }
        }
        if error as? PracticeError == .unsupportedFormat { return "practice.error.format" }
        return "practice.error.range"
    }
}
