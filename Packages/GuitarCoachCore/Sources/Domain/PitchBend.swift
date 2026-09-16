import Foundation

/// One picked note with an authored upward bend and optional return, in musical ticks.
/// This describes audible pitch; it cannot establish how the player moved a string.
public struct PitchBend: Hashable, Codable, Sendable {
    public let semitones: Int
    public let riseStartTick: Int64
    public let riseEndTick: Int64
    public let releaseStartTick: Int64?
    public let releaseEndTick: Int64?

    public init(semitones: Int, riseStartTick: Int64, riseEndTick: Int64,
                releaseStartTick: Int64? = nil, releaseEndTick: Int64? = nil) throws {
        guard (1...2).contains(semitones), riseStartTick > 0, riseEndTick > riseStartTick,
              (releaseStartTick == nil) == (releaseEndTick == nil) else { throw MusicError.invalidEvent }
        if let start = releaseStartTick, let end = releaseEndTick {
            guard start > riseEndTick, end > start else { throw MusicError.invalidEvent }
        }
        self.semitones = semitones; self.riseStartTick = riseStartTick; self.riseEndTick = riseEndTick
        self.releaseStartTick = releaseStartTick; self.releaseEndTick = releaseEndTick
    }

    public struct Point: Equatable, Sendable {
        public let tick: Int64
        public let cents: Double
    }
    public func points(durationTicks: Int64) -> [Point] {
        let target = Double(semitones * 100)
        var result = [Point(tick: 0, cents: 0), Point(tick: riseStartTick, cents: 0), Point(tick: riseEndTick, cents: target)]
        if let start = releaseStartTick, let end = releaseEndTick {
            result += [Point(tick: start, cents: target), Point(tick: end, cents: 0)]
        }
        result.append(Point(tick: durationTicks, cents: releaseEndTick == nil ? target : 0))
        return result
    }
    public func cents(at tick: Double, durationTicks: Int64) -> Double {
        let points = points(durationTicks: durationTicks)
        for (a, b) in zip(points, points.dropFirst()) where tick <= Double(b.tick) {
            let fraction = min(1, max(0, (tick - Double(a.tick)) / Double(b.tick - a.tick)))
            return a.cents + fraction * (b.cents - a.cents)
        }
        return points.last!.cents
    }
    /// Integral of the frequency multiplier in ticks; absolute phase is chunk/seek independent.
    public func integratedMultiplier(to tick: Double, durationTicks: Int64) -> Double {
        Self.integratedMultiplier(to: tick, points: points(durationTicks: durationTicks))
    }
    public static func integratedMultiplier(to tick: Double, points: [Point]) -> Double {
        var integral = 0.0
        let upper = min(Double(points.last?.tick ?? 0), max(0, tick))
        for (a, b) in zip(points, points.dropFirst()) {
            let length = min(upper, Double(b.tick)) - Double(a.tick)
            guard length > 0 else { break }
            let multiplier = pow(2, a.cents / 1200)
            let slope = (b.cents - a.cents) * log(2) / (1200 * Double(b.tick - a.tick))
            integral += abs(slope) < 1e-12 ? multiplier * length : multiplier * expm1(slope * length) / slope
        }
        return integral
    }
    public func validate(durationTicks: Int64) throws {
        guard (releaseEndTick ?? riseEndTick) < durationTicks else { throw MusicError.invalidTime }
    }
    private enum CodingKeys: String, CodingKey { case semitones, riseStartTick, riseEndTick, releaseStartTick, releaseEndTick }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(semitones: v.decode(Int.self, forKey: .semitones), riseStartTick: v.decode(Int64.self, forKey: .riseStartTick),
            riseEndTick: v.decode(Int64.self, forKey: .riseEndTick), releaseStartTick: v.decodeIfPresent(Int64.self, forKey: .releaseStartTick),
            releaseEndTick: v.decodeIfPresent(Int64.self, forKey: .releaseEndTick))
    }
}
