import Testing
import AVFAudio
import RealtimeAudio
import AudioTestSupport
@testable import Audio

@Suite struct CaptureAnalysisTests {
    @Test func badPacketTimestampCannotBeHiddenByALaterValidPacket() async throws {
        let storage = try PCMStorage(), reader = try PCMReader(storage: storage, sampleRate: 48000)
        let zero = [Float](repeating: 0, count: 480)
        for packet in 0..<3 {
            let info = GCPacketInfo(host_time: UInt64(packet + 1), sample_time: Double(packet * 480), sample_rate: 48000,
                frame_count: 0, host_time_valid: packet != 1, sample_time_valid: true)
            #expect(zero.withUnsafeBufferPointer { GCRingWrite(storage.handle, $0.baseAddress!, 480, 1, info) })
        }
        await reader.drain()
        let snapshot = try #require(await reader.snapshot())
        #expect(snapshot.hostTimeValid)
        #expect(snapshot.discontinuities == 1)
    }

    @Test func selectedChannelTraversesTheRealRingAndWorkerWithInputTimestamps() async throws {
        let rate = 48000.0
        let mono = SyntheticAudio.render(rate: rate, duration: 1, notes: [.init(frequency: 220)])
        let other = SyntheticAudio.render(rate: rate, duration: 1, notes: [.init(frequency: 440)])
        let stereo = zip(other, mono).flatMap { [$0.0, $0.1] }
        let storage = try PCMStorage(), reader = try PCMReader(storage: storage, sampleRate: rate)
        for offset in stride(from: 0, to: mono.count, by: 512) {
            let frames = min(512, mono.count - offset)
            let info = GCPacketInfo(host_time: AVAudioTime.hostTime(forSeconds: 100 + Double(offset) / rate),
                sample_time: Double(offset), sample_rate: rate, frame_count: 0, host_time_valid: true, sample_time_valid: true)
            #expect(stereo.withUnsafeBufferPointer { GCRingWrite(storage.handle, $0.baseAddress! + offset * 2 + 1, UInt32(frames), 2, info) })
            await reader.drain()
        }
        let value = try #require(await reader.snapshot())
        #expect(value.totalFrames == 48000 && value.droppedPackets == 0 && value.discontinuities == 0)
        let event = try #require(value.analysis?.events.first)
        #expect(event.quality == .reliable)
        #expect(abs((event.pitch?.frequency ?? 0) - 220) < 1)
        #expect(abs((event.onset.hostSeconds ?? 0) - 100.1) < 0.03)
        #expect(value.analysis?.latest?.quality == .silence)
    }

    @Test func sustainedStreamingRetainsOnlyBoundedEventHistory() throws {
        let analyzer = try MonophonicAnalyzer(sampleRate: 48000)
        [Float](repeating: 0, count: 4800).withUnsafeBufferPointer { analyzer.process($0) }
        let cycle = SyntheticAudio.render(rate: 48000, duration: 0.2,
            notes: [.init(onset: 0.05, duration: 0.13, frequency: 220)])
        for _ in 0..<136 { cycle.withUnsafeBufferPointer { analyzer.process($0) } }
        analyzer.finish()
        let result = analyzer.snapshot()
        #expect(result.totalEvents == 136)
        #expect(result.events.count == MonophonicAnalyzer.eventCapacity)
        #expect(result.events.first?.id == 9 && result.events.last?.id == 136)
        #expect(result.invalidSamples == 0)
    }
}
