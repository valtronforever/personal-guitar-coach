import Foundation

/// Authored upward pitch oscillation returning to the base after every full cycle.
/// This describes audible pitch, not a verified finger or hand movement.
public struct PitchVibrato: Hashable, Codable, Sendable {
    public let extentCents: Int
    public let startTick: Int64
    public let endTick: Int64
    public let periodTicks: Int64
    public var cycles: Int64 { (endTick - startTick) / periodTicks }

    public init(extentCents: Int, startTick: Int64, endTick: Int64, periodTicks: Int64) throws {
        guard (1...200).contains(extentCents), startTick > 0, endTick > startTick, periodTicks > 0,
              (endTick - startTick) % periodTicks == 0, (endTick - startTick) / periodTicks >= 2 else { throw MusicError.invalidEvent }
        self.extentCents = extentCents; self.startTick = startTick; self.endTick = endTick; self.periodTicks = periodTicks
    }
    public func validate(durationTicks: Int64) throws {
        guard endTick < durationTicks else { throw MusicError.invalidTime }
    }
    public func cents(at tick: Double) -> Double {
        guard tick > Double(startTick), tick < Double(endTick) else { return 0 }
        let cycle = ((tick - Double(startTick)) / Double(periodTicks)).truncatingRemainder(dividingBy: 1)
        return Double(extentCents) * (1 - cos(2 * .pi * cycle)) / 2
    }
    private enum CodingKeys: String, CodingKey { case extentCents, startTick, endTick, periodTicks }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(extentCents: v.decode(Int.self, forKey: .extentCents), startTick: v.decode(Int64.self, forKey: .startTick),
            endTick: v.decode(Int64.self, forKey: .endTick), periodTicks: v.decode(Int64.self, forKey: .periodTicks))
    }
}

/// Prepared once outside rendering. The table depends only on extent, so transports may share it
/// between events. Lookup is allocation-free and independent of chunk/seek history.
public struct VibratoWaveform: Sendable {
    public let extentCents: Int
    private static let segments = 1024
    private let cumulative: [Double]
    private let multipliers: [Double]

    public init(extentCents: Int) throws {
        guard (1...200).contains(extentCents) else { throw MusicError.invalidEvent }
        self.extentCents = extentCents
        let step = 1 / Double(Self.segments)
        func multiplier(_ phase: Double) -> Double {
            pow(2, Double(extentCents) * (1 - cos(2 * .pi * phase)) / 2400)
        }
        let samples = (0...Self.segments).map { multiplier(Double($0) * step) }
        var areas = [Double](repeating: 0, count: Self.segments + 1)
        for index in 0..<Self.segments {
            // Simpson quadrature with midpoint; Hermite lookup also uses endpoint derivatives.
            let middle = multiplier((Double(index) + 0.5) * step)
            areas[index + 1] = areas[index] + step * (samples[index] + 4 * middle + samples[index + 1]) / 6
        }
        cumulative = areas; multipliers = samples
    }
    fileprivate func integratedCycles(_ cycles: Double) -> Double {
        let complete = floor(cycles), fraction = cycles - complete
        return complete * cumulative[Self.segments] + partialCycle(fraction)
    }
    private func partialCycle(_ fraction: Double) -> Double {
        guard fraction > 0 else { return 0 }
        guard fraction < 1 else { return cumulative[Self.segments] }
        let coordinate = fraction * Double(Self.segments), index = min(Self.segments - 1, Int(coordinate))
        let x = coordinate - Double(index), square = x * x, cube = square * x, step = 1 / Double(Self.segments)
        return (2 * cube - 3 * square + 1) * cumulative[index] + (cube - 2 * square + x) * step * multipliers[index]
            + (-2 * cube + 3 * square) * cumulative[index + 1] + (cube - square) * step * multipliers[index + 1]
    }
}

/// Binds a validated authored gesture to its prepared waveform before rendering starts.
public struct VibratoReference: Sendable {
    public let vibrato: PitchVibrato
    private let waveform: VibratoWaveform
    public init(vibrato: PitchVibrato, waveform: VibratoWaveform? = nil) throws {
        if let waveform, waveform.extentCents != vibrato.extentCents { throw MusicError.invalidEvent }
        self.vibrato = vibrato; self.waveform = try waveform ?? VibratoWaveform(extentCents: vibrato.extentCents)
    }
    public func integratedMultiplier(to tick: Double, durationTicks: Int64) -> Double {
        let upper = min(Double(durationTicks), max(0, tick))
        let initial = min(upper, Double(vibrato.startTick))
        guard upper > Double(vibrato.startTick) else { return initial }
        let activeTicks = min(upper - Double(vibrato.startTick), Double(vibrato.endTick - vibrato.startTick))
        let cycles = activeTicks / Double(vibrato.periodTicks)
        return initial + Double(vibrato.periodTicks) * waveform.integratedCycles(cycles) + max(0, upper - Double(vibrato.endTick))
    }
}
