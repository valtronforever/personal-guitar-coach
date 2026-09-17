import Foundation

/// Explicit omitted pulse-click onsets, in exercise ticks. Musical events and
/// count-in are unaffected. Nil on Exercise means the ordinary continuous click.
public struct MetronomePattern: Hashable, Codable, Sendable {
    public let silentBeatTicks: [Int64]
    public init(silentBeatTicks: [Int64]) throws {
        guard !silentBeatTicks.isEmpty, silentBeatTicks.count <= 4096,
              silentBeatTicks.allSatisfy({ $0 >= 0 && $0 % 480 == 0 }),
              zip(silentBeatTicks, silentBeatTicks.dropFirst()).allSatisfy({ $0 < $1 }) else { throw MusicError.invalidTime }
        self.silentBeatTicks = silentBeatTicks
    }
    public func scoped(to range: Range<Int64>, pulseTicks: Int64 = MusicalTime.ppq) throws -> Self? {
        guard [480,960,1440].contains(pulseTicks), range.lowerBound >= 0, range.lowerBound % pulseTicks == 0,
              range.upperBound % pulseTicks == 0 else { throw MusicError.invalidTime }
        let ticks = silentBeatTicks.filter(range.contains).map { $0 - range.lowerBound }
        return ticks.isEmpty ? nil : try Self(silentBeatTicks: ticks)
    }
    private enum CodingKeys: String, CodingKey { case silentBeatTicks }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(silentBeatTicks: values.decode([Int64].self, forKey: .silentBeatTicks))
    }
}
