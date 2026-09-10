import Foundation

/// Independent measured pitch. The expected fret/string is deliberately absent.
public struct PracticeAttack: Codable, Equatable, Sendable, Identifiable {
    public let id: UInt64
    public let normalizedOnset: Double
    public let frequency: Double?
    public let clarity: Double?
    public let reliable: Bool
    public init(id: UInt64, normalizedOnset: Double, frequency: Double?, clarity: Double?, reliable: Bool) throws {
        guard id > 0, normalizedOnset.isFinite,
              frequency.map({ $0.isFinite && $0 > 0 }) ?? true,
              clarity.map({ $0.isFinite && (0...1).contains($0) }) ?? true,
              !reliable || (frequency != nil && (clarity ?? 0) >= 0.9) else { throw PracticeError.invalidEvidence }
        self.id = id; self.normalizedOnset = normalizedOnset; self.frequency = frequency; self.clarity = clarity; self.reliable = reliable
    }
}

public struct PracticeClippingInterval: Codable, Equatable, Sendable {
    public let start: Double
    public let end: Double
    public init(start: Double, end: Double) throws {
        guard start.isFinite, end.isFinite, start <= end else { throw PracticeError.invalidEvidence }
        self.start = start; self.end = end
    }
}

/// A closed attempt, ready for the task 17 evaluator. Completion does not itself imply a score.
public struct PracticeEvidence: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let configuration: PracticeConfiguration
    public let startedAt: Date
    public let finishedAt: Date
    public let phase: PracticePhase
    public let reason: PracticeStopReason?
    public let signalConfirmed: Bool
    public let renderEpochSeconds: Double?
    public let maximumClockDriftSeconds: Double?
    public let attacks: [PracticeAttack]
    public let clipping: [PracticeClippingInterval]
    public let uncertainSignal: [PracticeUncertainSpan]
    public let analysisVersion: String
    public init(id: UUID, configuration: PracticeConfiguration, startedAt: Date, finishedAt: Date,
                phase: PracticePhase, reason: PracticeStopReason?, signalConfirmed: Bool, renderEpochSeconds: Double?,
                maximumClockDriftSeconds: Double?, attacks: [PracticeAttack], clipping: [PracticeClippingInterval], uncertainSignal: [PracticeUncertainSpan] = [], analysisVersion: String) throws {
        guard !phase.active, phase != .idle, startedAt.timeIntervalSinceReferenceDate.isFinite,
              finishedAt.timeIntervalSinceReferenceDate.isFinite, finishedAt >= startedAt,
              renderEpochSeconds.map({ $0.isFinite && $0 >= 0 }) ?? true,
              maximumClockDriftSeconds.map({ $0.isFinite && $0 >= 0 }) ?? true,
              !analysisVersion.isEmpty, analysisVersion.utf8.count <= 256,
              attacks.count <= PracticeConfiguration.maximumObservations, clipping.count <= 4096, uncertainSignal.count <= 4096 - clipping.count,
              Set(attacks.map(\.id)).count == attacks.count,
              zip(attacks, attacks.dropFirst()).allSatisfy({ $0.normalizedOnset <= $1.normalizedOnset }),
              phase != .completed || (signalConfirmed && renderEpochSeconds != nil && reason == nil),
              phase == .completed || reason != nil else { throw PracticeError.invalidEvidence }
        self.id = id; self.configuration = configuration; self.startedAt = startedAt; self.finishedAt = finishedAt
        self.phase = phase; self.reason = reason; self.signalConfirmed = signalConfirmed; self.renderEpochSeconds = renderEpochSeconds
        self.maximumClockDriftSeconds = maximumClockDriftSeconds; self.attacks = attacks; self.clipping = clipping
        self.uncertainSignal = uncertainSignal; self.analysisVersion = analysisVersion
    }
}

extension PracticeAttack {
    private enum CodingKeys: String, CodingKey { case id, normalizedOnset, frequency, clarity, reliable }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(UInt64.self, forKey: .id),
            normalizedOnset: v.decode(Double.self, forKey: .normalizedOnset),
            frequency: v.decodeIfPresent(Double.self, forKey: .frequency),
            clarity: v.decodeIfPresent(Double.self, forKey: .clarity),
            reliable: v.decode(Bool.self, forKey: .reliable))
    }
}

extension PracticeClippingInterval {
    private enum CodingKeys: String, CodingKey { case start, end }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(start: v.decode(Double.self, forKey: .start),
            end: v.decode(Double.self, forKey: .end))
    }
}

extension PracticeEvidence {
    private enum CodingKeys: String, CodingKey { case id, configuration, startedAt, finishedAt, phase, reason, signalConfirmed, renderEpochSeconds, maximumClockDriftSeconds, attacks, clipping, uncertainSignal, analysisVersion }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(UUID.self, forKey: .id),
            configuration: v.decode(PracticeConfiguration.self, forKey: .configuration),
            startedAt: v.decode(Date.self, forKey: .startedAt),
            finishedAt: v.decode(Date.self, forKey: .finishedAt),
            phase: v.decode(PracticePhase.self, forKey: .phase),
            reason: v.decodeIfPresent(PracticeStopReason.self, forKey: .reason),
            signalConfirmed: v.decode(Bool.self, forKey: .signalConfirmed),
            renderEpochSeconds: v.decodeIfPresent(Double.self, forKey: .renderEpochSeconds),
            maximumClockDriftSeconds: v.decodeIfPresent(Double.self, forKey: .maximumClockDriftSeconds),
            attacks: v.decode([PracticeAttack].self, forKey: .attacks),
            clipping: v.decode([PracticeClippingInterval].self, forKey: .clipping),
            uncertainSignal: v.decodeIfPresent([PracticeUncertainSpan].self, forKey: .uncertainSignal) ?? [],
            analysisVersion: v.decode(String.self, forKey: .analysisVersion))
    }
}


/// Non-silent input for which no reliable pitch was available. Normal attack settling may also appear here.
public struct PracticeUncertainSpan: Codable, Equatable, Sendable {
    public enum Reason: String, Codable, Sendable { case quiet, unstable, ambiguous, outOfRange, warmingUp }
    public let interval: PracticeClippingInterval
    public let reason: Reason
    public init(interval: PracticeClippingInterval, reason: Reason) { self.interval = interval; self.reason = reason }
}
