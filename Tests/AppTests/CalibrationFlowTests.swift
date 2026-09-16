import Foundation
import AVFAudio
import Testing
import Domain
import Persistence
@testable import Audio
@testable import PersonalGuitarCoach

private struct CalibrationPermission: AudioPermissionProviding {
    var denied = false
    func status() -> AudioPermissionStatus { denied ? .denied : .authorized }
    func request() -> Bool { false }
}
private actor CalibrationRuntime: AudioRuntime {
    var request: TransportRequest?
    var complete = false
    var changed = false
    var reads: UInt64 = 0
    var wrongPitch = false
    var clipped = false
    var missing = false
    var variable = false
    var clockDrift = 0.0
    var playedOffset = 0.05
    var dataLost = false
    var inputStarts = 0
    func devices() -> [AudioDeviceDescriptor] {
        [AudioDeviceDescriptor(hardwareID: 1, uid: "test", name: "Synthetic interface", inputChannels: 1, outputChannels: 1,
            sampleRate: 48000, bufferFrames: changed ? 256 : 512)]
    }
    func capabilities(device: AudioDeviceDescriptor, channel: Int) -> AudioDeviceCapabilities {
        AudioDeviceCapabilities(sampleRates: [48000...48000], bufferRange: 256...512,
            canSetSampleRate: false, canSetBufferFrames: false, inputGain: nil)
    }
    func timing(device: AudioDeviceDescriptor, channel: Int, input: Bool) -> AudioDeviceTiming {
        AudioDeviceTiming(deviceLatencyFrames: input ? 4800 : 0, streamLatencyFrames: 0, safetyOffsetFrames: 0)
    }
    func startInput(device: AudioDeviceDescriptor, channel: Int) -> AudioStreamFormat { inputStarts += 1; complete = false; reads = 0; return AudioStreamFormat(sampleRate: 48000, inputChannels: 1) }
    func stopInput() {}
    func readInput() -> CaptureSnapshot? {
        reads += 1
        let frames: UInt64 = (complete ? 22 * 48000 : 48000) + reads * 512
        let events: [DetectedNoteEvent] = complete ? (request?.exercise.events.enumerated().map { index, event in
            let frame = Int64((Double(event.startTick) / 960 + playedOffset + (variable && index.isMultiple(of: 2) ? 0.16 : 0)) * 48000)
            let onset = AnalysisTimestamp(frame: frame, sampleRate: 48000, hostSeconds: 100.1 + Double(frame) / 48000)
            return DetectedNoteEvent(id: UInt64(index + 1), onset: onset, resolvedAt: onset, quality: .reliable, pitch: DetectedPitch(frequency: wrongPitch ? 440 : 195.99771799, clarity: 0.98))
        }.filter { !missing || $0.id != 20 } ?? []) : []
        let now = AnalysisTimestamp(frame: Int64(frames), sampleRate: 48000, hostSeconds: 100.1 + Double(frames) / 48000)
        let before = AnalysisTimestamp(frame: Int64(frames) - 14400, sampleRate: 48000, hostSeconds: now.hostSeconds! - 0.3)
        let latest = PitchObservation(time: now, quality: .reliable, pitch: DetectedPitch(frequency: 195.99771799, clarity: 0.98),
                                     rms: 0.1, peak: 0.2, noiseFloor: 0.001, periodEvidence: nil)
        let span = SignalQualitySpan(id: 1, quality: .reliable, start: before, end: now)
        let analysis = AudioAnalysisSnapshot(algorithmVersion: MonophonicAnalyzer.algorithmVersion, latest: latest, events: events,
            totalEvents: UInt64(events.count), invalidSamples: 0, qualitySpans: [span], totalQualitySpans: 1)
        return CaptureSnapshot(totalFrames: frames, totalPackets: frames / 512, droppedPackets: dataLost ? 1 : 0, peak: complete && clipped ? 1 : 0.2, rms: 0.01,
            sampleRate: 48000, lastHostTime: AVAudioTime.hostTime(forSeconds: 100.1 + Double(frames - 512) / 48000 + clockDrift),
            hostTimeValid: true, analysis: analysis, lastPacketFrames: 512)
    }
    func startClick(device: AudioDeviceDescriptor, channel: Int) {}
    func stopClick() {}
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) {}
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) {}
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) {}
    func startTransport(device: AudioDeviceDescriptor, channel: Int, request: TransportRequest) { self.request = request; if request.mode == .preview { complete = false } }
    func stopTransport() { request = nil }
    func readTransport() -> TransportPlaybackSnapshot? {
        guard let request else { return nil }
        return TransportPlaybackSnapshot(requestID: request.id, phase: complete ? .completed : .playing,
            position: TransportPosition(tick: complete ? request.exercise.durationTicks : 0, loopIndex: 0, countInBeat: nil, completed: complete),
            sampleRate: 48000, renderedFrames: complete ? 27 * 48000 : 0, scheduledStartHostSeconds: 100,
            renderAnchorHostSeconds: 100, presentationLatency: 0)
    }
    func finish(wrongPitch: Bool = false, clipped: Bool = false, offset: Double = 0.05) { playedOffset = offset; self.wrongPitch = wrongPitch; self.clipped = clipped; complete = true }
    func failPass(_ kind: String) {
        dataLost = kind == "data"
        missing = kind == "count"; variable = kind == "spread"; clockDrift = kind == "clock" ? 0.03 : 0
        complete = true
    }
    func changeRoute() { changed = true }
}

private actor SynchronizationRepository: CalibrationRepository {
    var values: [CalibrationProfile] = []
    var failing = true
    func loadCalibrationProfiles() -> [CalibrationProfile] { values }
    func saveCalibration(_ profile: CalibrationProfile, replacing expectedID: UUID?) throws {
        if failing { throw StorageError.corruptDocument }
        values = [profile]
    }
    func removeCalibration(id: UUID) { values.removeAll { $0.id == id } }
    func allowWrites() { failing = false }
}

@MainActor struct CalibrationFlowTests {
    private func setup(_ directory: URL, outputOnly: Bool = false) async -> (CalibrationRuntime, AudioSessionStore, CalibrationStore) {
        let repository = LocalRepository(root: directory), runtime = CalibrationRuntime()
        let audio = AudioSessionStore(repository: repository, coordinator: AudioSessionCoordinator(runtime: runtime, permissions: CalibrationPermission(denied: outputOnly)))
        await audio.load(); await audio.select(inputUID: outputOnly ? "" : "test", outputUID: "test")
        let store = CalibrationStore(repository: repository); await store.load()
        return (runtime, audio, store)
    }
    private func waitForRequest(_ runtime: CalibrationRuntime, model: CalibrationModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while await runtime.request == nil, model.running, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(await runtime.request != nil)
    }
    private func waitForCompletion(_ model: CalibrationModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.running, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!model.running)
    }
    private func outputMeasurement(_ runtime: CalibrationRuntime, audio: AudioSessionStore, store: CalibrationStore, offset: Double = 0.2) async throws {
        store.wizard.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3, source: .taps)
        try await waitForRequest(runtime, model: store.wizard)
        for beat in 4..<20 { store.wizard.tap(hostSeconds: 100 + Double(beat) + offset) }
        await runtime.finish(); try await waitForCompletion(store.wizard)
    }
    @Test func instrumentWorksWithDefaultZeroOutputAndNeedsExplicitApply() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory)
        let model = store.wizard, instrument = InstrumentProfile()
        #expect(store.outputProfile(for: audio.state?.outputEndpoint) == nil)
        model.start(audio: audio, store: store, instrument: instrument, string: 3)
        try await waitForRequest(runtime, model: model)
        await runtime.finish(); try await waitForCompletion(model)
        let candidate = try #require(model.candidate)
        #expect(candidate.instrumentEvidence?.outputSetting == nil)
        #expect(abs(candidate.residualOffsetSeconds - 0.05) < 0.001)
        #expect(store.profiles.isEmpty && model.stage == .result)
        #expect(model.timelines.count == 1 && model.timelines[0].events.count == 20)
        await model.apply(audio: audio, store: store, instrument: instrument)
        #expect(store.usableProfile(audio: audio, instrument: instrument) == candidate)
        model.cancel(audio: audio)
        #expect(store.wizard.timelines[0].status == .completed) // Closing/reopening uses the same model.
        let reopened = CalibrationStore(repository: LocalRepository(root: directory)); await reopened.load()
        #expect(reopened.profile(for: candidate.route) == candidate)
        #expect(reopened.usableProfile(audio: audio, instrument: instrument) == nil)
        await audio.coordinator.suspend(); await audio.publish()
        #expect(store.usableProfile(audio: audio, instrument: instrument) == nil)
        model.refreshContext(audio: audio, store: store, instrument: instrument, string: 3)
        #expect(model.timelines[0].status == .stale && model.candidate == nil)
    }
    @Test func outputOnlyNeedsNeitherGuitarNorMicrophoneAndDoesNotEnableInstrumentScoring() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory, outputOnly: true)
        #expect(audio.state?.calibrationRoute == nil && audio.state?.outputEndpoint != nil)
        try await outputMeasurement(runtime, audio: audio, store: store)
        let candidate = try #require(store.wizard.outputCandidate)
        #expect(abs(candidate.seconds - 0.2) < 0.001)
        #expect(await runtime.inputStarts == 0 && store.profiles.isEmpty && store.outputProfiles.isEmpty)
        await store.wizard.applyOutput(audio: audio, store: store)
        #expect(store.outputProfiles == [candidate] && store.profiles.isEmpty)
        let reopened = CalibrationStore(repository: LocalRepository(root: directory)); await reopened.load()
        #expect(reopened.outputProfile(for: audio.state?.outputEndpoint) == candidate)
        #expect(store.wizard.timelines[0].events.count == 16)
    }
    @Test func separateOutputAndInstrumentOffsetsAreCombinedExactlyOnceAndResetInvalidatesInstrument() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory)
        try await outputMeasurement(runtime, audio: audio, store: store, offset: 0.18)
        await store.wizard.applyOutput(audio: audio, store: store)
        let output = try #require(store.outputProfiles.first), model = store.wizard
        model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
        try await waitForRequest(runtime, model: model)
        await runtime.finish(offset: 0.23); try await waitForCompletion(model)
        let candidate = try #require(model.candidate)
        #expect(abs(candidate.instrumentEvidence!.guitar.offset - 0.05) < 0.001)
        #expect(abs(candidate.residualOffsetSeconds - 0.23) < 0.001)
        #expect(candidate.instrumentEvidence?.outputSetting == output)
        #expect(model.timelines.count == 2 && model.timelines[0].source == .taps)
        let guitar = try #require(model.timelines.last)
        let first = try #require(guitar.events.first { $0.id == 5 })
        #expect(abs(guitar.position(first)!.delta - 0.05) < 0.001)
        await model.apply(audio: audio, store: store, instrument: InstrumentProfile())
        #expect(store.usableProfile(audio: audio, instrument: InstrumentProfile()) != nil)
        await store.resetOutput(audio.state?.outputEndpoint)
        #expect(store.outputProfiles.isEmpty && store.usableProfile(audio: audio, instrument: InstrumentProfile()) == nil)
        #expect(store.profiles == [candidate]) // No rewriting historical instrument evidence.
        #expect(model.timelines.count == 2)
    }
    @Test func failedApplyCanRetryButCandidateCannotCrossRouteRevision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, _) = await setup(directory)
        let repository = SynchronizationRepository(), store = CalibrationStore(repository: repository)
        await store.load(); let model = store.wizard
        model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
        try await waitForRequest(runtime, model: model)
        await runtime.finish(); try await waitForCompletion(model)
        await model.apply(audio: audio, store: store, instrument: InstrumentProfile())
        #expect(store.profiles.isEmpty && model.messageKey == "calibration.storageSave")
        await repository.allowWrites(); await model.apply(audio: audio, store: store, instrument: InstrumentProfile())
        #expect(store.usableProfile(audio: audio, instrument: InstrumentProfile()) != nil)
        await audio.coordinator.suspend(); await audio.publish()
        await model.apply(audio: audio, store: store, instrument: InstrumentProfile())
        #expect(model.messageKey == "sync.routeChanged" && model.candidate == nil)
        #expect(!model.timelines.isEmpty)
    }
    @Test func failedInstrumentDiagnosticsAndTimelinesSurviveStopAndCancellation() async throws {
        for kind in ["count", "spread", "clock", "pitch", "clip", "data", "route", "cancel"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let (runtime, audio, store) = await setup(directory); let model = store.wizard
            model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
            try await waitForRequest(runtime, model: model)
            switch kind {
            case "pitch": await runtime.finish(wrongPitch: true)
            case "clip": await runtime.finish(clipped: true)
            case "route": await runtime.changeRoute(); await audio.refresh()
            case "cancel": model.cancel(audio: audio)
            default: await runtime.failPass(kind)
            }
            try await waitForCompletion(model)
            #expect(model.candidate == nil && store.profiles.isEmpty && model.stage == .ready)
            #expect(!model.timelines.isEmpty && model.timelines[0].cursor == nil)
            if ["count", "spread", "clock"].contains(kind) {
                #expect(model.failure?.reason.rawValue == (kind == "clock" ? "clockDrift" : kind))
                #expect(model.diagnostics?.measuredAttacks == (kind == "count" ? 15 : 16))
            }
            if kind == "pitch" { #expect(model.failure?.reason == .wrongNotes && model.diagnostics?.wrongAttacks == 16) }
            if kind == "clip" { #expect(model.failure?.reason == .clipping) }
            if kind == "data" { #expect(model.audioError == .dataLoss) }
            if kind == "route" { #expect(model.audioError == .routeChanged) }
            if kind == "cancel" { #expect(model.timelines[0].status == .cancelled) }
            #expect(await audio.coordinator.snapshot().captureRequestID == nil)
        }
    }
    @Test func changingOutputAfterMeasurementCannotApplyAStaleInstrumentCandidate() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory); let model = store.wizard
        model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
        try await waitForRequest(runtime, model: model); await runtime.finish(); try await waitForCompletion(model)
        let output = try OutputAlignmentProfile(output: try #require(audio.state?.outputEndpoint), evidence: try SyncPassEvidence(offset: 0.1, spread: 0, drift: 0))
        #expect(await store.saveOutput(output))
        await model.apply(audio: audio, store: store, instrument: InstrumentProfile())
        #expect(model.candidate == nil && model.messageKey == "sync.routeChanged" && store.profiles.isEmpty)
    }
    @Test func rejectedOrCancelledOutputKeepsTraceWithoutSaving() async throws {
        for failure in ["missing", "extra", "timestamp", "cancel", "overflow"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let (runtime, audio, store) = await setup(directory, outputOnly: true), model = store.wizard
            model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3, source: .taps)
            try await waitForRequest(runtime, model: model)
            let count = failure == "missing" ? 15 : failure == "overflow" ? 129 : 16
            for beat in 0..<count { model.tap(hostSeconds: 104.1 + Double(beat)) }
            switch failure {
            case "extra": model.tap(hostSeconds: 119.3)
            case "timestamp": model.tap(hostSeconds: 119)
            case "cancel": model.cancel(audio: audio)
            default: break
            }
            await runtime.finish(); try await waitForCompletion(model)
            #expect(model.outputCandidate == nil && store.outputProfiles.isEmpty && store.profiles.isEmpty)
            #expect(!model.timelines[0].events.isEmpty && model.timelines[0].events.count <= 128)
            if failure == "missing" || failure == "extra" { #expect(model.failure?.reason == .count) }
            if failure == "timestamp" { #expect(model.failure?.reason == .timestamps) }
            if failure == "overflow" { #expect(model.failure?.reason == .dataLoss) }
            if failure == "cancel" { #expect(model.timelines[0].status == .cancelled) }
            #expect(await runtime.inputStarts == 0)
        }
    }

    @Test func negativeMeasurementsRemainDiagnosticAndCannotBeApplied() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory), model = store.wizard
        try await outputMeasurement(runtime, audio: audio, store: store, offset: -0.02)
        let output = try #require(model.outputCandidate)
        #expect(output.seconds < 0 && !output.isNonnegativeSetting)
        let outputTrace = model.timelines
        await model.applyOutput(audio: audio, store: store)
        #expect(store.outputProfiles.isEmpty && model.timelines == outputTrace)
        #expect(model.messageKey == "sync.nonnegative.measurement")
        model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
        try await waitForRequest(runtime, model: model)
        await runtime.finish(offset: -0.02); try await waitForCompletion(model)
        let guitar = try #require(model.candidate)
        #expect(guitar.remainingInstrumentOffset < 0 && !guitar.isNonnegativeSetting)
        let guitarTrace = model.timelines
        await model.apply(audio: audio, store: store, instrument: InstrumentProfile())
        #expect(store.profiles.isEmpty && model.timelines == guitarTrace)
        #expect(model.messageKey == "sync.nonnegative.measurement")
    }

    @Test func oldNegativeSettingsRemainReadableButCannotBeReactivated() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, audio, _) = await setup(directory), repository = LocalRepository(root: directory)
        let route = try #require(audio.state?.calibrationRoute)
        let output = try OutputAlignmentProfile(output: route.output, manual: ManualOutputAlignment(seconds: -0.02, reference: .additional))
        let evidence = try ManualInstrumentSyncEvidence(instrument: InstrumentProfile(), outputSetting: output, remainingOffset: -0.03)
        let profile = try CalibrationProfile(route: route, method: .manualPersonal, residualOffsetSeconds: evidence.offset,
            uncertaintySeconds: ManualInstrumentSyncEvidence.scoringAllowance, manualInstrumentEvidence: evidence)
        try await repository.saveOutputAlignment(output)
        try await repository.saveCalibration(profile, replacing: nil)
        let store = CalibrationStore(repository: repository); await store.load()
        #expect(store.storedOutputProfile(for: route.output) == output && store.outputProfile(for: route.output) == nil)
        #expect(store.profile(for: route) == profile)
        store.confirm(profile, session: audio.synchronizationSession, revision: try #require(audio.state?.routeRevision))
        #expect(store.usableProfile(audio: audio, instrument: InstrumentProfile()) == nil)
        #expect(await store.saveOutput(output) == false)
        #expect(await store.save(profile) == false)
        await store.wizard.applyManualOutput(output, audio: audio, store: store)
        await store.wizard.applyManualInstrument(-0.03, audio: audio, store: store, instrument: InstrumentProfile())
        #expect(store.wizard.messageKey == "sync.manual.invalid")
        #expect(try await repository.loadOutputAlignments() == [output])
        #expect(try await repository.loadCalibrationProfiles() == [profile])
        await store.resetOutput(route.output)
        #expect(store.storedOutputProfile(for: route.output) == nil)
        for seconds in [0.0, 1.0] {
            await store.wizard.applyManualInstrument(seconds, audio: audio, store: store, instrument: InstrumentProfile())
            #expect(store.usableProfile(audio: audio, instrument: InstrumentProfile())?.remainingInstrumentOffset == seconds)
        }
    }

    @Test func manualValuesApplyWithoutARecordedPassAndRetainFailureDiagnostics() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory), model = store.wizard
        let output = try OutputAlignmentProfile(output: #require(audio.state?.outputEndpoint), manual: ManualOutputAlignment(seconds: 0.2, reference: .additional))
        await model.applyManualOutput(output, audio: audio, store: store)
        #expect(store.outputProfiles == [output])
        #expect(await runtime.inputStarts == 0)
        model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
        try await waitForRequest(runtime, model: model)
        await runtime.failPass("count"); try await waitForCompletion(model)
        let trace = model.timelines
        #expect(model.candidate == nil && model.failure?.reason == .count)
        await model.applyManualInstrument(0.05, audio: audio, store: store, instrument: InstrumentProfile())
        let profile = try #require(store.usableProfile(audio: audio, instrument: InstrumentProfile()))
        #expect(profile.method == .manualPersonal && abs(profile.residualOffsetSeconds - 0.25) < 1e-9)
        #expect(profile.manualInstrumentEvidence?.outputSetting == output && profile.instrumentEvidence == nil)
        #expect(model.timelines == trace && model.failure?.reason == .count)
        let reopened = CalibrationStore(repository: LocalRepository(root: directory)); await reopened.load()
        #expect(reopened.profiles == [profile] && reopened.outputProfiles == [output])
        #expect(reopened.usableProfile(audio: audio, instrument: InstrumentProfile()) == nil)
        await reopened.wizard.applyManualInstrument(0.05, audio: audio, store: reopened, instrument: InstrumentProfile())
        #expect(reopened.usableProfile(audio: audio, instrument: InstrumentProfile())?.method == .manualPersonal)
        await reopened.resetOutput(audio.state?.outputEndpoint)
        #expect(reopened.usableProfile(audio: audio, instrument: InstrumentProfile()) == nil)
    }

}
