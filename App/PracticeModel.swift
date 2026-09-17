import SwiftUI
import Domain
import Audio

@MainActor @Observable
final class PracticeModel {
    @ObservationIgnored private let audio: AudioSessionStore
    @ObservationIgnored private let calibration: CalibrationStore
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var captureID: UUID?
    @ObservationIgnored private var synchronizationSession: UUID?
    @ObservationIgnored private var synchronizationRevision: UInt64?
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
    @ObservationIgnored private var listeningTask: Task<Void, Never>?
    @ObservationIgnored private var listeningInstrument: InstrumentProfile?
    @ObservationIgnored private var listeningRevision: UInt64?
    @ObservationIgnored private var listeningSession: UUID?
    private(set) var listening = ListeningPreparation()
    private(set) var isListeningBusy = false
    var isListeningPractice: Bool { request?.activityReference?.presentation == .listenAndRepeat }
    var hidesTargets: Bool { isListeningPractice && !listening.targetsRevealed }
    var listeningConditions: PracticeListeningConditions? {
        guard isListeningPractice else { return nil }
        // Reconfiguration or sleep invalidates a completed reference even while the screen is idle.
        if listeningRevision != audio.state?.routeRevision || listeningSession != audio.synchronizationSession {
            return try? PracticeListeningConditions(referencePlaybackCompleted: false, targetsRevealed: listening.targetsRevealed)
        }
        return listening.conditions
    }
    var canStartPreparedAttempt: Bool { !isListeningBusy && (!isListeningPractice || listeningConditions != nil) }
    private(set) var machine = PracticeStateMachine()
    private(set) var request: PracticeRequest?
    private(set) var bpm = 60.0
    private(set) var firstBar = 1
    private(set) var lastBar = 1
    private(set) var repeatEnabled = false
    private(set) var clickVolume = 0.3
    private(set) var isBusy = false
    private(set) var cursorTick: Int64?
    private(set) var displayTick: Double?
    private(set) var countInBeat: Int?
    private(set) var latestFrequency: Double?
    private(set) var latestEvidence: PracticeEvidence?
    private(set) var completedCount = 0
    private(set) var errorKey: String?
    private(set) var rangeExpandedForSustain = false
    private(set) var backendError: AudioBackendError?
    private(set) var recordedTake: CoachRecordedTake?
    private(set) var recordsForCoach = false
    private(set) var coachLanguage = "en"
    private(set) var coachProvider = CoachProvider.codex
    private(set) var coachLesson = ""
    var physicallyTuned = false
    var phase: PracticePhase { machine.phase }
    var barCount: Int { max(1, Int(((request?.exercise.durationTicks ?? 1) - 1) / (request?.exercise.timeSignature.ticksPerBar ?? 3840)) + 1) }
    var activeEvent: MusicalEvent? {
        guard (phase == .running || phase == .finalizing), let cursorTick else { return nil }
        return machine.configuration?.selectedEvents.first { $0.startTick <= cursorTick && cursorTick < $0.endTick }
    }
    var expectedPositions: [FretPosition] { expectedEvent?.techniquePositions ?? [] }
    func expectedFretTargets(in tuning: TuningProfile) -> [EventFretTarget] { (try? expectedEvent?.visualTargets(in: tuning)) ?? [] }
    private var expectedEvent: MusicalEvent? {
        guard !hidesTargets else { return nil }
        if phase == .running { return activeEvent }
        guard phase != .finalizing, let exercise = request?.exercise else { return nil }
        let lower = Int64(firstBar - 1) * exercise.timeSignature.ticksPerBar
        let upper = Int64(lastBar).multipliedReportingOverflow(by: exercise.timeSignature.ticksPerBar)
        let end = upper.overflow ? exercise.durationTicks : min(exercise.durationTicks, upper.partialValue)
        return exercise.events.first { $0.startTick >= lower && $0.startTick < end && $0.kind == .note }
    }
    init(audio: AudioSessionStore, calibration: CalibrationStore) { self.audio = audio; self.calibration = calibration }
    func takeRecording() -> CoachRecordedTake? { defer { recordedTake = nil }; return recordedTake }

    func configure(_ request: PracticeRequest?) {
        guard self.request != request else { return }
        stop(.changedExercise); listening = ListeningPreparation(); self.request = request
        if isBusy { pendingConfigurationReset = true } else { machine = PracticeStateMachine() }
        bpm = request?.initialBPM ?? request?.exercise.defaultBPM ?? 60
        let bar = request?.exercise.timeSignature.ticksPerBar ?? 3840
        firstBar = request?.initialRange.map { Int($0.lowerBound / bar) + 1 } ?? 1
        lastBar = request?.initialRange.map { Int(($0.upperBound - 1) / bar) + 1 } ?? barCount
        repeatEnabled = false; rangeExpandedForSustain = false
        physicallyTuned = false; latestEvidence = nil; completedCount = 0; errorKey = nil
    }
    func setTempo(_ value: Double) {
        guard value.isFinite, let exercise = request?.exercise, (exercise.minimumBPM...exercise.maximumBPM).contains(value) else {
            errorKey = "practice.error.tempo"; return
        }
        guard bpm != value else { return }; stop(.changedTempo); bpm = value
    }
    func setBars(first: Int, last: Int) {
        guard let exercise = request?.exercise else { return }
        let requestedLower = max(1, min(first, barCount)), requestedUpper = max(requestedLower, min(last, barCount))
        let complete = PracticeBarSelection.completeEvents(in: exercise, first: requestedLower, last: requestedUpper)
        let lower = complete.lowerBound, upper = complete.upperBound
        rangeExpandedForSustain = lower != requestedLower || upper != requestedUpper
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
    func setRepeat(_ value: Bool) { repeatEnabled = isListeningPractice || recordsForCoach && isBusy ? false : value }
    func setClickVolume(_ value: Double) { guard value.isFinite, !isBusy else { return }; clickVolume = min(1, max(0, value)) }
    func instrumentWillChange(_ value: InstrumentProfile) {
        if listeningInstrument != value { cancelListening() }
        guard let old = machine.configuration?.instrument else { physicallyTuned = false; return }
        if old.tuning != value.tuning || old.source != value.source || old.frets != value.frets {
            physicallyTuned = false; stop(.changedInstrument)
        }
    }
    func pause() {
        let bar = request?.exercise.timeSignature.ticksPerBar ?? 3840
        let resumeBar = cursorTick.map { Int($0 / bar) + 1 }
        stop(.paused)
        if let resumeBar, let exercise = request?.exercise {
            let first = min(lastBar, max(firstBar, resumeBar))
            let bounds = PracticeBarSelection.completeEvents(in: exercise, first: first, last: lastBar)
            rangeExpandedForSustain = bounds.lowerBound != first || bounds.upperBound != lastBar
            firstBar = bounds.lowerBound; lastBar = bounds.upperBound
        }
    }
    func stop(_ reason: PracticeStopReason = .userCancelled) {
        displayTick = nil
        cancelListening()
        guard isBusy else { return }
        machine.stop(reason); task?.cancel()
        if let id = captureID { Task { await audio.stopCapture(id: id) } }
    }

    func start(instrument: InstrumentProfile, recordForCoach: Bool = false, language: String = "en", lessonContext: String = "", provider: CoachProvider = .codex) {
        guard !isBusy, !isListeningBusy, let request else { return }
        guard canStartPreparedAttempt else { errorKey = "listening.prepareFirst"; return }
        errorKey = nil; backendError = nil
        let targetInstrument: InstrumentProfile
        do { targetInstrument = try request.retryInstrument(from: instrument) }
        catch { errorKey = "result.retryTuningMismatch"; physicallyTuned = false; return }
        if isListeningPractice, listening.referenceCompleted, listeningInstrument != targetInstrument {
            cancelListening()
            guard canStartPreparedAttempt else { errorKey = "listening.prepareFirst"; return }
        }
        guard let route = audio.state?.calibrationRoute else { errorKey = "practice.error.route"; return }
        let configuration: PracticeConfiguration
        do {
            let bar = request.exercise.timeSignature.ticksPerBar
            let upper = Int64(lastBar).multipliedReportingOverflow(by: bar)
            let endTick = upper.overflow ? request.exercise.durationTicks : min(request.exercise.durationTicks, upper.partialValue)
            configuration = try PracticeConfiguration(exercise: request.exercise, instrument: targetInstrument, bpm: bpm,
                range: Int64(firstBar - 1) * bar..<endTick,
                route: route, calibration: calibration.usableProfile(audio: audio, instrument: targetInstrument),
                outputAlignment: calibration.outputProfile(for: route.output),
                lesson: PracticeLessonReference(id: request.lessonID, version: request.lessonVersion, position: request.historicalPosition, activity: request.activityReference), listeningConditions: listeningConditions)
            if recordForCoach && (configuration.durationSeconds > 120 || configuration.countInSeconds + configuration.durationSeconds + configuration.finalDrainSeconds > 145) {
                errorKey = "coach.error.tooLarge"; return
            }
            try machine.begin(configuration)
        } catch { errorKey = Self.configurationError(error); return }
        latestEvidence = nil
        guard physicallyTuned else { machine.stop(.tuningNotConfirmed); return }
        listening.invalidate()
        recordsForCoach = recordForCoach; recordedTake = nil; coachLanguage = language; coachLesson = lessonContext; coachProvider = provider
        if recordForCoach { repeatEnabled = false }
        synchronizationSession = audio.synchronizationSession; synchronizationRevision = audio.state?.routeRevision
        let id = UUID(); captureID = id; isBusy = true; signalConfirmed = false
        cursorTick = nil; displayTick = nil; countInBeat = nil; latestFrequency = nil; latestEvidence = nil; completedCount = 0
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
            if captureID == id { captureID = nil; isBusy = false; task = nil; cursorTick = nil; displayTick = nil; countInBeat = nil; latestFrequency = nil }
        }
    }

    func revealListeningTargets() {
        guard isListeningPractice, !isBusy, !isListeningBusy else { return }
        listening.reveal()
    }
    private func cancelListening() {
        let previous = listening.playbackID
        listening.invalidate(); listeningTask?.cancel()
        // Keep busy until this task releases its coordinator ownership.
        if let previous { Task { await audio.stopTransport(id: previous) } }
    }
    func listen(instrument: InstrumentProfile) {
        guard isListeningPractice, !isBusy, !isListeningBusy, let request else { return }
        errorKey = nil; backendError = nil
        do {
            let target = try request.retryInstrument(from: instrument)
            let bar = request.exercise.timeSignature.ticksPerBar
            let range = Int64(firstBar - 1) * bar..<min(request.exercise.durationTicks, Int64(lastBar) * bar)
            let transport = try TransportRequest(exercise: request.exercise, tuning: target.tuning,
                bpm: bpm, range: range, countInBars: 1, loops: false,
                clickEnabled: true, clickVolume: max(0.1, clickVolume), toneVolume: 0.5)
            listening.begin(transport.id); isListeningBusy = true
            listeningInstrument = target; listeningRevision = audio.state?.routeRevision
            listeningSession = audio.synchronizationSession
            latestEvidence = nil
            listeningTask = Task {
                do {
                    try Task.checkCancellation()
                    try await audio.coordinator.startTransport(transport)
                    let plan = try TransportPlan(request: transport, sampleRate: 48000)
                    let duration = Double(plan.endFrame ?? 0) / 48000
                    let deadline = ContinuousClock.now.advanced(by: .seconds(duration + 10))
                    while true {
                        try Task.checkCancellation()
                        let state = await audio.coordinator.snapshot()
                        guard listening.playbackID == transport.id,
                              listeningRevision == state.routeRevision,
                              listeningSession == audio.synchronizationSession,
                              let playback = state.transport, playback.requestID == transport.id,
                              state.transportRequestID == transport.id || (playback.phase == .completed && state.phase == .idle && state.purpose == nil) else { throw AudioBackendError.routeChanged }
                        if playback.phase == .completed {
                            let output = state.outputEndpoint
                            let alignment = calibration.outputProfile(for: output)
                            let latency = max(0, (output?.hardwareLatencySeconds ?? (alignment == nil ? playback.presentationLatency : 0)) + (alignment?.seconds ?? 0))
                            // Let already rendered sound leave the output before enabling input practice.
                            try await Task.sleep(for: .seconds(latency + 0.1))
                            try Task.checkCancellation()
                            let final = await audio.coordinator.snapshot()
                            guard final.transport?.requestID == transport.id, final.transport?.phase == .completed,
                                  final.phase == .idle, final.purpose == nil, final.routeRevision == listeningRevision,
                                  listeningSession == audio.synchronizationSession else { throw AudioBackendError.routeChanged }
                            await audio.stopTransport(id: transport.id)
                            try Task.checkCancellation()
                            listening.complete(transport.id)
                            break
                        }
                        guard ContinuousClock.now < deadline else { throw AudioBackendError.streamStalled }
                        try await Task.sleep(for: .milliseconds(50))
                    }
                } catch {
                    if listening.playbackID == transport.id {
                        listening.invalidate()
                        if !(error is CancellationError) { errorKey = "listening.playbackFailed"; backendError = error as? AudioBackendError }
                    }
                }
                await audio.stopTransport(id: transport.id)
                isListeningBusy = false; listeningTask = nil
            }
        } catch { errorKey = "listening.playbackFailed" }
    }

    private func resetAttempt() {
        displayTick = nil
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
        if configuration.calibration?.method.isPersonal == true {
            guard synchronizationSession == audio.synchronizationSession, synchronizationRevision == state.routeRevision else {
                throw AudioBackendError.routeChanged
            }
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
            loops: false, mode: .practice, clickVolume: recordsForCoach ? max(0.1, clickVolume) : clickVolume, toneVolume: 0)
        if recordsForCoach { try await audio.coordinator.beginRecording(requestID: captureID) }
        try machine.preflightPassed()
        try await audio.coordinator.startTransport(transport)
        let displayPlan = try TransportPlan(request: transport, sampleRate: configuration.route.output.sampleRate)
        let deadline = ContinuousClock.now.advanced(by: .seconds(configuration.countInSeconds + configuration.durationSeconds + 30))
        var completedAt: ContinuousClock.Instant?
        while true {
            let state = try await checkedState(captureID, configuration: configuration)
            updateLive(state)
            guard let playback = state.transport, playback.requestID == transport.id else { throw AudioBackendError.invalidFormat }
            if renderEpoch == nil { renderEpoch = playback.renderAnchorHostSeconds }
            let audible = displayPlan.audiblePosition(renderedFrames: playback.renderedFrames,
                outputLatencySeconds: configuration.visualOutputLatency(fallback: playback.presentationLatency),
                visualAlignmentSeconds: configuration.outputAlignment?.seconds ?? 0)
            cursorTick = audible.tick; countInBeat = audible.countInBeat
            if phase == .countIn || phase == .running || phase == .finalizing {
                displayTick = displayPlan.audibleTimelineTick(renderedFrames: playback.renderedFrames,
                    outputLatencySeconds: configuration.visualOutputLatency(fallback: playback.presentationLatency),
                    visualAlignmentSeconds: configuration.outputAlignment?.seconds ?? 0)
            }
            if audible.countInBeat == nil && phase == .countIn { try machine.beginPlaying() }
            if let renderEpoch, let analysis = state.meters?.analysis { try collector?.consume(analysis, renderEpochSeconds: renderEpoch) }
            if let drift = state.clock?.validatedDriftSeconds { maximumDrift = max(maximumDrift ?? 0, abs(drift)) }
            else if maximumDrift != nil { clockInvalid = true }
            if playback.phase == .completed {
                if phase == .countIn { try machine.beginPlaying() }
                if phase == .running { try machine.beginFinalizing(); completedAt = .now }
                if let completedAt, completedAt.duration(to: .now) >= .seconds(configuration.finalDrainSeconds),
                   let renderEpoch, try collector?.hasResolvedTail(renderEpochSeconds: renderEpoch) == true {
                    try machine.complete(); completedCount += 1
                    if recordsForCoach {
                        do {
                            let recording = try await audio.coordinator.endRecording(requestID: captureID)
                            recordedTake = CoachRecordedTake(recording: recording, renderEpoch: renderEpoch, transport: transport)
                        } catch { errorKey = "coach.error.recording" }
                    }
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
                clipping: collector?.clipping ?? [], uncertainSignal: collector?.uncertainSignal ?? [],
                sustainTrace: collector?.sustainTrace(), pitchContour: collector?.pitchContourTrace(), analysisVersion: collector?.analysisVersion ?? MonophonicAnalyzer.algorithmVersion)
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
            case .invalidFret: return "practice.error.fretCount"
            case .unsupportedPitch, .unsupportedDuration: return "practice.error.capability"
            default: return "practice.error.exercise"
            }
        }
        if error as? PracticeError == .unsupportedFormat { return "practice.error.format" }
        return "practice.error.range"
    }
}
