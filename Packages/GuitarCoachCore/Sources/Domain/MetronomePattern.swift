import Foundation

/// Explicit omitted quarter-click onsets, in exercise ticks. Musical events and
/// count-in are unaffected. Nil on Exercise means the ordinary continuous click.
public struct MetronomePattern: Hashable, Codable, Sendable {
    public let silentBeatTicks: [Int64]
    public init(silentBeatTicks: [Int64]) throws {
        guard !silentBeatTicks.isEmpty, silentBeatTicks.count <= 4096,
              silentBeatTicks.allSatisfy({ $0 >= 0 && $0 % MusicalTime.ppq == 0 }),
              zip(silentBeatTicks, silentBeatTicks.dropFirst()).allSatisfy({ $0 < $1 }) else { throw MusicError.invalidTime }
        self.silentBeatTicks = silentBeatTicks
    }
    public func scoped(to range: Range<Int64>) throws -> Self? {
        guard range.lowerBound >= 0, range.lowerBound % MusicalTime.ppq == 0,
              range.upperBound % MusicalTime.ppq == 0 else { throw MusicError.invalidTime }
        let ticks = silentBeatTicks.filter(range.contains).map { $0 - range.lowerBound }
        return ticks.isEmpty ? nil : try Self(silentBeatTicks: ticks)
    }
    private enum CodingKeys: String, CodingKey { case silentBeatTicks }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(silentBeatTicks: values.decode([Int64].self, forKey: .silentBeatTicks))
    }
}
