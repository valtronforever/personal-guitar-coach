import Foundation

public enum AssessmentError: Error, Equatable, Sendable { case invalidResult, unsupportedVersion(String) }
public enum AssessmentValidity: String, Codable, Sendable { case valid, uncalibrated, insufficientSignal, interrupted }

/// Frozen v1 parameters. Changes require a new version and explicit evaluation, never history regrading.
public struct AssessmentParameters: Codable, Equatable, Sendable {
    public let version: String
    public let pitchToleranceCents: Double
    public let rhythmToleranceSeconds: Double
    public let rhythmIntervalFraction: Double
    public let maximumMatchSeconds: Double
    public let matchIntervalFraction: Double
    public let uncertaintyFraction: Double
    public let pitchWeight: Double
    public let extraPenalty: Double
    public let onsetUncertaintySeconds: Double
    public static let current = AssessmentParameters()
    private init() {
        version = "monophonic-assessment-1"; pitchToleranceCents = 50; rhythmToleranceSeconds = 0.1
        rhythmIntervalFraction = 0.45; maximumMatchSeconds = 0.3; matchIntervalFraction = 0.49
        uncertaintyFraction = 0.2; pitchWeight = 0.6; extraPenalty = 20; onsetUncertaintySeconds = 0.03
    }
    private enum CodingKeys: String, CodingKey {
        case version, pitchToleranceCents, rhythmToleranceSeconds, rhythmIntervalFraction, maximumMatchSeconds
        case matchIntervalFraction, uncertaintyFraction, pitchWeight, extraPenalty, onsetUncertaintySeconds
    }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        let version = try v.decode(String.self, forKey: .version)
        guard version == Self.current.version else { throw AssessmentError.unsupportedVersion(version) }
        self.init()
        let fields: [(CodingKeys, Double)] = [(.pitchToleranceCents, pitchToleranceCents), (.rhythmToleranceSeconds, rhythmToleranceSeconds),
            (.rhythmIntervalFraction, rhythmIntervalFraction), (.maximumMatchSeconds, maximumMatchSeconds),
            (.matchIntervalFraction, matchIntervalFraction), (.uncertaintyFraction, uncertaintyFraction),
            (.pitchWeight, pitchWeight), (.extraPenalty, extraPenalty), (.onsetUncertaintySeconds, onsetUncertaintySeconds)]
        for (key, value) in fields { guard try v.decode(Double.self, forKey: key) == value else { throw AssessmentError.invalidResult } }
    }
}

public struct AssessedNote: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let attackID: UInt64?
    public let targetFrequency: Double
    public let centsError: Double?
    /// Nil when rhythm calibration is ineligible. Positive is late.
    public let timingErrorSeconds: Double?
    public let uncertain: Bool
    public init(id: String, attackID: UInt64?, targetFrequency: Double, centsError: Double?, timingErrorSeconds: Double?, uncertain: Bool) throws {
        guard !id.isEmpty, attackID.map({ $0 > 0 }) ?? true, targetFrequency.isFinite, targetFrequency > 0,
              centsError.map(\.isFinite) ?? true, timingErrorSeconds.map(\.isFinite) ?? true,
              attackID != nil || (centsError == nil && timingErrorSeconds == nil),
              !uncertain || (centsError == nil && timingErrorSeconds == nil) else { throw AssessmentError.invalidResult }
        self.id = id; self.attackID = attackID; self.targetFrequency = targetFrequency; self.centsError = centsError
        self.timingErrorSeconds = timingErrorSeconds; self.uncertain = uncertain
    }
}

public struct AssessedExtra: Codable, Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let restID: String?
    public let uncertain: Bool
    public init(id: UInt64, restID: String?, uncertain: Bool) throws {
        guard id > 0, restID.map({ !$0.isEmpty }) ?? true else { throw AssessmentError.invalidResult }
        self.id = id; self.restID = restID; self.uncertain = uncertain
    }
}

/// Immutable evaluation and its exact inputs. Codable decoding validates structure without recomputing a grade.
public struct AssessedPractice: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID { evidence.id }
    public let evidence: PracticeEvidence
    public let parameters: AssessmentParameters
    public let validity: AssessmentValidity
    public let rhythmCapability: RhythmCapability
    public let rhythmToleranceSeconds: Double
    public let notes: [AssessedNote]
    public let extras: [AssessedExtra]
    public let overallScore: Double?
    public let pitchScore: Double?
    public let timingScore: Double?
    public var expectedCount: Int { notes.count }
    public var matchedCount: Int { notes.filter { $0.attackID != nil }.count }
    public var missedCount: Int { expectedCount - matchedCount }
    public var uncertainCount: Int { notes.filter(\.uncertain).count }
    public var uncertainExtraCount: Int { extras.filter(\.uncertain).count }
    public var meanSignedTimingSeconds: Double? { Self.mean(notes.compactMap(\.timingErrorSeconds)) }
    public var medianSignedTimingSeconds: Double? { Self.median(notes.compactMap(\.timingErrorSeconds)) }
    public var medianAbsolutePitchCents: Double? { Self.median(notes.compactMap(\.centsError).map(abs)) }

    public init(evidence: PracticeEvidence, parameters: AssessmentParameters = .current, validity: AssessmentValidity,
                rhythmCapability: RhythmCapability, rhythmToleranceSeconds: Double, notes: [AssessedNote], extras: [AssessedExtra],
                overallScore: Double?, pitchScore: Double?, timingScore: Double?) throws {
        let expected = evidence.configuration.selectedEvents.filter { $0.kind == .note }
        let ids = notes.compactMap(\.attackID) + extras.map(\.id)
        let attacks = Set(evidence.attacks.map(\.id))
        guard notes.map(\.id) == expected.map(\.id), !notes.isEmpty,
              Set(ids).count == ids.count, Set(ids).isSubset(of: attacks),
              rhythmToleranceSeconds.isFinite, rhythmToleranceSeconds > 0, rhythmToleranceSeconds <= parameters.rhythmToleranceSeconds,
              [overallScore, pitchScore, timingScore].compactMap({ $0 }).allSatisfy({ $0.isFinite && (0...100).contains($0) }),
              rhythmCapability == .available || notes.allSatisfy({ $0.timingErrorSeconds == nil }),
              extras.allSatisfy({ extra in extra.restID.map { id in evidence.configuration.selectedEvents.contains { $0.id == id && $0.kind == .rest } } ?? true }) else {
            throw AssessmentError.invalidResult
        }
        let tuning = evidence.configuration.exercise.requiredTuning ?? evidence.configuration.instrument.tuning
        let targets = try expected.map { try tuning.pitch(at: $0.positions[0]).frequency(referenceA4: tuning.referenceA4) }
        guard notes.map(\.targetFrequency) == targets else { throw AssessmentError.invalidResult }
        let indices = Dictionary(uniqueKeysWithValues: evidence.attacks.enumerated().map { ($0.element.id, $0.offset) })
        let assigned = notes.compactMap(\.attackID).compactMap { indices[$0] }
        guard zip(assigned, assigned.dropFirst()).allSatisfy({ $0 < $1 }) else { throw AssessmentError.invalidResult }
        if let epoch = evidence.renderEpochSeconds {
            let window = try evidence.configuration.observationWindow(renderEpochSeconds: epoch)
            let offset = evidence.configuration.calibration?.residualOffsetSeconds ?? 0
            let eligible = Set(evidence.attacks.filter { window.contains($0.normalizedOnset - offset) }.map(\.id))
            guard Set(ids) == eligible else { throw AssessmentError.invalidResult }
        } else if !ids.isEmpty { throw AssessmentError.invalidResult }
        switch validity {
        case .valid:
            guard evidence.phase == .completed, rhythmCapability == .available,
                  overallScore != nil, pitchScore != nil, timingScore != nil else { throw AssessmentError.invalidResult }
        case .uncalibrated:
            guard evidence.phase == .completed, rhythmCapability != .available,
                  overallScore == nil, timingScore == nil, pitchScore != nil else { throw AssessmentError.invalidResult }
        case .insufficientSignal, .interrupted:
            guard overallScore == nil, pitchScore == nil, timingScore == nil else { throw AssessmentError.invalidResult }
        }
        self.evidence = evidence; self.parameters = parameters; self.validity = validity; self.rhythmCapability = rhythmCapability
        self.rhythmToleranceSeconds = rhythmToleranceSeconds; self.notes = notes; self.extras = extras
        self.overallScore = overallScore; self.pitchScore = pitchScore; self.timingScore = timingScore
    }
    private static func mean(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }; let sorted = values.sorted(), middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}

extension AssessedNote {
    private enum CodingKeys: String, CodingKey { case id, attackID, targetFrequency, centsError, timingErrorSeconds, uncertain }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(String.self, forKey: .id),
            attackID: v.decodeIfPresent(UInt64.self, forKey: .attackID),
            targetFrequency: v.decode(Double.self, forKey: .targetFrequency),
            centsError: v.decodeIfPresent(Double.self, forKey: .centsError),
            timingErrorSeconds: v.decodeIfPresent(Double.self, forKey: .timingErrorSeconds),
            uncertain: v.decode(Bool.self, forKey: .uncertain))
    }
}

extension AssessedExtra {
    private enum CodingKeys: String, CodingKey { case id, restID, uncertain }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(UInt64.self, forKey: .id),
            restID: v.decodeIfPresent(String.self, forKey: .restID),
            uncertain: v.decode(Bool.self, forKey: .uncertain))
    }
}

extension AssessedPractice {
    private enum CodingKeys: String, CodingKey { case evidence, parameters, validity, rhythmCapability, rhythmToleranceSeconds, notes, extras, overallScore, pitchScore, timingScore }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(evidence: v.decode(PracticeEvidence.self, forKey: .evidence),
            parameters: v.decode(AssessmentParameters.self, forKey: .parameters),
            validity: v.decode(AssessmentValidity.self, forKey: .validity),
            rhythmCapability: v.decode(RhythmCapability.self, forKey: .rhythmCapability),
            rhythmToleranceSeconds: v.decode(Double.self, forKey: .rhythmToleranceSeconds),
            notes: v.decode([AssessedNote].self, forKey: .notes),
            extras: v.decode([AssessedExtra].self, forKey: .extras),
            overallScore: v.decodeIfPresent(Double.self, forKey: .overallScore),
            pitchScore: v.decodeIfPresent(Double.self, forKey: .pitchScore),
            timingScore: v.decodeIfPresent(Double.self, forKey: .timingScore))
    }
}
