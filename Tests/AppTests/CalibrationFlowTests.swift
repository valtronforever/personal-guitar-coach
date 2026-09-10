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
    func devices() -> [AudioDeviceDescriptor] {
        [AudioDeviceDescriptor(hardwareID: 1, uid: "test", name: "Synthetic interface", inputChannels: 1, outputChannels: 1,
            sampleRate: 48000, bufferFrames: changed ? 256 : 512)]
    }
    func capabilities(device: AudioDeviceDescriptor, channel: Int) -> AudioDeviceCapabilities {
        AudioDeviceCapabilities(sampleRates: [48000...48000], bufferRange: 256...512,
            canSetSampleRate: false, canSetBufferFrames: false, inputGain: nil)
    }
    func startInput(device: AudioDeviceDescriptor, channel: Int) -> AudioStreamFormat { AudioStreamFormat(sampleRate: 48000, inputChannels: 1) }
    func stopInput() {}
    func readInput() -> CaptureSnapshot? {
        reads += 1
        let frames: UInt64 = (complete ? 27 * 48000 : 0) + reads * 512
        let events: [DetectedNoteEvent] = complete ? (request?.exercise.events.enumerated().map { index, event in
            let frame = Int64((Double(event.startTick) / 960 + 0.05) * 48000)
            let onset = AnalysisTimestamp(frame: frame, sampleRate: 48000, hostSeconds: 100 + Double(frame) / 48000)
            return DetectedNoteEvent(id: UInt64(index + 1), onset: onset, resolvedAt: onset, quality: .unstable, pitch: nil)
        } ?? []) : []
        let analysis = AudioAnalysisSnapshot(algorithmVersion: MonophonicAnalyzer.algorithmVersion, latest: nil, events: events,
            totalEvents: UInt64(events.count), invalidSamples: 0, qualitySpans: [], totalQualitySpans: 0)
        return CaptureSnapshot(totalFrames: frames, totalPackets: frames / 512, droppedPackets: 0, peak: 0.2, rms: 0.01,
            sampleRate: 48000, lastHostTime: AVAudioTime.hostTime(forSeconds: 100 + Double(frames - 512) / 48000),
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
    func finish() { complete = true }
    func changeRoute() { changed = true }
}

@MainActor struct CalibrationFlowTests {
    @Test func completedMeasurementSavesSignedOffsetAndRouteChangeSavesNothing() async throws {
        for changeRoute in [false, true] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = LocalRepository(root: directory), runtime = CalibrationRuntime()
            let coordinator = AudioSessionCoordinator(runtime: runtime, permissions: CalibrationPermission())
            let audio = AudioSessionStore(repository: repository, coordinator: coordinator)
            await audio.load(); await audio.select(inputUID: "test", outputUID: "test")
            let store = CalibrationStore(repository: repository); await store.load()
            let model = CalibrationModel(); model.start(audio: audio, store: store, long: false)
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while await runtime.request == nil, ContinuousClock.now < deadline { await Task.yield() }
            #expect(await runtime.request != nil)
            await coordinator.poll()
            if changeRoute { await runtime.changeRoute(); await coordinator.refresh() }
            else { await runtime.finish(); await coordinator.poll() }
            while model.running, ContinuousClock.now < deadline {
                await coordinator.poll()
                try await Task.sleep(for: .milliseconds(25))
            }
            #expect(!model.running)
            if changeRoute {
                #expect(store.profiles.isEmpty && model.messageKey == "calibration.failed")
            } else {
                let saved = try #require(store.profiles.first)
                #expect(saved.method == .measured && abs(saved.residualOffsetSeconds - 0.05) < 0.001)
                #expect(saved.evidence?.matchedPulses == 12)
            }
            #expect(await coordinator.snapshot().captureRequestID == nil)
        }
    }
}
