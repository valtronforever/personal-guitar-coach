import Foundation
import Domain

public enum PersonalSyncProbe {
    public static let algorithmVersion = PersonalSyncEvidence.currentAlgorithmVersion
    public static let warmupBeats = 4
    public static let measuredBeats = 16
    /// Audio-rendered clicks; the first four are listening only. There are no reference guitar tones.
    public static func request(instrument: InstrumentProfile, string: Int) throws -> TransportRequest {
        let position = try FretPosition(string: string, fret: 0)
        let events = try (0..<20).map { index in
            try MusicalEvent(id: "sync-\(index)", startTick: Int64(index) * 960, durationTicks: 240,
                             kind: .note, positions: [position])
        }
        return try TransportRequest(exercise: Exercise(id: algorithmVersion, events: events), tuning: instrument.tuning,
                                    bpm: 60, countInBars: 0, mode: .calibration, accent: false, clickVolume: 0.2, toneVolume: 0)
    }
}

public struct PersonalSyncPass: Equatable, Sendable {
    public let offset: Double
    public let spread: Double
    public let drift: Double
    /// Timestamps have already been normalized by CalibrationRoute. All sixteen attacks must be present.
    /// A sub-half-beat window prevents silently matching a missing attack to the following click.
    public init(expected: [Double], observed: [Double]) throws {
        guard expected.count == 16, (expected + observed).allSatisfy({ $0.isFinite }),
              zip(expected, expected.dropFirst()).allSatisfy({ abs($1 - $0 - 1) < 0.001 }),
              zip(observed, observed.dropFirst()).allSatisfy({ $1 > $0 }) else { throw CalibrationError.insufficientEvidence }
        let attacks = observed.filter { $0 >= expected[0] - 0.45 && $0 <= expected[15] + 0.45 }
        guard attacks.count == 16 else { throw CalibrationError.insufficientEvidence }
        let offsets = zip(attacks, expected).map(-)
        guard offsets.allSatisfy({ abs($0) <= 0.4 }) else { throw CalibrationError.insufficientEvidence }
        let center = Self.median(offsets)
        // With sixteen samples the nearest-rank p95 is the maximum, deliberately conservative.
        let spread = offsets.map { abs($0 - center) }.max()!
        let drift = Self.median(Array(offsets.suffix(5))) - Self.median(Array(offsets.prefix(5)))
        guard spread <= 0.06, abs(drift) <= 0.04 else { throw CalibrationError.insufficientEvidence }
        self.offset = center; self.spread = spread; self.drift = drift
    }
    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted(), n = sorted.count
        return (sorted[(n - 1) / 2] + sorted[n / 2]) / 2
    }
}
