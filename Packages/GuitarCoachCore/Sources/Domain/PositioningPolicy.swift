import Foundation

public enum PositioningError: String, Error, Equatable, Sendable {
    case invalidPolicy, forbiddenChoice, beyondFretCount, regionUnplayable, incompatibleTuning
}

public struct FretRegion: Codable, Equatable, Hashable, Sendable {
    public let firstFret: Int
    public let windowFrets: Int
    public init(firstFret: Int, windowFrets: Int) throws {
        guard (0...24).contains(firstFret), (1...6).contains(windowFrets) else { throw PositioningError.invalidPolicy }
        self.firstFret = firstFret; self.windowFrets = windowFrets
    }
    public func contains(_ position: FretPosition, maximumFret: Int) -> Bool {
        position.fret >= firstFret && position.fret <= min(firstFret + windowFrets - 1, maximumFret)
    }
    private enum CodingKeys: String, CodingKey { case firstFret, windowFrets }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(firstFret: v.decode(Int.self, forKey: .firstFret), windowFrets: v.decode(Int.self, forKey: .windowFrets))
    }
}

public enum PositionChoice: Equatable, Hashable, Sendable, Codable {
    case original, region(firstFret: Int)
    public var firstFret: Int? { if case let .region(fret) = self { return fret }; return nil }
    private enum CodingKeys: String, CodingKey { case kind, firstFret }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        switch try v.decode(String.self, forKey: .kind) {
        case "original":
            guard !v.contains(.firstFret) else { throw PositioningError.invalidPolicy }; self = .original
        case "region":
            let fret = try v.decode(Int.self, forKey: .firstFret)
            guard (0...24).contains(fret) else { throw PositioningError.invalidPolicy }; self = .region(firstFret: fret)
        default: throw PositioningError.invalidPolicy
        }
    }
    public func encode(to encoder: Encoder) throws {
        var v = encoder.container(keyedBy: CodingKeys.self)
        try v.encode(firstFret == nil ? "original" : "region", forKey: .kind)
        try v.encodeIfPresent(firstFret, forKey: .firstFret)
    }
}

public enum AllowedPositionStarts: Equatable, Sendable, Codable {
    case auto, explicit([Int]), range(minimum: Int, maximum: Int, step: Int)
    public var starts: [Int] {
        switch self {
        case .auto: return Array(0...24)
        case let .explicit(values): return values
        case let .range(minimum, maximum, step):
            guard step > 0, minimum <= maximum else { return [] }
            return Array(stride(from: minimum, through: maximum, by: step))
        }
    }
    public func validate() throws {
        switch self {
        case .auto: break
        case let .explicit(values):
            guard !values.isEmpty, values == Array(Set(values)).sorted(), values.allSatisfy({ (0...24).contains($0) }) else { throw PositioningError.invalidPolicy }
        case let .range(minimum, maximum, step):
            guard (0...24).contains(minimum), (minimum...24).contains(maximum), (1...24).contains(step) else { throw PositioningError.invalidPolicy }
        }
    }
    private enum CodingKeys: String, CodingKey { case kind, frets, minimum, maximum, step }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        switch try v.decode(String.self, forKey: .kind) {
        case "auto":
            guard v.allKeys == [.kind] else { throw PositioningError.invalidPolicy }; self = .auto
        case "explicit":
            guard Set(v.allKeys) == [.kind, .frets] else { throw PositioningError.invalidPolicy }
            self = .explicit(try v.decode([Int].self, forKey: .frets))
        case "range":
            guard !v.contains(.frets) else { throw PositioningError.invalidPolicy }
            self = .range(minimum: try v.decode(Int.self, forKey: .minimum), maximum: try v.decode(Int.self, forKey: .maximum), step: try v.decodeIfPresent(Int.self, forKey: .step) ?? 1)
        default: throw PositioningError.invalidPolicy
        }
        try validate()
    }
    public func encode(to encoder: Encoder) throws {
        var v = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .auto: try v.encode("auto", forKey: .kind)
        case let .explicit(values): try v.encode("explicit", forKey: .kind); try v.encode(values, forKey: .frets)
        case let .range(minimum, maximum, step):
            try v.encode("range", forKey: .kind); try v.encode(minimum, forKey: .minimum)
            try v.encode(maximum, forKey: .maximum); try v.encode(step, forKey: .step)
        }
    }
}

/// Authored permission is also frozen in attempt evidence; it has no UI or storage dependency.
public struct PositioningPolicy: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let preserve: String?
    public let windowFrets: Int?
    public let allowedStarts: AllowedPositionStarts?
    public let allowOriginal: Bool?
    public static let disabled = PositioningPolicy()
    public init() { enabled = false; preserve = nil; windowFrets = nil; allowedStarts = nil; allowOriginal = nil }
    public init(windowFrets: Int = 5, allowedStarts: AllowedPositionStarts = .auto, allowOriginal: Bool = true) throws {
        enabled = true; preserve = "soundingPitch"; self.windowFrets = windowFrets
        self.allowedStarts = allowedStarts; self.allowOriginal = allowOriginal; try validate()
    }
    public func validate() throws {
        guard enabled else {
            guard preserve == nil, windowFrets == nil, allowedStarts == nil, allowOriginal == nil else { throw PositioningError.invalidPolicy }; return
        }
        guard preserve == "soundingPitch", let windowFrets, (1...6).contains(windowFrets), let allowedStarts, allowOriginal != nil else { throw PositioningError.invalidPolicy }
        try allowedStarts.validate()
    }
    public func permits(_ choice: PositionChoice) -> Bool {
        switch choice {
        case .original: return !enabled || allowOriginal == true
        case let .region(fret): return enabled && (allowedStarts?.starts.contains(fret) ?? false)
        }
    }
    public func region(for choice: PositionChoice) throws -> FretRegion? {
        try validate()
        guard permits(choice) else { throw PositioningError.forbiddenChoice }
        guard let first = choice.firstFret, let width = windowFrets else { return nil }
        return try FretRegion(firstFret: first, windowFrets: width)
    }
    public var choices: [PositionChoice] {
        (permits(.original) ? [.original] : []) + (enabled ? (allowedStarts?.starts ?? []).map { .region(firstFret: $0) } : [])
    }
    private enum CodingKeys: String, CodingKey { case enabled, preserve, windowFrets, allowedStarts, allowOriginal }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try v.decode(Bool.self, forKey: .enabled); preserve = try v.decodeIfPresent(String.self, forKey: .preserve)
        windowFrets = try v.decodeIfPresent(Int.self, forKey: .windowFrets); allowedStarts = try v.decodeIfPresent(AllowedPositionStarts.self, forKey: .allowedStarts)
        allowOriginal = try v.decodeIfPresent(Bool.self, forKey: .allowOriginal); try validate()
    }
}

public struct ExerciseSourceMapping: Codable, Equatable, Sendable {
    public let exerciseID: String
    public let exerciseVersion: Int
    public let startTick: Int64
    public let eventIDs: [String]
    public init(exerciseID: String, exerciseVersion: Int, startTick: Int64, eventIDs: [String]) {
        self.exerciseID = exerciseID; self.exerciseVersion = exerciseVersion; self.startTick = startTick; self.eventIDs = eventIDs
    }
}


/// Explicit learner self-report, separate from any claim made by audio assessment.
public struct PositionSelfConfirmation: Codable, Equatable, Sendable {
    public let choice: PositionChoice
    public let tuning: TuningProfile
    public let frets: GuitarFretCount
    public init(choice: PositionChoice, tuning: TuningProfile, frets: GuitarFretCount) {
        self.choice = choice; self.tuning = tuning; self.frets = frets
    }
}
