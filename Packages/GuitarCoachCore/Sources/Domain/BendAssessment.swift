import Foundation

public struct BendPhaseAssessment: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case base, rise, target, release, returned }
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
public struct BendNoteAssessment: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    /// Raw normalized input clock, including the attempt's actual onset when available.
    public let normalizedStart: Double?
    public let phases: [BendPhaseAssessment]
    public var score: Double? {
        guard phases.allSatisfy({ $0.matchedFraction != nil }) else { return nil }
        return 100 * phases.compactMap(\.matchedFraction).reduce(0, +) / Double(phases.count)
    }
    public init(id: String, normalizedStart: Double?, phases: [BendPhaseAssessment]) throws {
        let basic: [BendPhaseAssessment.Kind] = [.base, .rise, .target]
        guard !id.isEmpty, normalizedStart.map(\.isFinite) ?? true,
              phases.map(\.kind) == basic || phases.map(\.kind) == basic + [.release, .returned],
              normalizedStart != nil || phases.allSatisfy({ $0.unknownFraction == 1 }) else { throw AssessmentError.invalidResult }
        self.id = id; self.normalizedStart = normalizedStart; self.phases = phases
    }
    private enum CodingKeys: String, CodingKey { case id, normalizedStart, phases }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(String.self, forKey: .id), normalizedStart: v.decodeIfPresent(Double.self, forKey: .normalizedStart),
            phases: v.decode([BendPhaseAssessment].self, forKey: .phases))
    }
}
public struct BendAssessment: Codable, Equatable, Sendable {
    public static let currentVersion = "bend-assessment-1"
    public let version: String
    public let capabilityVersion: String
    public let notes: [BendNoteAssessment]
    public var score: Double? {
        guard notes.allSatisfy({ $0.score != nil }) else { return nil }
        return notes.compactMap(\.score).reduce(0, +) / Double(notes.count)
    }
    public init(version: String = Self.currentVersion, capabilityVersion: String = BendCapability.version, notes: [BendNoteAssessment]) throws {
        guard version == Self.currentVersion, capabilityVersion == BendCapability.version,
              !notes.isEmpty, notes.count <= PracticeConfiguration.maximumNotes, Set(notes.map(\.id)).count == notes.count else { throw AssessmentError.invalidResult }
        self.version = version; self.capabilityVersion = capabilityVersion; self.notes = notes
    }
    private enum CodingKeys: String, CodingKey { case version, capabilityVersion, notes }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(version: v.decode(String.self, forKey: .version), capabilityVersion: v.decode(String.self, forKey: .capabilityVersion),
            notes: v.decode([BendNoteAssessment].self, forKey: .notes))
    }
}

extension PracticeEvidence {
    /// Spectral-flux events inside a bend cannot establish additional pick attacks.
    /// Keep these observations in evidence, but exclude them from extra-attack penalties.
    public func bendObservationIDs(notes: [AssessedNote]) -> Set<UInt64> {
        movingPitchObservationIDs(notes: notes, transitions: false)
    }
    /// Pitch motion can itself produce spectral flux; these events do not prove a repick.
    public func pitchTransitionObservationIDs(notes: [AssessedNote]) -> Set<UInt64> {
        movingPitchObservationIDs(notes: notes, transitions: true)
    }
    private func movingPitchObservationIDs(notes: [AssessedNote], transitions: Bool) -> Set<UInt64> {
        guard let epoch = renderEpochSeconds else { return [] }
        let offset = configuration.calibration?.residualOffsetSeconds ?? 0
        let secondsPerTick = configuration.exercise.timeSignature.secondsPerTick(bpm: configuration.bpm)
        let notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let attacksByID = Dictionary(uniqueKeysWithValues: attacks.map { ($0.id, $0) })
        let intervals: [Range<Double>] = configuration.selectedEvents.compactMap { event in
            guard let changeTick = transitions ? event.pitchTransition?.startTick : event.bend?.riseStartTick,
                  let start = try? configuration.route.expectedTime(renderEpochSeconds: epoch,
                    sampleFrame: Int64(((configuration.countInSeconds + Double(event.startTick - configuration.range.lowerBound) * secondsPerTick) * configuration.route.output.sampleRate).rounded())) else { return nil }
            let observedStart = notesByID[event.id]?.attackID.flatMap { attacksByID[$0]?.normalizedOnset } ?? start + offset
            return (observedStart + Double(changeTick) * secondsPerTick - 0.06)..<(observedStart + Double(event.durationTicks) * secondsPerTick)
        }
        guard !intervals.isEmpty else { return [] }
        return Set(attacks.filter { attack in intervals.contains { $0.contains(attack.normalizedOnset) } }.map(\.id))
    }
}
