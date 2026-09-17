import AVFoundation
import Testing
import Yams
import Domain
@testable import Learning
@testable import Audio
@testable import PersonalGuitarCoach

private enum SelfRecordingFixture {
    static func context(tuning: TuningProfile = .cStandard, frets: GuitarFretCount = .twentyFour) throws -> SelfPracticeRecordingContext {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Lessons/fingerstyle-bass-melody")
        func read<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            try YAMLDecoder().decode(T.self, from: String(contentsOf: root.appendingPathComponent(name + ".yml"), encoding: .utf8))
        }
        let lesson = try LoadedLesson(manifest: read("lesson", as: LessonManifest.self), english: read("en", as: LessonText.self), ukrainian: read("uk", as: LessonText.self))
        let snapshot = try lesson.resolveActivity(id: "two-line-study", instrument: InstrumentProfile(tuning: tuning, frets: frets))
        return try SelfPracticeRecordingContext(snapshot: snapshot, exercise: #require(snapshot.exercises.first))
    }
    static func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("self-recording-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
}

private struct SelfRecordingPermission: AudioPermissionProviding {
    var authorized = true
    func status() -> AudioPermissionStatus { authorized ? .authorized : .denied }
    func request() -> Bool { false }
}
/// Synthetic monotonic clock/capture. Never opens a device or microphone.
private actor SelfRecordingRuntime: AudioRuntime {
    var request: TransportRequest?
    var complete = false
    var dropped = false
    var invalidRecording = false
    var available = true
    var pauseEnding = false
    var endingContinuation: CheckedContinuation<Void, Never>?
    var begins = 0
    var ends = 0
    var frames: UInt64 = 0
    let epoch = 101.0
    func devices() -> [AudioDeviceDescriptor] {
        available ? [AudioDeviceDescriptor(hardwareID: 1, uid: "self-recording", name: "Synthetic self practice", inputChannels: 1,
            outputChannels: 1, sampleRate: 48000, bufferFrames: 512)] : []
    }
    func capabilities(device: AudioDeviceDescriptor, channel: Int) -> AudioDeviceCapabilities {
        AudioDeviceCapabilities(sampleRates: [48000...48000], bufferRange: 512...512, canSetSampleRate: false, canSetBufferFrames: false, inputGain: nil)
    }
    func startInput(device: AudioDeviceDescriptor, channel: Int) -> AudioStreamFormat {
        frames = 0; return AudioStreamFormat(sampleRate: 48000, inputChannels: 1)
    }
    func stopInput() {}
    func readInput() -> CaptureSnapshot? {
        frames += 512
        return CaptureSnapshot(totalFrames: frames, totalPackets: frames / 512, droppedPackets: dropped ? 1 : 0,
            peak: 0.2, rms: 0.1, sampleRate: 48000, lastHostTime: AVAudioTime.hostTime(forSeconds: 100 + Double(frames) / 48000), hostTimeValid: true, lastPacketFrames: 512)
    }
    func beginRecording() { begins += 1 }
    func endRecording() async throws -> PracticeRecording {
        ends += 1
        if invalidRecording { throw AudioBackendError.dataLoss }
        let plan = try TransportPlan(request: #require(request), sampleRate: 48000)
        let samples = [Float](repeating: 0.125, count: Int(plan.endFrame ?? 0) + 24000)
        if pauseEnding { await withCheckedContinuation { endingContinuation = $0 } }
        return PracticeRecording(samples: samples, sampleRate: 48000, firstHostSeconds: epoch - 0.25)
    }
    func startClick(device: AudioDeviceDescriptor, channel: Int) {}
    func stopClick() {}
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) {}
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) {}
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) {}
    func startTransport(device: AudioDeviceDescriptor, channel: Int, request: TransportRequest) { self.request = request }
    func readTransport() -> TransportPlaybackSnapshot? {
        guard let request, let plan = try? TransportPlan(request: request, sampleRate: 48000) else { return nil }
        let frame = complete ? (plan.endFrame ?? 0) : plan.practiceStartFrame + 128
        return TransportPlaybackSnapshot(requestID: request.id, phase: complete ? .completed : .playing, position: plan.position(at: frame),
            sampleRate: 48000, renderedFrames: frame, scheduledStartHostSeconds: epoch, renderAnchorHostSeconds: epoch, presentationLatency: 0)
    }
    func stopTransport() { request = nil }
    func delayEnding() { pauseEnding = true }
    func releaseEnding() { endingContinuation?.resume(); endingContinuation = nil }
    func finish() { complete = true }
    func losePackets() { dropped = true }
    func failRecording() { invalidRecording = true }
    func unplug() { available = false }
}

@MainActor struct SelfPracticeRecordingTests {
    private func harness(authorized: Bool = true) async throws -> (SelfPracticeRecordingModel, AudioSessionCoordinator, SelfRecordingRuntime) {
        let runtime = SelfRecordingRuntime(), coordinator = AudioSessionCoordinator(runtime: runtime, permissions: SelfRecordingPermission(authorized: authorized))
        await coordinator.configure(try AudioRouteSelection(inputUID: "self-recording", outputUID: "self-recording"))
        return (SelfPracticeRecordingModel(), coordinator, runtime)
    }
    private func wait(until condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await condition()), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(await condition())
    }
    @Test func resolvedContextsKeepInstrumentAndNeverAddGradingOrGuitarReference() throws {
        for tuning in TuningProfile.presets {
            for frets in GuitarFretCount.allCases {
                let context = try SelfRecordingFixture.context(tuning: tuning, frets: frets)
                let request = try context.transport(bpm: 60)
                #expect(context.snapshot.instrument == InstrumentProfile(tuning: tuning, frets: frets))
                #expect(request.exercise.assessmentMode == .displayOnly && request.mode == .practice && request.toneVolume == 0)
                #expect(request.countInBars == 1 && !request.loops && request.clickEnabled)
                #expect(request.range == 0..<context.exercise.durationTicks)
                #expect(context.snapshot.sourceMappings.count == 1)
                #expect(throws: (any Error).self) { try context.transport(bpm: .nan) }
                #expect(throws: (any Error).self) { try context.transport(bpm: context.exercise.maximumBPM + 1) }
            }
        }
    }
    @Test func completedTakeExportsReadableStereoWAVWithFrozenContextAndNoScore() async throws {
        let context = try SelfRecordingFixture.context(), (model, coordinator, runtime) = try await harness()
        model.start(context: context, bpm: 60, coordinator: coordinator, outputAlignment: nil)
        try await wait { model.phase == .recording }
        #expect(model.displayTick != nil && model.take == nil)
        await runtime.finish()
        try await wait { !model.isBusy }
        let take = try #require(model.take)
        #expect(model.phase == .review && take.metadata.completed && model.savedURL == nil)
        #expect(take.metadata.exercise == context.exercise && take.metadata.instrument.tuning == .cStandard)
        #expect(take.metadata.kind == "self-practice-ungraded" && !take.metadata.assessmentCalibrationApplied)
        #expect(await runtime.begins == 1)
        #expect(await runtime.ends == 1)
        #expect(await coordinator.snapshot().captureRequestID == nil)
        let directory = try SelfRecordingFixture.directory(); defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("quoted ' $() запис.wav")
        try Data("old file".utf8).write(to: url)
        await model.save(to: url)
        #expect(model.savedURL == url && model.errorKey == nil && !model.saving)
        let file = try AVAudioFile(forReading: url)
        #expect(file.processingFormat.channelCount == 2 && file.processingFormat.sampleRate == 48000)
        #expect(file.length == take.metadata.sampleCount)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 24000))
        try file.read(into: buffer)
        let channels = try #require(buffer.floatChannelData)
        #expect((0..<24000).allSatisfy { channels[0][$0] == 0.125 })
        #expect((0..<12000).allSatisfy { channels[1][$0] == 0 })
        #expect((12000..<12600).contains { abs(channels[1][$0]) > 0.01 })
        let data = try Data(contentsOf: url)
        func uint(_ offset: Int) -> Int { (0..<4).reduce(0) { $0 | (Int(data[offset + $1]) << (8 * $1)) } }
        #expect(uint(4) == data.count - 8)
        var offset = 12, chunks: [Data] = []
        while offset + 8 <= data.count {
            let size = uint(offset + 4)
            try #require(offset + 8 + size <= data.count)
            if data.subdata(in: offset..<offset + 4) == Data("pgcx".utf8) { chunks.append(data.subdata(in: offset + 8..<offset + 8 + size)) }
            offset += 8 + size + size % 2
        }
        #expect(chunks.count == 1 && offset == data.count)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(SelfPracticeTakeMetadata.self, from: #require(chunks.first))
        #expect(metadata.schemaVersion == 1 && metadata.id == take.metadata.id && metadata.completed)
        #expect(metadata.exercise == context.exercise && metadata.sourceMappings == context.snapshot.sourceMappings)
        #expect(metadata.bpm == 60 && metadata.sampleCount == file.length && metadata.countInBars == 1)
        #expect(metadata.route.inputUID == "self-recording" && metadata.outputAlignment == nil)
        let json = try #require(JSONSerialization.jsonObject(with: chunks[0]) as? [String: Any])
        #expect(json["score"] == nil && json["assessment"] == nil)
    }
    @Test func stopAndCancelHaveDistinctOutcomesAndOnlyReleaseTheirOwnCapture() async throws {
        let context = try SelfRecordingFixture.context(), (model, coordinator, runtime) = try await harness()
        model.start(context: context, bpm: 60, coordinator: coordinator, outputAlignment: nil)
        try await wait { model.phase == .recording }
        model.stopAndReview(); try await wait { !model.isBusy }
        #expect(model.take?.metadata.completed == false && model.phase == .review)
        model.start(context: context, bpm: 60, coordinator: coordinator, outputAlignment: nil)
        try await wait { model.phase == .recording }
        model.cancel(); try await wait { !model.isBusy }
        #expect(model.take == nil && model.phase == .idle)
        #expect(await runtime.ends == 1)
        #expect(await runtime.begins == 2)
        let owner = UUID(); try await coordinator.start(purpose: .tuner, requestID: owner)
        model.cancel()
        #expect(await coordinator.snapshot().captureRequestID == owner)
        model.start(context: context, bpm: 60, coordinator: coordinator, outputAlignment: nil)
        try await wait { !model.isBusy }
        #expect(model.phase == .failed && model.take == nil)
        #expect(await coordinator.snapshot().captureRequestID == owner)
        await coordinator.stopCapture(requestID: owner)
    }
    @Test func lateRecordingCompletionAfterCancellationCannotPublishOrStopANewOwner() async throws {
        let context = try SelfRecordingFixture.context(), (model, coordinator, runtime) = try await harness()
        await runtime.delayEnding()
        model.start(context: context, bpm: 60, coordinator: coordinator, outputAlignment: nil)
        try await wait { model.phase == .recording }
        model.stopAndReview()
        try await wait { await runtime.endingContinuation != nil }
        model.cancel()
        try await wait { await coordinator.snapshot().captureRequestID == nil }
        #expect(model.isBusy && model.take == nil)
        let later = UUID()
        try await coordinator.start(purpose: .tuner, requestID: later)
        await runtime.releaseEnding()
        try await wait { !model.isBusy }
        #expect(model.phase == .idle && model.take == nil)
        #expect(await coordinator.snapshot().captureRequestID == later)
        await coordinator.stopCapture(requestID: later)
    }

    @Test func deniedLostChangedOrInvalidCaptureNeverProducesATake() async throws {
        let context = try SelfRecordingFixture.context()
        for failure in 0..<5 {
            let (model, coordinator, runtime) = try await harness(authorized: failure != 0)
            model.start(context: context, bpm: 60, coordinator: coordinator, outputAlignment: nil)
            if failure != 0 {
                try await wait { model.phase == .recording }
                switch failure {
                case 1: await runtime.losePackets()
                case 2: await coordinator.configure(.unselected)
                case 3: await runtime.failRecording(); model.stopAndReview()
                default: await runtime.unplug(); await coordinator.refresh()
                }
            }
            try await wait { !model.isBusy }
            #expect(model.phase == .failed && model.take == nil && model.savedURL == nil)
            #expect(model.backendError != nil && model.errorKey == "selfRecording.failed")
            #expect(await coordinator.snapshot().captureRequestID == nil)
        }
    }
    @Test func exportFailurePreservesExistingFileAndDoesNotMarkSaved() async throws {
        let context = try SelfRecordingFixture.context(), (model, coordinator, _) = try await harness()
        model.start(context: context, bpm: 60, coordinator: coordinator, outputAlignment: nil)
        try await wait { model.phase == .recording }
        model.stopAndReview(); try await wait { !model.isBusy }
        let directory = try SelfRecordingFixture.directory(); defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("existing.wav")
        try Data("keep me".utf8).write(to: destination)
        let state = await coordinator.snapshot(), request = try context.transport(bpm: 60)
        let malformed = try SelfPracticeTake(context: context, recording: PracticeRecording(samples: [.nan], sampleRate: 48000, firstHostSeconds: 101),
            transport: request, epoch: 101, route: state, outputAlignment: nil, completed: false, capturedAt: Date())
        #expect(throws: CoachFileError.invalid) { try malformed.export(to: destination) }
        #expect(try Data(contentsOf: destination) == Data("keep me".utf8))
        #expect(throws: CoachFileError.invalid) { try SelfPracticeTake(context: context,
            recording: PracticeRecording(samples: [0.1], sampleRate: 48000, firstHostSeconds: 101), transport: request,
            epoch: 101, route: state, outputAlignment: nil, completed: true, capturedAt: Date()) }
        await model.save(to: directory.appendingPathComponent("missing/recording.wav"))
        #expect(model.errorKey == "selfRecording.saveFailed" && model.savedURL == nil && model.take != nil && !model.saving)
    }
}
