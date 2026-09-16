import Testing
import Foundation
import Darwin
import RealtimeAudio
@testable import Audio

@Suite("Real-time PCM handoff")
struct RealtimeBufferTests {
    @Test func concurrentProducerConsumerPreserveSequence() async throws {
        let storage = try TestRing()
        // Dedicated queues model the separate capture/worker threads. Cooperative
        // Tasks can be starved by concurrent synchronous DSP fixtures, exhausting
        // the deadline before the other half of the ring test can run.
        async let produced = onQueue {
            var index = 0
            let deadline = ContinuousClock.now + .seconds(5)
            while index < 10_000 && ContinuousClock.now < deadline {
                var value = Float(index)
                if GCRingWrite(storage.handle, &value, 1, 1, GCPacketInfo()) { index += 1 }
                else { sched_yield() }
            }
            return index
        }
        async let consumed = onQueue {
            var index = 0
            var mismatches = 0
            let deadline = ContinuousClock.now + .seconds(5)
            while index < 10_000 && ContinuousClock.now < deadline {
                var value: Float = -1
                var info = GCPacketInfo()
                if GCRingRead(storage.handle, &value, 1, &info) {
                    if value != Float(index) { mismatches += 1 }
                    index += 1
                } else { sched_yield() }
            }
            return (index, mismatches)
        }
        let (writes, reads) = await (produced, consumed)
        #expect(writes == 10_000)
        #expect(reads.0 == 10_000)
        #expect(reads.1 == 0)
    }

    private func onQueue<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue(label: "ring-test-" + UUID().uuidString, qos: .userInitiated).async {
                continuation.resume(returning: body())
            }
        }
    }

    @Test func selectsOneInterleavedChannelAndPreservesTime() throws {
        let ring = try #require(GCRingCreate(2, 4))
        defer { GCRingDestroy(ring) }
        let stereo: [Float] = [1, 11, 2, 12, 3, 13, 4, 14]
        let timestamp = GCPacketInfo(host_time: 123, sample_time: 456, sample_rate: 44100, frame_count: 0, host_time_valid: true, sample_time_valid: true)
        #expect(stereo.withUnsafeBufferPointer { GCRingWrite(ring, $0.baseAddress! + 1, 4, 2, timestamp) })
        var mono = [Float](repeating: 0, count: 4)
        var info = GCPacketInfo()
        #expect(mono.withUnsafeMutableBufferPointer { GCRingRead(ring, $0.baseAddress!, 4, &info) })
        #expect(mono == [11, 12, 13, 14])
        #expect(info.host_time == 123 && info.sample_time == 456 && info.sample_rate == 44100)
        #expect(info.host_time_valid && info.frame_count == 4)
    }

    @Test func overflowIsReportedWithoutOverwritingUnreadAudio() throws {
        let ring = try #require(GCRingCreate(2, 2))
        defer { GCRingDestroy(ring) }
        var sample: Float = 1
        let info = GCPacketInfo()
        #expect(GCRingWrite(ring, &sample, 1, 1, info))
        sample = 2; #expect(GCRingWrite(ring, &sample, 1, 1, info))
        sample = 3; #expect(!GCRingWrite(ring, &sample, 1, 1, info))
        #expect(GCRingDropped(ring) == 1)
        var read = GCPacketInfo()
        #expect(GCRingRead(ring, &sample, 1, &read)); #expect(sample == 1)
        #expect(GCRingRead(ring, &sample, 1, &read)); #expect(sample == 2)
        sample = 4; #expect(GCRingWrite(ring, &sample, 1, 1, info))
        #expect(GCRingRead(ring, &sample, 1, &read)); #expect(sample == 4)
    }

    @Test func undersizedConsumerDoesNotLosePacket() throws {
        let ring = try #require(GCRingCreate(2, 4))
        defer { GCRingDestroy(ring) }
        let samples: [Float] = [1, 2, 3, 4]
        #expect(samples.withUnsafeBufferPointer { GCRingWrite(ring, $0.baseAddress!, 4, 1, GCPacketInfo()) })
        var output = [Float](repeating: 0, count: 4)
        var info = GCPacketInfo()
        #expect(!output.withUnsafeMutableBufferPointer { GCRingRead(ring, $0.baseAddress!, 2, &info) })
        #expect(output.withUnsafeMutableBufferPointer { GCRingRead(ring, $0.baseAddress!, 4, &info) })
        #expect(output == samples)
    }

    @Test func rejectsUnboundedAllocation() {
        #expect(GCRingCreate(0, 100) == nil)
        #expect(GCRingCreate(2, UInt32.max) == nil)
    }
}

// Test ownership only; synchronization is implemented in the C SPSC queue.
private final class TestRing: @unchecked Sendable {
    let handle: OpaquePointer
    init() throws { handle = try #require(GCRingCreate(8, 4)) }
    deinit { GCRingDestroy(handle) }
}
