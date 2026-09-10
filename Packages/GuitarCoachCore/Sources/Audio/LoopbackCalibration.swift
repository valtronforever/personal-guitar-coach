import Foundation
import Domain

public enum LoopbackProbe {
    public static let algorithmVersion = "loopback-onset-median-1"
    /// Irregular spacing prevents a missing first pulse from silently shifting all matches by one beat.
    public static func request(long: Bool = false) throws -> TransportRequest {
        let pattern = [1, 3, 4, 6, 9, 11, 14, 15, 17, 20, 22, 25]
        let seconds = long ? (0..<34).flatMap { cycle in pattern.map { cycle * 27 + $0 }.filter { $0 < 900 } } : pattern
        let events = try seconds.enumerated().map { index, second in
            try MusicalEvent(id: "pulse-\(index)", startTick: Int64(second) * 960, durationTicks: 240,
                             kind: .note, positions: [FretPosition(string: 6, fret: 0)])
        }
        return try TransportRequest(exercise: Exercise(id: "loopback-probe-v1", events: events), tuning: .standard,
            bpm: 60, countInBars: 0, mode: .calibration, accent: false, clickVolume: 0.2, toneVolume: 0)
    }
}

public struct LoopbackEstimate: Sendable {
    public let residualOffsetSeconds: Double
    public let uncertaintySeconds: Double
    public let evidence: CalibrationEvidence
}

public enum LoopbackEstimator {
    private struct Fit {
        let offsets: [Double]
        let times: [Double]
        let median: Double
        let p95: Double
    }
    /// All timestamps are already normalized once using CalibrationRoute. No latency is subtracted here.
    public static func estimate(expected: [Double], observed: [Double]) throws -> LoopbackEstimate {
        guard (8...512).contains(expected.count), (8...512).contains(observed.count),
              (expected + observed).allSatisfy({ $0.isFinite }),
              zip(expected, expected.dropFirst()).allSatisfy({ $1 - $0 >= 0.25 }),
              zip(observed, observed.dropFirst()).allSatisfy({ $1 > $0 }) else { throw CalibrationError.insufficientEvidence }
        // Bounded 1-ms offset histogram, then only eight candidate alignments (not cubic pair search).
        var histogram: [Int: Int] = [:]
        for target in expected { for onset in observed {
            let delta = onset - target
            if abs(delta) <= 1 { histogram[Int((delta * 1000).rounded()), default: 0] += 1 }
        } }
        let peaks = histogram.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        var candidates: [Double] = []
        for peak in peaks {
            let offset = Double(peak.key) / 1000
            if candidates.allSatisfy({ abs($0 - offset) >= 0.04 }) { candidates.append(offset) }
            if candidates.count == 8 { break }
        }
        var fits: [Fit] = []
        for offset in candidates {
            var index = 0, offsets: [Double] = [], times: [Double] = []
            for target in expected {
                while index < observed.count && observed[index] < target + offset - 0.08 { index += 1 }
                if index < observed.count && abs(observed[index] - target - offset) <= 0.08 {
                    offsets.append(observed[index] - target); times.append(target); index += 1
                }
            }
            guard offsets.count >= 8 else { continue }
            let center = median(offsets), error = percentile95(offsets.map { abs($0 - center) })
            let fit = Fit(offsets: offsets, times: times, median: center, p95: error)
            if let existing = fits.firstIndex(where: { abs($0.median - center) < 0.02 }) {
                if offsets.count > fits[existing].offsets.count { fits[existing] = fit }
            } else { fits.append(fit) }
        }
        fits.sort { $0.offsets.count == $1.offsets.count ? $0.p95 < $1.p95 : $0.offsets.count > $1.offsets.count }
        guard let best = fits.first, abs(best.median) <= 1 else { throw CalibrationError.insufficientEvidence }
        if fits.dropFirst().contains(where: { $0.offsets.count == best.offsets.count && abs($0.p95 - best.p95) < 0.01 }) {
            throw CalibrationError.insufficientEvidence
        }
        let third = max(1, best.offsets.count / 3)
        let drift = median(Array(best.offsets.suffix(third))) - median(Array(best.offsets.prefix(third)))
        let evidence = try CalibrationEvidence(algorithmVersion: LoopbackProbe.algorithmVersion,
            matchedPulses: best.offsets.count, missedPulses: expected.count - best.offsets.count,
            extraPulses: observed.count - best.offsets.count, durationSeconds: best.times.last! - best.times.first!,
            residualP95Seconds: best.p95, driftSeconds: drift)
        return LoopbackEstimate(residualOffsetSeconds: best.median, uncertaintySeconds: best.p95 + 0.01 + abs(drift), evidence: evidence)
    }
    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted(), middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
    private static func percentile95(_ values: [Double]) -> Double {
        let sorted = values.sorted(); return sorted[max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
    }
}
