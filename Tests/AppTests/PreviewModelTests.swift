import Foundation
import Testing
import Domain
import Persistence
@testable import Audio
@testable import PersonalGuitarCoach

private actor PreviewRuntime: AudioRuntime {
    var request: TransportRequest?
    var value: TransportPlaybackSnapshot?
    func devices() -> [AudioDeviceDescriptor] {
        [AudioDeviceDescriptor(hardwareID: 1, uid: "output", name: "Test output", inputChannels: 0, outputChannels: 2, sampleRate: 48000, bufferFrames: 512)]
    }
    func capabilities(device: AudioDeviceDescriptor, channel: Int) throws -> AudioDeviceCapabilities { throw AudioBackendError.invalidChannel }
    func startInput(device: AudioDeviceDescriptor, channel: Int) throws -> AudioStreamFormat { throw AudioBackendError.invalidChannel }
    func stopInput() {}
    func readInput() -> CaptureSnapshot? { nil }
    func startClick(device: AudioDeviceDescriptor, channel: Int) {}
    func stopClick() {}
    func setSampleRate(_ rate: Double, device: AudioDeviceDescriptor) {}
    func setBufferFrames(_ frames: UInt32, device: AudioDeviceDescriptor) {}
    func setInputGain(_ value: Float, device: AudioDeviceDescriptor, element: UInt32) {}
    func startTransport(device: AudioDeviceDescriptor, channel: Int, request: TransportRequest) { self.request = request; emit(tick: request.startTick, beat: 1) }
    func stopTransport() { request = nil; value = nil }
    func readTransport() -> TransportPlaybackSnapshot? { value }
    func emit(tick: Int64, beat: Int? = nil) {
        guard let request else { return }
        value = TransportPlaybackSnapshot(requestID: request.id, phase: .playing,
            position: TransportPosition(tick: tick, loopIndex: 0, countInBeat: beat, completed: false), sampleRate: 48000,
            renderedFrames: 48000, scheduledStartHostSeconds: 1, renderAnchorHostSeconds: 1, presentationLatency: 0)
    }
}
private struct PreviewPermission: AudioPermissionProviding {
    func status() -> AudioPermissionStatus { .denied }
    func request() -> Bool { Issue.record("Preview must not request microphone permission"); return false }
}

@MainActor struct PreviewModelTests {
    private func exercise() throws -> Exercise {
        try Exercise(id: "preview-model", events: [
            MusicalEvent(id: "note", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)]),
            MusicalEvent(id: "rest", startTick: 960, durationTicks: 960, kind: .rest),
            MusicalEvent(id: "last", startTick: 1920, durationTicks: 1920, kind: .note, positions: [FretPosition(string: 1, fret: 0)])])
    }
    @Test func cursorPauseSeekAndResumeUseNewSegmentsAndCanonicalEvents() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let runtime = PreviewRuntime(), coordinator = AudioSessionCoordinator(runtime: runtime, permissions: PreviewPermission())
        let audio = AudioSessionStore(repository: LocalRepository(root: directory), coordinator: coordinator)
        await audio.load(); await audio.select(outputUID: "output", outputChannel: 2)
        let model = PreviewModel(); await model.configure(try exercise(), audio: audio)
        await model.start(tuning: .standard, audio: audio)
        let firstID = try #require(model.requestID)
        #expect(model.countInBeat == 1 && model.activeEvent() == nil)
        await runtime.emit(tick: 960); await coordinator.poll(); await audio.publish(); model.update(audio.state)
        #expect(model.activeEvent()?.id == "rest" && model.activeEvent()?.positions.isEmpty == true)
        await model.stop(audio: audio, pause: true)
        #expect(model.resumeTick == 960 && model.cursorTick == nil)
        model.bpm = 73
        await model.start(tuning: .dropD, audio: audio)
        #expect(model.requestID != firstID)
        #expect(await runtime.request?.startTick == 960)
        #expect(await runtime.request?.bpm == 73)
        #expect(await runtime.request?.countInBars == 1)
        await model.seek(1920, audio: audio)
        #expect(model.requestID == nil && model.resumeTick == 1920)
        await model.start(tuning: .standard, audio: audio)
        await runtime.emit(tick: 1920); await coordinator.poll(); await audio.publish(); model.update(audio.state)
        #expect(model.activeEvent()?.id == "last")
        await model.configure(nil, audio: audio)
        #expect(model.requestID == nil && model.resumeTick == nil && model.cursorTick == nil)
        #expect(await runtime.request == nil)
    }
}
