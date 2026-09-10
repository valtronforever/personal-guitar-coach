import Foundation
import AVFAudio
import Testing
import Domain
import Learning
import Persistence
@testable import Audio
@testable import PersonalGuitarCoach

private struct PracticePermissionStub: AudioPermissionProviding {
    func status() -> AudioPermissionStatus { .authorized }
    func request() -> Bool { false }
}
private actor PracticeRuntimeStub: AudioRuntime {
    enum Stage { case countIn, playing, completed }
    var request: TransportRequest?
    var stage = Stage.countIn
    var epoch = 101.0
    var frames: UInt64 = 0
    var events: [DetectedNoteEvent] = []
    var spans: [SignalQualitySpan] = []
    var emitted: Set<String> = []
    var available = true
    var testSignal = true
    var silentPractice = false
    var inputStarts = 0
    var transportStarts = 0
    func devices() -> [AudioDeviceDescriptor] {
        available ? [AudioDeviceDescriptor(hardwareID: 1, uid: "practice-test", name: "Synthetic practice route", inputChannels: 1,
            outputChannels: 1, sampleRate: 48000, bufferFrames: 512)] : []
    }
    func capabilities(device: AudioDeviceDescriptor, channel: Int) -> AudioDeviceCapabilities {
        AudioDeviceCapabilities(sampleRates: [48000...48000], bufferRange: 512...512,
            canSetSampleRate: false, canSetBufferFrames: false, inputGain: nil)
    }
    func startInput(device: AudioDeviceDescriptor, channel: Int) -> AudioStreamFormat {
        inputStarts += 1; frames = 0; events = []; spans = []
        if testSignal { append(host: 100.1, frequency: 82.4) }
        return AudioStreamFormat(sampleRate: 48000, inputChannels: 1)
    }
    func stopInput() {}
    func startClick(device: AudioDeviceDescriptor, channel: Int) {}
    func stopClick() {}
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) {}
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) {}
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) {}
    func time(_ host: Double) -> AnalysisTimestamp {
        AnalysisTimestamp(frame: Int64(((host - 100) * 48000).rounded()), sampleRate: 48000, hostSeconds: host)
    }
    func append(host: Double, frequency: Double) {
        events.append(DetectedNoteEvent(id: UInt64(events.count + 1), onset: time(host), resolvedAt: time(host + 0.3),
            quality: .reliable, pitch: DetectedPitch(frequency: frequency, clarity: 0.99)))
    }
    func readInput() -> CaptureSnapshot? {
        var desired = 100.5
        if let request, let plan = try? TransportPlan(request: request, sampleRate: 48000) {
            switch stage {
            case .countIn: desired = epoch + 0.2
            case .playing: desired = epoch + Double(plan.practiceStartFrame) / 48000 + 0.6
            case .completed: desired = epoch + Double(plan.endFrame ?? 0) / 48000 + 0.8
            }
        }
        frames = max(frames + 512, UInt64(max(512, (desired - 100) * 48000)))
        let host = 100 + Double(frames) / 48000
        let quality: SignalQuality = testSignal && (request == nil || stage == .playing) ? .reliable : .silence
        if let previous = spans.last, previous.quality == quality {
            spans[spans.count - 1] = SignalQualitySpan(id: previous.id, quality: quality, start: previous.start, end: time(host))
        } else { spans.append(SignalQualitySpan(id: UInt64(spans.count + 1), quality: quality, start: time(host - 0.3), end: time(host))) }
        let latest = PitchObservation(time: time(host), quality: quality, pitch: quality == .reliable ? DetectedPitch(frequency: 82.4, clarity: 0.99) : nil,
            rms: quality == .reliable ? 0.1 : 0, peak: quality == .reliable ? 0.2 : 0, noiseFloor: 0.0003, periodEvidence: nil)
        let analysis = AudioAnalysisSnapshot(algorithmVersion: MonophonicAnalyzer.algorithmVersion, latest: latest, events: events,
            totalEvents: UInt64(events.count), invalidSamples: 0, qualitySpans: spans, totalQualitySpans: UInt64(spans.count))
        return CaptureSnapshot(totalFrames: frames, totalPackets: frames / 512, droppedPackets: 0, peak: 0.2, rms: 0.1,
            sampleRate: 48000, lastHostTime: AVAudioTime.hostTime(forSeconds: host - 512.0 / 48000),
            hostTimeValid: true, analysis: analysis, lastPacketFrames: 512)
    }
    func startTransport(device: AudioDeviceDescriptor, channel: Int, request: TransportRequest) {
        self.request = request; stage = .countIn; epoch = 100 + Double(frames) / 48000 + 0.5
        emitted = []; transportStarts += 1
        append(host: epoch + 0.5, frequency: 82.4) // A count-in attack must never become a practice attack.
    }
    func stopTransport() { request = nil }
    func readTransport() -> TransportPlaybackSnapshot? {
        guard let request, let plan = try? TransportPlan(request: request, sampleRate: 48000) else { return nil }
        let frame: Int64
        switch stage { case .countIn: frame = 0; case .playing: frame = plan.practiceStartFrame + 100; case .completed: frame = plan.endFrame ?? 0 }
        return TransportPlaybackSnapshot(requestID: request.id, phase: stage == .completed ? .completed : .playing,
            position: plan.position(at: frame), sampleRate: 48000, renderedFrames: frame,
            scheduledStartHostSeconds: epoch, renderAnchorHostSeconds: epoch, presentationLatency: 0)
    }
    func advance(_ stage: Stage) throws {
        self.stage = stage
        guard !silentPractice, let request else { return }
        let notes = try request.exercise.resolvedEvents(instrument: request.tuning).filter { $0.event.kind == .note && request.range.contains($0.event.startTick) }
        let selected = stage == .playing ? Array(notes.prefix(1)) : notes
        let plan = try TransportPlan(request: request, sampleRate: 48000)
        for note in selected where !emitted.contains(note.id) {
            let tick = note.event.startTick - request.range.lowerBound
            let host = epoch + Double(plan.practiceStartFrame) / 48000 + Double(tick) / 960 * 60 / request.bpm + 0.03
            append(host: host, frequency: try note.pitches[0].frequency()); emitted.insert(note.id)
        }
    }
    func setTestSignal(_ value: Bool) { testSignal = value }
    func setSilentPractice(_ value: Bool) { silentPractice = value }
    func unplug() { available = false }
}

@MainActor struct PracticeModelTests {
    private struct Harness {
        let directory: URL
        let model: PracticeModel
        let runtime: PracticeRuntimeStub
        let audio: AudioSessionStore
    }
    private func harness() async throws -> Harness {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = LocalRepository(root: directory), runtime = PracticeRuntimeStub()
        let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PracticePermissionStub())
        let audio = AudioSessionStore(repository: repository, coordinator: coordinator)
        await audio.load(); await audio.select(inputUID: "practice-test", outputUID: "practice-test")
        let calibration = CalibrationStore(repository: repository); await calibration.load()
        let model = PracticeModel(audio: audio, calibration: calibration)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let lesson = try #require(LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons.first)
        let exerciseID = try #require(lesson.manifest.practiceExerciseIDs.first)
        let practiceRequest: PracticeRequest? = PracticeRequest(lesson: lesson, exerciseID: exerciseID)
        let unwrapped = try #require(practiceRequest)
        model.configure(unwrapped); model.physicallyTuned = true
        return Harness(directory: directory, model: model, runtime: runtime, audio: audio)
    }
    private func wait(_ harness: Harness, seconds: Double = 5, until condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        while !(await condition()), ContinuousClock.now < deadline {
            await harness.audio.coordinator.poll(); await harness.audio.publish()
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(await condition())
    }
    private func playing(_ harness: Harness) async throws {
        try await wait(harness) { (await harness.runtime.request != nil) && harness.model.phase == .countIn }
        try await harness.runtime.advance(.playing)
        try await wait(harness) { harness.model.phase == .running }
    }
    @Test func repeatsAreIndependentAndHealthySilenceAfterPreflightIsCompletedEvidence() async throws {
        let h = try await harness(); defer { try? FileManager.default.removeItem(at: h.directory) }
        var attempts: [PracticeEvidence] = []
        let repository = LocalRepository(root: h.directory), assessment = AssessmentStore(repository: LocalRepository(root: h.directory))
        h.model.onAttemptFinished = { evidence in
            attempts.append(evidence)
            #expect(await assessment.receive(evidence))
        }
        h.model.setRepeat(true); h.model.start(instrument: InstrumentProfile())
        try await playing(h); try await h.runtime.advance(.completed)
        try await wait(h) { h.model.completedCount == 1 && h.model.phase == .countIn }
        await h.runtime.setSilentPractice(true); h.model.setRepeat(false)
        try await playing(h); try await h.runtime.advance(.completed)
        try await wait(h) { !h.model.isBusy }
        try #require(attempts.count == 2)
        #expect(attempts[0].id != attempts[1].id)
        #expect(attempts[0].configuration.lesson?.id == h.model.request?.lessonID)
        #expect(attempts[0].maximumClockDriftSeconds != nil && attempts[1].maximumClockDriftSeconds != nil)
        #expect(attempts[0].attacks.count == h.model.request?.exercise.noteCount)
        #expect(attempts[1].attacks.isEmpty && attempts[1].signalConfirmed && attempts[1].phase == .completed)
        #expect(await h.runtime.inputStarts == 1)
        #expect(await h.runtime.transportStarts == 2)
        let stored = try await repository.history()
        #expect(stored.issues.isEmpty && stored.records.count == 2)
        let silent = try #require(stored.records.first { $0.id == attempts[1].id })
        #expect(silent.result.payload.validity == .uncalibrated && silent.result.payload.pitchScore == 0)
        #expect(silent.assessment?.payload.evidence == attempts[1])
    }
    @Test func pauseRetryAndInstrumentChangeDoNotCarryAttacksOrMutateSnapshots() async throws {
        let h = try await harness(); defer { try? FileManager.default.removeItem(at: h.directory) }
        h.model.start(instrument: InstrumentProfile()); try await playing(h)
        let previousID = h.model.machine.attemptID
        h.model.pause(); try await wait(h) { !h.model.isBusy }
        let previous = try #require(h.model.latestEvidence)
        #expect(previous.phase == .paused && previous.attacks.count == 1)
        h.model.start(instrument: InstrumentProfile())
        try await wait(h) { (await h.runtime.request != nil) && h.model.phase == .countIn }
        #expect(h.model.machine.attemptID != previousID)
        h.model.instrumentWillChange(InstrumentProfile(tuning: .dropD))
        try await wait(h) { !h.model.isBusy }
        #expect(h.model.latestEvidence?.phase == .interrupted && h.model.latestEvidence?.reason == .changedInstrument)
        #expect(h.model.latestEvidence?.attacks.isEmpty == true && !h.model.physicallyTuned)
        #expect(h.model.latestEvidence?.configuration.instrument.tuning == .standard)
        #expect(previous.configuration.instrument.tuning == .standard)
    }
    @Test func failedSignalCheckAndMissingPhysicalConfirmationNeverStartTheMetronome() async throws {
        let h = try await harness(); defer { try? FileManager.default.removeItem(at: h.directory) }
        h.model.physicallyTuned = false; h.model.start(instrument: InstrumentProfile())
        #expect(h.model.phase == .preflightFailed && h.model.machine.reason == .tuningNotConfirmed)
        #expect(await h.runtime.inputStarts == 0)
        h.model.physicallyTuned = true; await h.runtime.setTestSignal(false)
        h.model.start(instrument: InstrumentProfile())
        try await wait(h, seconds: 12) { !h.model.isBusy }
        #expect(h.model.phase == .preflightFailed && h.model.machine.reason == .noTestSignal)
        #expect(h.model.latestEvidence?.signalConfirmed == false)
        #expect(await h.runtime.transportStarts == 0)
    }
    @Test func tempoAndSameBarSeekInterruptBeforeChangingControls() async throws {
        let h = try await harness(); defer { try? FileManager.default.removeItem(at: h.directory) }
        for seek in [false, true] {
            h.model.start(instrument: InstrumentProfile()); try await playing(h)
            let frozen = try #require(h.model.machine.configuration)
            if seek { h.model.seekBar(h.model.firstBar, extending: false) } else { h.model.setTempo(61) }
            #expect(h.model.phase == .interrupted)
            #expect(h.model.machine.configuration == frozen)
            try await wait(h) { !h.model.isBusy }
            #expect(h.model.latestEvidence?.reason == (seek ? .changedRange : .changedTempo))
        }
    }
    @Test func leavingTheExerciseCancelsOwnershipAndDoesNotShowTheOldAttemptOnTheNewScreen() async throws {
        let h = try await harness(); defer { try? FileManager.default.removeItem(at: h.directory) }
        var finished: PracticeEvidence?
        h.model.onAttemptFinished = { finished = $0 }
        h.model.start(instrument: InstrumentProfile()); try await playing(h)
        h.model.configure(nil)
        try await wait(h) { !h.model.isBusy }
        #expect(h.model.request == nil && h.model.phase == .idle && h.model.latestEvidence == nil)
        #expect(finished?.phase == .interrupted && finished?.reason == .changedExercise)
        #expect(await h.audio.coordinator.snapshot().captureRequestID == nil)
    }
    @Test func unplugDuringFinalDrainCannotProduceCompletion() async throws {
        let h = try await harness(); defer { try? FileManager.default.removeItem(at: h.directory) }
        h.model.start(instrument: InstrumentProfile()); try await playing(h)
        try await h.runtime.advance(.completed)
        try await wait(h) { h.model.phase == .finalizing }
        await h.runtime.unplug(); await h.audio.coordinator.refresh()
        try await wait(h) { !h.model.isBusy }
        #expect(h.model.latestEvidence?.phase == .interrupted && h.model.completedCount == 0)
        #expect(h.model.latestEvidence?.reason == .routeChanged)
    }
}
