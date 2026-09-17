import Foundation

/// Each plateau uses the same measured/ silent/ unknown coverage contract as a held transition target.
public struct LegatoChainNoteAssessment: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let normalizedStart: Double?
    public let semitoneOffsets: [Int]
    public let phases: [PitchTransitionPhaseAssessment]
    public var score: Double? {
        guard phases.allSatisfy({ $0.matchedFraction != nil }) else { return nil }
        return 100 * phases.compactMap(\.matchedFraction).reduce(0, +) / Double(phases.count)
    }
    public init(id: String, normalizedStart: Double?, semitoneOffsets: [Int], phases: [PitchTransitionPhaseAssessment]) throws {
        guard !id.isEmpty, normalizedStart.map(\.isFinite) ?? true,
              (2...9).contains(phases.count), semitoneOffsets.count == phases.count,
              semitoneOffsets.first == 0, semitoneOffsets.allSatisfy({ (-24...24).contains($0) }),
              zip(semitoneOffsets, semitoneOffsets.dropFirst()).allSatisfy({ $0 != $1 && abs($1 - $0) <= 12 }),
              phases.map(\.kind) == [.base] + Array(repeating: .target, count: phases.count - 1),
              normalizedStart != nil || phases.allSatisfy({ $0.unknownFraction == 1 }) else { throw AssessmentError.invalidResult }
        self.id = id; self.normalizedStart = normalizedStart; self.semitoneOffsets = semitoneOffsets; self.phases = phases
    }
    private enum CodingKeys: String, CodingKey { case id, normalizedStart, semitoneOffsets, phases }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(String.self, forKey: .id), normalizedStart: v.decodeIfPresent(Double.self, forKey: .normalizedStart),
            semitoneOffsets: v.decode([Int].self, forKey: .semitoneOffsets), phases: v.decode([PitchTransitionPhaseAssessment].self, forKey: .phases))
    }
}
public struct LegatoChainAssessment: Codable, Equatable, Sendable {
    public static let currentVersion = "legato-chain-assessment-1"
    public let version: String
    public let capabilityVersion: String
    public let notes: [LegatoChainNoteAssessment]
    public var score: Double? {
        guard notes.allSatisfy({ $0.score != nil }) else { return nil }
        return notes.compactMap(\.score).reduce(0, +) / Double(notes.count)
    }
    public init(version: String = Self.currentVersion, capabilityVersion: String = LegatoChainCapability.version, notes: [LegatoChainNoteAssessment]) throws {
        guard version == Self.currentVersion, capabilityVersion == LegatoChainCapability.version,
              !notes.isEmpty, notes.count <= PracticeConfiguration.maximumNotes, Set(notes.map(\.id)).count == notes.count else { throw AssessmentError.invalidResult }
        self.version = version; self.capabilityVersion = capabilityVersion; self.notes = notes
    }
    private enum CodingKeys: String, CodingKey { case version, capabilityVersion, notes }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(version: v.decode(String.self, forKey: .version), capabilityVersion: v.decode(String.self, forKey: .capabilityVersion),
            notes: v.decode([LegatoChainNoteAssessment].self, forKey: .notes))
    }
}
