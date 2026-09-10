import Testing
import Foundation
import Domain
@testable import Audio

struct LoopbackTests {
    @Test func actualPulseRendererAndAnalyzerRecoverSignedDelays() throws {
        for rate in [44100.0, 48000] { for delay in [-0.05, 0.05] {
            let request = try LoopbackProbe.request()
            let plan = try TransportPlan(request: request, sampleRate: rate)
            let analyzer = try MonophonicAnalyzer(sampleRate: rate)
            let shift = Int64((delay * rate).rounded())
            let end = Int(27 * rate)
            for start in stride(from: 0, to: end, by: 512) {
                let count = min(512, end - start), source = Int64(start) - shift
                var block = [Float](repeating: 0, count: count)
                let skip = Int(max(0, -source))
                if skip < count {
                    let rendered = try plan.render(startFrame: max(0, source), count: count - skip)
                    block.replaceSubrange(skip..<count, with: rendered)
                }
                if delay > 0 {
                    for index in block.indices {
                        block[index] += Float(0.0002 * sin(2 * .pi * 2300 * Double(start + index) / rate))
                    }
                }
                block.withUnsafeBufferPointer { analyzer.process($0, startHostSeconds: 100 + Double(start) / rate) }
            }
            analyzer.finish()
            let observed = analyzer.snapshot().events.compactMap(\.onset.hostSeconds)
            let expected = request.exercise.events.map { 100 + Double($0.startTick) / 960 }
            let estimate = try LoopbackEstimator.estimate(expected: expected, observed: observed)
            #expect(estimate.evidence.matchedPulses == 12)
            #expect(abs(estimate.residualOffsetSeconds - delay) <= 0.02)
            #expect(estimate.evidence.residualP95Seconds <= 0.02)
        } }
    }

    @Test func missingSignalExcessAttacksAndAmbiguousAlignmentReject() throws {
        let expected = [1.0, 3, 4, 6, 9, 11, 14, 15, 17, 20, 22, 25]
        #expect(throws: CalibrationError.self) { try LoopbackEstimator.estimate(expected: expected, observed: []) }
        #expect(throws: CalibrationError.self) {
            try LoopbackEstimator.estimate(expected: expected, observed: (expected + [2.2, 5.2, 7.2]).sorted())
        }
        #expect(throws: CalibrationError.self) {
            try LoopbackEstimator.estimate(expected: expected, observed: expected.flatMap { [$0 - 0.1, $0 + 0.1] })
        }
        let oneMissing = try LoopbackEstimator.estimate(expected: expected, observed: expected.dropFirst().map { $0 + 0.05 })
        #expect(abs(oneMissing.residualOffsetSeconds - 0.05) < 0.000001)
        #expect(oneMissing.evidence.missedPulses == 1)
    }
}
