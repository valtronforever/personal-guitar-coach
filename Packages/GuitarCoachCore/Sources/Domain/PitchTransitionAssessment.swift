import Foundation

public struct PitchTransitionPhaseAssessment: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case base, travel, target }
    public let kind: Kind
    public let matchedFraction: Double?
    public let silentFraction: Double
    public let unknownFraction: Double
    public let medianErrorCents: Double?
    public init(kind: Kind, matchedFraction: Double?, silentFraction: Double, unknownFraction: Double, medianErrorCents: Double?) throws {
        guard [silentFraction, unknownFraction].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              matchedFraction.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
              medianErrorCents.map(\.isFinite) ?? true,
              silentFraction + unknownFraction + (matchedFraction ?? 0) <= 1 + 1e-8,
              (matchedFraction == nil) == (unknownFraction > 0.2 + 1e-9) else { throw AssessmentError.invalidResult }
        self.kind = kind; self.matchedFraction = matchedFraction; self.silentFraction = silentFraction
        self.unknownFraction = unknownFraction; self.medianErrorCents = medianErrorCents
    }
    private enum CodingKeys: String, CodingKey { case kind, matchedFraction, silentFraction, unknownFraction, medianErrorCents }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: v.decode(Kind.self, forKey: .kind), matchedFraction: v.decodeIfPresent(Double.self, forKey: .matchedFraction),
            silentFraction: v.decode(Double.self, forKey: .silentFraction), unknownFraction: v.decode(Double.self, forKey: .unknownFraction),
            medianErrorCents: v.decodeIfPresent(Double.self, forKey: .medianErrorCents))
    }
}
public struct PitchTransitionNoteAssessment: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// Raw normalized input clock, including the attempt's actual onset when available.
    public let normalizedStart: Double?
    public let kind: PitchTransition.Kind
    public let phases: [PitchTransitionPhaseAssessment]
    public var score: Double? {
        guard phases.allSatisfy({ $0.matchedFraction != nil }) else { return nil }
        return 100 * phases.compactMap(\.matchedFraction).reduce(0, +) / Double(phases.count)
    }
    public init(id: String, kind: PitchTransition.Kind, normalizedStart: Double?, phases: [PitchTransitionPhaseAssessment]) throws {
        let expected: [PitchTransitionPhaseAssessment.Kind] = kind == .slide ? [.base, .travel, .target] : [.base, .target]
        guard !id.isEmpty, normalizedStart.map(\.isFinite) ?? true,
              phases.map(\.kind) == expected,
              normalizedStart != nil || phases.allSatisfy({ $0.unknownFraction == 1 }) else { throw AssessmentError.invalidResult }
        self.id = id; self.kind = kind; self.normalizedStart = normalizedStart; self.phases = phases
    }
    private enum CodingKeys: String, CodingKey { case id, kind, normalizedStart, phases }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(String.self, forKey: .id), kind: v.decode(PitchTransition.Kind.self, forKey: .kind), normalizedStart: v.decodeIfPresent(Double.self, forKey: .normalizedStart),
            phases: v.decode([PitchTransitionPhaseAssessment].self, forKey: .phases))
    }
}
public struct PitchTransitionAssessment: Codable, Equatable, Sendable {
    public static let currentVersion = "pitch-transition-assessment-1"
    public let version: String
    public let capabilityVersion: String
    public let notes: [PitchTransitionNoteAssessment]
    public var score: Double? {
        guard notes.allSatisfy({ $0.score != nil }) else { return nil }
        return notes.compactMap(\.score).reduce(0, +) / Double(notes.count)
    }
    public init(version: String = Self.currentVersion, capabilityVersion: String = PitchTransitionCapability.version, notes: [PitchTransitionNoteAssessment]) throws {
        guard version == Self.currentVersion, capabilityVersion == PitchTransitionCapability.version,
              !notes.isEmpty, notes.count <= PracticeConfiguration.maximumNotes, Set(notes.map(\.id)).count == notes.count else { throw AssessmentError.invalidResult }
        self.version = version; self.capabilityVersion = capabilityVersion; self.notes = notes
    }
    private enum CodingKeys: String, CodingKey { case version, capabilityVersion, notes }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(version: v.decode(String.self, forKey: .version), capabilityVersion: v.decode(String.self, forKey: .capabilityVersion),
            notes: v.decode([PitchTransitionNoteAssessment].self, forKey: .notes))
    }
}

