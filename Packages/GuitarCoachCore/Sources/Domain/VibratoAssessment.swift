import Foundation


/// Robust audible span, lower pitch and cycle regularity. Missing cycles with known audio are a
/// musical failure (for example a flat note), not automatically unavailable signal.
public struct VibratoModulationMetrics: Codable, Equatable, Sendable {
    public let lowCents: Double?
    public let widthCents: Double?
    public let slowestRateHz: Double?
    public let fastestRateHz: Double?
    public let rateHz: Double?
    public let periodVariation: Double?
    public let measuredPeriods: Int
    public init(lowCents: Double?, widthCents: Double?, rateHz: Double?, periodVariation: Double?, measuredPeriods: Int, slowestRateHz: Double? = nil, fastestRateHz: Double? = nil) throws {
        guard lowCents.map(\.isFinite) ?? true,
              widthCents.map({ $0.isFinite && $0 >= 0 }) ?? true,
              rateHz.map({ $0.isFinite && $0 > 0 }) ?? true,
              [slowestRateHz, fastestRateHz].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 }),
              (slowestRateHz == nil) == (rateHz == nil), (fastestRateHz == nil) == (rateHz == nil),
              rateHz == nil || (slowestRateHz! <= rateHz! && rateHz! <= fastestRateHz!),
              periodVariation.map({ $0.isFinite && $0 >= 0 }) ?? true,
              (0...SustainTrace.maximumFrames).contains(measuredPeriods),
              (lowCents == nil) == (widthCents == nil), (rateHz == nil) == (periodVariation == nil),
              (measuredPeriods >= 2) == (rateHz != nil),
              measuredPeriods == 0 || (widthCents ?? 0) >= 5 else { throw AssessmentError.invalidResult }
        self.slowestRateHz = slowestRateHz; self.fastestRateHz = fastestRateHz
        self.lowCents = lowCents; self.widthCents = widthCents; self.rateHz = rateHz
        self.periodVariation = periodVariation; self.measuredPeriods = measuredPeriods
    }
    private enum CodingKeys: String, CodingKey { case lowCents, widthCents, rateHz, periodVariation, measuredPeriods, slowestRateHz, fastestRateHz }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(lowCents: v.decodeIfPresent(Double.self, forKey: .lowCents), widthCents: v.decodeIfPresent(Double.self, forKey: .widthCents),
            rateHz: v.decodeIfPresent(Double.self, forKey: .rateHz), periodVariation: v.decodeIfPresent(Double.self, forKey: .periodVariation),
            measuredPeriods: v.decode(Int.self, forKey: .measuredPeriods),
            slowestRateHz: v.decodeIfPresent(Double.self, forKey: .slowestRateHz), fastestRateHz: v.decodeIfPresent(Double.self, forKey: .fastestRateHz))
    }
}

public struct VibratoPhaseAssessment: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case base, modulation, returned }
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
public struct VibratoNoteAssessment: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// Raw normalized input clock, including the attempt's actual onset when available.
    public let normalizedStart: Double?
    public let modulation: VibratoModulationMetrics
    public let phases: [VibratoPhaseAssessment]
    public var score: Double? {
        guard phases.allSatisfy({ $0.matchedFraction != nil }) else { return nil }
        return 100 * phases.compactMap(\.matchedFraction).reduce(0, +) / Double(phases.count)
    }
    public init(id: String, normalizedStart: Double?, phases: [VibratoPhaseAssessment], modulation: VibratoModulationMetrics) throws {
        let expected: [VibratoPhaseAssessment.Kind] = [.base, .modulation, .returned]
        guard !id.isEmpty, normalizedStart.map(\.isFinite) ?? true,
              phases.map(\.kind) == expected,
              normalizedStart != nil || (phases.allSatisfy({ $0.unknownFraction == 1 }) && modulation.widthCents == nil),
              (phases[1].matchedFraction ?? 0) == 0 || modulation.rateHz != nil else { throw AssessmentError.invalidResult }
        self.id = id; self.normalizedStart = normalizedStart; self.phases = phases; self.modulation = modulation
    }
    private enum CodingKeys: String, CodingKey { case id, normalizedStart, phases, modulation }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(String.self, forKey: .id), normalizedStart: v.decodeIfPresent(Double.self, forKey: .normalizedStart),
            phases: v.decode([VibratoPhaseAssessment].self, forKey: .phases),
            modulation: v.decode(VibratoModulationMetrics.self, forKey: .modulation))
    }
}
public struct VibratoAssessment: Codable, Equatable, Sendable {
    public static let currentVersion = "vibrato-assessment-1"
    public let version: String
    public let capabilityVersion: String
    public let notes: [VibratoNoteAssessment]
    public var score: Double? {
        guard notes.allSatisfy({ $0.score != nil }) else { return nil }
        return notes.compactMap(\.score).reduce(0, +) / Double(notes.count)
    }
    public init(version: String = Self.currentVersion, capabilityVersion: String = VibratoCapability.version, notes: [VibratoNoteAssessment]) throws {
        guard version == Self.currentVersion, capabilityVersion == VibratoCapability.version,
              !notes.isEmpty, notes.count <= PracticeConfiguration.maximumNotes, Set(notes.map(\.id)).count == notes.count else { throw AssessmentError.invalidResult }
        self.version = version; self.capabilityVersion = capabilityVersion; self.notes = notes
    }
    private enum CodingKeys: String, CodingKey { case version, capabilityVersion, notes }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(version: v.decode(String.self, forKey: .version), capabilityVersion: v.decode(String.self, forKey: .capabilityVersion),
            notes: v.decode([VibratoNoteAssessment].self, forKey: .notes))
    }
}

