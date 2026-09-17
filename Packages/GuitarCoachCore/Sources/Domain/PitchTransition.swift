import Foundation

/// An authored change from a picked starting pitch to another fret on the same string.
/// The technique names describe the instruction; sound cannot prove the hand gesture.
public struct PitchTransition: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case slide, hammerOn, pullOff }
    public let kind: Kind
    public let semitones: Int
    public let startTick: Int64
    /// A slide has a travel interval; legato reference pitch changes at one exact tick.
    public let travelTicks: Int64
    public var endTick: Int64 { startTick + travelTicks }

    public init(kind: Kind, semitones: Int, startTick: Int64, travelTicks: Int64 = 0) throws {
        guard (-12...12).contains(semitones), semitones != 0, startTick > 0,
              travelTicks >= 0, startTick <= Int64.max - travelTicks,
              kind == .slide ? travelTicks > 0 : travelTicks == 0,
              kind != .hammerOn || semitones > 0,
              kind != .pullOff || semitones < 0 else { throw MusicError.invalidEvent }
        self.kind = kind; self.semitones = semitones; self.startTick = startTick; self.travelTicks = travelTicks
    }
    public func validate(durationTicks: Int64, position: FretPosition) throws {
        guard endTick < durationTicks else { throw MusicError.invalidTime }
        let target = try targetPosition(from: position)
        if kind == .slide, position.fret == 0 || target.fret == 0 { throw MusicError.invalidFret }
    }
    public func targetPosition(from position: FretPosition) throws -> FretPosition {
        try FretPosition(string: position.string, fret: position.fret + semitones)
    }
    public func cents(at tick: Double) -> Double {
        let target = Double(semitones * 100)
        guard travelTicks > 0 else { return tick < Double(startTick) ? 0 : target }
        let fraction = min(1, max(0, (tick - Double(startTick)) / Double(travelTicks)))
        return target * fraction
    }
    /// Abstract pitch reference, not a timbral model of a finger crossing frets.
    /// Phase remains continuous and independent of render chunking or seeking.
    public func integratedMultiplier(to tick: Double, durationTicks: Int64) -> Double {
        let upper = min(Double(durationTicks), max(0, tick))
        let initial = min(upper, Double(startTick))
        guard upper > Double(startTick) else { return initial }
        let multiplier = pow(2, Double(semitones) / 12)
        guard travelTicks > 0 else { return initial + (upper - Double(startTick)) * multiplier }
        let travel = min(Double(travelTicks), upper - Double(startTick))
        let slope = log(multiplier) / Double(travelTicks)
        let changing = expm1(slope * travel) / slope
        return initial + changing + max(0, upper - Double(endTick)) * multiplier
    }
    private enum CodingKeys: String, CodingKey { case kind, semitones, startTick, travelTicks }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: v.decode(Kind.self, forKey: .kind), semitones: v.decode(Int.self, forKey: .semitones),
            startTick: v.decode(Int64.self, forKey: .startTick), travelTicks: v.decodeIfPresent(Int64.self, forKey: .travelTicks) ?? 0)
    }
    public func encode(to encoder: Encoder) throws {
        var v = encoder.container(keyedBy: CodingKeys.self)
        try v.encode(kind, forKey: .kind); try v.encode(semitones, forKey: .semitones); try v.encode(startTick, forKey: .startTick)
        if travelTicks != 0 { try v.encode(travelTicks, forKey: .travelTicks) }
    }
}
