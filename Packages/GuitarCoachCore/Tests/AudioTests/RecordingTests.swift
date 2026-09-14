import Testing
@testable import Audio

struct RecordingTests {
    @Test func recordingIsBoundedAndRetainsFirstPacketHostTime() throws {
        var recording = RecordingBuffer(sampleRate: 48000)
        let values = [Float](repeating: 0.1, count: 480)
        values.withUnsafeBufferPointer { recording.append($0, hostSeconds: 42, healthy: true) }
        values.withUnsafeBufferPointer { recording.append($0, hostSeconds: 42.01, healthy: true) }
        let take = try recording.finish()
        #expect(take.firstHostSeconds == 42 && take.samples.count == 960 && take.sampleRate == 48000)
        values.withUnsafeBufferPointer { recording.append($0, hostSeconds: 43, healthy: true) }
        #expect(throws: AudioBackendError.dataLoss) { try recording.finish() }
    }
    @Test func overflowNonfiniteAndDroppedPacketsCannotReturnPartialSuccess() throws {
        for kind in 0..<3 {
            var recording = RecordingBuffer(sampleRate: 1)
            let values = kind == 0 ? [Float](repeating: 0.1, count: 151) : [kind == 1 ? Float.nan : 0.1]
            values.withUnsafeBufferPointer { recording.append($0, hostSeconds: 42, healthy: kind != 2) }
            #expect(recording.failed && recording.samples.isEmpty)
            #expect(throws: AudioBackendError.dataLoss) { try recording.finish() }
        }
    }
}
