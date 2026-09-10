import Foundation

/// Independent measured pitch. The expected fret/string is deliberately absent.
public struct PracticeAttack: Equatable, Sendable, Identifiable {
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

public struct PracticeClippingInterval: Equatable, Sendable {
    public let start: Double
    public let end: Double
    public init(start: Double, end: Double) throws {
        guard start.isFinite, end.isFinite, start <= end else { throw PracticeError.invalidEvidence }
        self.start = start; self.end = end
    }
}

/// A closed attempt, ready for the task 17 evaluator. Completion does not itself imply a score.
public struct PracticeEvidence: Equatable, Sendable, Identifiable {
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
    public let analysisVersion: String
    public init(id: UUID, configuration: PracticeConfiguration, startedAt: Date, finishedAt: Date,
                phase: PracticePhase, reason: PracticeStopReason?, signalConfirmed: Bool, renderEpochSeconds: Double?,
                maximumClockDriftSeconds: Double?, attacks: [PracticeAttack], clipping: [PracticeClippingInterval], analysisVersion: String) throws {
        guard !phase.active, phase != .idle, startedAt.timeIntervalSinceReferenceDate.isFinite,
              finishedAt.timeIntervalSinceReferenceDate.isFinite, finishedAt >= startedAt,
              renderEpochSeconds.map({ $0.isFinite && $0 >= 0 }) ?? true,
              maximumClockDriftSeconds.map({ $0.isFinite && $0 >= 0 }) ?? true,
              !analysisVersion.isEmpty, analysisVersion.utf8.count <= 256,
              attacks.count <= PracticeConfiguration.maximumObservations, clipping.count <= 4096,
              Set(attacks.map(\.id)).count == attacks.count,
              zip(attacks, attacks.dropFirst()).allSatisfy({ $0.normalizedOnset <= $1.normalizedOnset }),
              phase != .completed || (signalConfirmed && renderEpochSeconds != nil && reason == nil),
              phase == .completed || reason != nil else { throw PracticeError.invalidEvidence }
        self.id = id; self.configuration = configuration; self.startedAt = startedAt; self.finishedAt = finishedAt
        self.phase = phase; self.reason = reason; self.signalConfirmed = signalConfirmed; self.renderEpochSeconds = renderEpochSeconds
        self.maximumClockDriftSeconds = maximumClockDriftSeconds; self.attacks = attacks; self.clipping = clipping; self.analysisVersion = analysisVersion
    }
}
