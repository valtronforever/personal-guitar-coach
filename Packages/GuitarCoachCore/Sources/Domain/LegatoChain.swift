import Foundation

/// One initial attack followed by authored same-string pitch changes. Technique cues are instructions,
/// not claims that the audio proves a particular hand or finger motion.
public struct LegatoChain: Hashable, Codable, Sendable {
    public struct Target: Hashable, Codable, Sendable {
        public enum Kind: String, Codable, CaseIterable, Sendable { case hammerOn, pullOff, tap }
        public let kind: Kind
        /// Signed distance from the preceding pitch, not from the initial note.
        public let semitones: Int
        public let startTick: Int64
        public init(kind: Kind, semitones: Int, startTick: Int64) throws {
            guard (-12...12).contains(semitones), semitones != 0, startTick > 0,
                  kind == .pullOff ? semitones < 0 : semitones > 0 else { throw MusicError.invalidEvent }
            self.kind = kind; self.semitones = semitones; self.startTick = startTick
        }
        private enum CodingKeys: String, CodingKey { case kind, semitones, startTick }
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(kind: values.decode(Kind.self, forKey: .kind), semitones: values.decode(Int.self, forKey: .semitones),
                          startTick: values.decode(Int64.self, forKey: .startTick))
        }
    }
    private struct Plateau: Sendable {
        let tick: Int64
        let semitones: Int
        let multiplier: Double
        let integral: Double
    }
    public static let maximumTargets = 8
    public let targets: [Target]
    /// Derived once outside rendering; never encoded as authored or historical data.
    private let plateaus: [Plateau]
    public init(targets: [Target]) throws {
        guard !targets.isEmpty, targets.count <= Self.maximumTargets,
              zip(targets, targets.dropFirst()).allSatisfy({ $0.startTick < $1.startTick }) else { throw MusicError.invalidEvent }
        var phases = [Plateau(tick: 0, semitones: 0, multiplier: 1, integral: 0)]
        for target in targets {
            let previous = phases.last!, offset = previous.semitones + target.semitones
            guard (-24...24).contains(offset) else { throw MusicError.invalidFret }
            phases.append(Plateau(tick: target.startTick, semitones: offset, multiplier: pow(2, Double(offset) / 12),
                integral: previous.integral + Double(target.startTick - previous.tick) * previous.multiplier))
        }
        self.targets = targets; plateaus = phases
    }
    public func validate(durationTicks: Int64, position: FretPosition) throws {
        guard targets.last!.startTick < durationTicks else { throw MusicError.invalidTime }
        _ = try positions(from: position)
    }
    public func positions(from position: FretPosition) throws -> [FretPosition] {
        try plateaus.map { try FretPosition(string: position.string, fret: position.fret + $0.semitones) }
    }
    public var semitoneOffsets: [Int] { plateaus.map(\.semitones) }
    public var boundaryTicks: [Int64] { plateaus.map(\.tick) }
    private func phase(at tick: Double) -> Plateau {
        var lower = 0, upper = plateaus.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if Double(plateaus[middle].tick) <= tick { lower = middle + 1 } else { upper = middle }
        }
        return plateaus[max(0, lower - 1)]
    }
    public func cents(at tick: Double) -> Double { Double(phase(at: tick).semitones * 100) }
    /// Continuous oscillator phase with O(log(target count)) lookup and no per-sample allocations/pow.
    public func integratedMultiplier(to tick: Double, durationTicks: Int64) -> Double {
        let upper = min(Double(durationTicks), max(0, tick)), phase = phase(at: upper)
        return phase.integral + (upper - Double(phase.tick)) * phase.multiplier
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.targets == rhs.targets }
    public func hash(into hasher: inout Hasher) { hasher.combine(targets) }
    private enum CodingKeys: String, CodingKey { case targets }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(targets: values.decode([Target].self, forKey: .targets))
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(targets, forKey: .targets)
    }
}
