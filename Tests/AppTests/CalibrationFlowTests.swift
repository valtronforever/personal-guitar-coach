import Foundation
import AVFAudio
import Testing
import Domain
import Persistence
@testable import Audio
@testable import PersonalGuitarCoach

private struct CalibrationPermission: AudioPermissionProviding {
    func status() -> AudioPermissionStatus { .authorized }
    func request() -> Bool { false }
}
private actor CalibrationRuntime: AudioRuntime {
    var request: TransportRequest?
    var complete = false
    var changed = false
    var reads: UInt64 = 0
    var wrongPitch = false
    var clipped = false
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
    func startInput(device: AudioDeviceDescriptor, channel: Int) -> AudioStreamFormat { complete = false; reads = 0; return AudioStreamFormat(sampleRate: 48000, inputChannels: 1) }
    func stopInput() {}
    func readInput() -> CaptureSnapshot? {
        reads += 1
        let frames: UInt64 = (complete ? 22 * 48000 : 48000) + reads * 512
        let events: [DetectedNoteEvent] = complete ? (request?.exercise.events.enumerated().map { index, event in
            let frame = Int64((Double(event.startTick) / 960 + 0.05) * 48000)
            let onset = AnalysisTimestamp(frame: frame, sampleRate: 48000, hostSeconds: 100.1 + Double(frame) / 48000)
            return DetectedNoteEvent(id: UInt64(index + 1), onset: onset, resolvedAt: onset, quality: .reliable, pitch: DetectedPitch(frequency: wrongPitch ? 440 : 195.99771799, clarity: 0.98))
        } ?? []) : []
        let now = AnalysisTimestamp(frame: Int64(frames), sampleRate: 48000, hostSeconds: 100.1 + Double(frames) / 48000)
        let before = AnalysisTimestamp(frame: Int64(frames) - 14400, sampleRate: 48000, hostSeconds: now.hostSeconds! - 0.3)
        let latest = PitchObservation(time: now, quality: .reliable, pitch: DetectedPitch(frequency: 195.99771799, clarity: 0.98),
                                     rms: 0.1, peak: 0.2, noiseFloor: 0.001, periodEvidence: nil)
        let span = SignalQualitySpan(id: 1, quality: .reliable, start: before, end: now)
        let analysis = AudioAnalysisSnapshot(algorithmVersion: MonophonicAnalyzer.algorithmVersion, latest: latest, events: events,
            totalEvents: UInt64(events.count), invalidSamples: 0, qualitySpans: [span], totalQualitySpans: 1)
        return CaptureSnapshot(totalFrames: frames, totalPackets: frames / 512, droppedPackets: 0, peak: complete && clipped ? 1 : 0.2, rms: 0.01,
            sampleRate: 48000, lastHostTime: AVAudioTime.hostTime(forSeconds: 100.1 + Double(frames - 512) / 48000),
            hostTimeValid: true, analysis: analysis, lastPacketFrames: 512)
    }
    func startClick(device: AudioDeviceDescriptor, channel: Int) {}
    func stopClick() {}
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) {}
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) {}
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) {}
    func startTransport(device: AudioDeviceDescriptor, channel: Int, request: TransportRequest) { self.request = request }
    func stopTransport() { request = nil }
    func readTransport() -> TransportPlaybackSnapshot? {
        guard let request else { return nil }
        return TransportPlaybackSnapshot(requestID: request.id, phase: complete ? .completed : .playing,
            position: TransportPosition(tick: complete ? request.exercise.durationTicks : 0, loopIndex: 0, countInBeat: nil, completed: complete),
            sampleRate: 48000, renderedFrames: complete ? 27 * 48000 : 0, scheduledStartHostSeconds: 100,
            renderAnchorHostSeconds: 100, presentationLatency: 0)
    }
    func finish(wrongPitch: Bool = false, clipped: Bool = false) { self.wrongPitch = wrongPitch; self.clipped = clipped; complete = true }
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
    private func setup(_ directory: URL) async -> (CalibrationRuntime, AudioSessionStore, CalibrationStore) {
        let repository = LocalRepository(root: directory), runtime = CalibrationRuntime()
        let audio = AudioSessionStore(repository: repository, coordinator: AudioSessionCoordinator(runtime: runtime, permissions: CalibrationPermission()))
        await audio.load(); await audio.select(inputUID: "test", outputUID: "test")
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
    @Test func twoPassesRequireApplyAndFreshnessDoesNotSurviveRelaunchOrSleep() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory)
        let model = CalibrationModel(), instrument = InstrumentProfile()
        for pass in 1...2 {
            model.start(audio: audio, store: store, instrument: instrument, string: 3)
            try await waitForRequest(runtime, model: model)
            await runtime.finish(); try await waitForCompletion(model)
            #expect(store.profiles.isEmpty)
            #expect(model.stage == (pass == 1 ? .between : .result))
            #expect(await audio.coordinator.snapshot().captureRequestID == nil)
        }
        let candidate = try #require(model.candidate)
        #expect(candidate.method == .personal && abs(candidate.residualOffsetSeconds - 0.05) < 0.001)
        #expect(candidate.evidence == nil && candidate.personalEvidence != nil)
        await model.apply(audio: audio, store: store, instrument: instrument)
        #expect(store.usableProfile(audio: audio, instrument: instrument) == candidate)
        #expect(store.usableProfile(audio: audio, instrument: InstrumentProfile(tuning: .cStandard)) == nil)
        let reopened = CalibrationStore(repository: LocalRepository(root: directory)); await reopened.load()
        #expect(reopened.profile(for: candidate.route) == candidate)
        #expect(reopened.usableProfile(audio: audio, instrument: instrument) == nil)
        await audio.coordinator.suspend(); await audio.publish()
        #expect(store.usableProfile(audio: audio, instrument: instrument) == nil)
    }
    @Test func failedApplyCanRetryButCandidateCannotCrossRouteRevision() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, _) = await setup(directory)
        let repository = SynchronizationRepository(), store = CalibrationStore(repository: repository)
        await store.load()
        let model = CalibrationModel(), instrument = InstrumentProfile()
        for _ in 1...2 {
            model.start(audio: audio, store: store, instrument: instrument, string: 3)
            try await waitForRequest(runtime, model: model)
            await runtime.finish(); try await waitForCompletion(model)
        }
        #expect(model.candidate != nil)
        await model.apply(audio: audio, store: store, instrument: instrument)
        #expect(store.profiles.isEmpty && store.usableProfile(audio: audio, instrument: instrument) == nil)
        #expect(model.messageKey == "calibration.storageSave")
        await repository.allowWrites()
        await model.apply(audio: audio, store: store, instrument: instrument)
        #expect(store.usableProfile(audio: audio, instrument: instrument) != nil)
        await audio.coordinator.suspend(); await audio.publish()
        await model.apply(audio: audio, store: store, instrument: instrument)
        #expect(model.messageKey == "sync.routeChanged" && model.candidate == nil)
        #expect(store.usableProfile(audio: audio, instrument: instrument) == nil)
    }
    @Test func firstPassCannotBeReusedWithChangedRoute() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let (runtime, audio, store) = await setup(directory)
        let model = CalibrationModel()
        model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
        try await waitForRequest(runtime, model: model)
        await runtime.finish(); try await waitForCompletion(model)
        #expect(model.stage == .between)
        await runtime.changeRoute(); await audio.refresh()
        model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
        #expect(!model.running && model.stage == .ready && model.messageKey == "sync.routeChanged")
        #expect(store.profiles.isEmpty)
    }
    @Test func routeChangeBadPitchClippingAndCancellationCannotSave() async throws {
        for mode in ["route", "pitch", "clip", "cancel"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let (runtime, audio, store) = await setup(directory)
            let old = try CalibrationProfile(route: #require(audio.state?.calibrationRoute), method: .manual, residualOffsetSeconds: 0.02, uncertaintySeconds: 1)
            #expect(await store.save(old))
            let model = CalibrationModel()
            model.start(audio: audio, store: store, instrument: InstrumentProfile(), string: 3)
            try await waitForRequest(runtime, model: model)
            switch mode {
            case "route": await runtime.changeRoute(); await audio.refresh()
            case "pitch": await runtime.finish(wrongPitch: true)
            case "clip": await runtime.finish(clipped: true)
            default: model.cancel(audio: audio)
            }
            try await waitForCompletion(model)
            #expect(model.candidate == nil && model.stage == .ready)
            #expect(store.profiles == [old])
            #expect(await audio.coordinator.snapshot().captureRequestID == nil)
        }
    }
}
