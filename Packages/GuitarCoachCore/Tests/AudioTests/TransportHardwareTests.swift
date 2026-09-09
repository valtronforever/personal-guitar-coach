import Foundation
import Testing
import Domain
@testable import Audio

/// Explicit opt-in, silent output integration. Does not capture input, change hardware format or prove audibility.
struct TransportHardwareTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["COACH_TEST_OUTPUT_NAME"] != nil))
    func silentNativeOutputAdvancesPlayerClockAndCompletes() async throws {
        let name = try #require(ProcessInfo.processInfo.environment["COACH_TEST_OUTPUT_NAME"])
        let devices = try AudioDeviceService().devices().filter { $0.name == name && $0.outputChannels > 0 }
        #expect(devices.count == 1)
        let device = try #require(devices.first)
        let exercise = try Exercise(id: "silent-native-test", events: [
            MusicalEvent(id: "note", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)])])
        let request = try TransportRequest(exercise: exercise, tuning: .standard, bpm: 200, countInBars: 0,
                                           clickVolume: 0, toneVolume: 0)
        let output = TransportOutput()
        try await output.start(device: device, channel: 1, request: request)
        let started = ContinuousClock.now
        var final: TransportPlaybackSnapshot?
        while started.duration(to: .now) < .seconds(5) {
            final = await output.read()
            if final?.phase != .playing { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        await output.stop()
        let value = try #require(final)
        #expect(value.phase == .completed)
        #expect(value.position.completed)
        #expect(value.renderedFrames >= Int64(device.sampleRate * 0.3))
        #expect(value.renderAnchorHostSeconds?.isFinite == true)
        #expect(await output.read() == nil)
        print("Silent native transport: \(device.name), UID \(device.uid), \(device.sampleRate) Hz, buffer \(device.bufferFrames), rendered \(value.renderedFrames), anchor \(value.renderAnchorHostSeconds ?? 0), presentation estimate \(value.presentationLatency) s")
    }
}
