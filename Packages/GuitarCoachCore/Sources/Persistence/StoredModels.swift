import Foundation
import Domain

public enum StorageError: Error, Equatable, Sendable {
    case unsupportedVersion(Int), corruptDocument, invalidRecord, identifierConflict, preferencesNeedRecovery
}

public struct DocumentEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let schemaVersion: Int
    public let payload: Payload
    public init(schemaVersion: Int, payload: Payload) { self.schemaVersion = schemaVersion; self.payload = payload }
}

public struct InstrumentPreferences: Codable, Equatable, Sendable {
    public let instrument: InstrumentProfile
    public let customTunings: [TuningProfile]
    public let practiceBPM: Double

    public init(instrument: InstrumentProfile = InstrumentProfile(), customTunings: [TuningProfile] = [],
                practiceBPM: Double = 60) throws {
        self.instrument = instrument; self.customTunings = customTunings; self.practiceBPM = practiceBPM
        try validate()
    }

    public func validate() throws {
        try MusicalTime.validateTempo(practiceBPM)
        guard Set(customTunings.map(\.id)).count == customTunings.count,
              Set(customTunings.map(\.id)).isDisjoint(with: Set(TuningProfile.presets.map(\.id))) else {
            throw StorageError.invalidRecord
        }
    }
    public static let defaults = try! InstrumentPreferences()
}

public enum StoredResultValidity: String, Codable, Sendable {
    case valid, uncalibrated, insufficientSignal, interrupted
}

/// A versioned storage DTO; scoring rules live in Learning, not in the repository.
public struct AssessmentSnapshot: Codable, Equatable, Sendable {
    public let algorithmVersion: String
    public let validity: StoredResultValidity
    public let overallScore: Double?
    public let pitchScore: Double?
    public let timingScore: Double?
    public let expectedCount: Int
    public let matchedCount: Int
    public let missedCount: Int
    public let extraCount: Int
    public let uncertainCount: Int

    public init(algorithmVersion: String, validity: StoredResultValidity, overallScore: Double? = nil,
                pitchScore: Double? = nil, timingScore: Double? = nil, expectedCount: Int,
                matchedCount: Int, missedCount: Int, extraCount: Int, uncertainCount: Int = 0) throws {
        self.algorithmVersion = algorithmVersion; self.validity = validity; self.overallScore = overallScore
        self.pitchScore = pitchScore; self.timingScore = timingScore; self.expectedCount = expectedCount
        self.matchedCount = matchedCount; self.missedCount = missedCount; self.extraCount = extraCount
        self.uncertainCount = uncertainCount
        try validate()
    }

    public func validate() throws {
        guard !algorithmVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              expectedCount > 0, matchedCount >= 0, missedCount >= 0, extraCount >= 0,
              matchedCount <= expectedCount, missedCount == expectedCount - matchedCount,
              uncertainCount >= 0, uncertainCount <= matchedCount,
              [overallScore, pitchScore, timingScore].compactMap({ $0 }).allSatisfy({ $0.isFinite && (0...100).contains($0) }) else {
            throw StorageError.invalidRecord
        }
        switch validity {
        case .valid:
            guard overallScore != nil, pitchScore != nil, timingScore != nil else { throw StorageError.invalidRecord }
        case .uncalibrated:
            guard overallScore == nil, timingScore == nil else { throw StorageError.invalidRecord }
        case .insufficientSignal, .interrupted:
            guard overallScore == nil, pitchScore == nil, timingScore == nil else { throw StorageError.invalidRecord }
        }
    }
}

public struct CalibrationSnapshot: Codable, Equatable, Sendable {
    public let id: UUID
    public let revision: Int
    /// Includes device/channel/format and backend identity; never a display name.
    public let routeSignature: String
    public let residualOffsetSeconds: Double
    public let uncertaintySeconds: Double
    public let method: Method
    public enum Method: String, Codable, Sendable { case measured, estimated, manual }

    public init(id: UUID, revision: Int, routeSignature: String, residualOffsetSeconds: Double,
                uncertaintySeconds: Double, method: Method) throws {
        self.id = id; self.revision = revision; self.routeSignature = routeSignature
        self.residualOffsetSeconds = residualOffsetSeconds; self.uncertaintySeconds = uncertaintySeconds; self.method = method
        try validate()
    }
    public func validate() throws {
        guard revision > 0, !routeSignature.isEmpty, residualOffsetSeconds.isFinite,
              uncertaintySeconds.isFinite, uncertaintySeconds >= 0 else { throw StorageError.invalidRecord }
    }
}

public struct PracticeRecord: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let finishedAt: Date
    public let exercise: Exercise
    public let instrument: InstrumentProfile
    public let bpm: Double
    public let startTick: Int64
    public let endTick: Int64
    public let calibration: CalibrationSnapshot?
    public let result: DocumentEnvelope<AssessmentSnapshot>

    public init(id: UUID = UUID(), startedAt: Date, finishedAt: Date, exercise: Exercise,
                instrument: InstrumentProfile, bpm: Double, startTick: Int64 = 0, endTick: Int64? = nil,
                calibration: CalibrationSnapshot? = nil, result: AssessmentSnapshot) throws {
        self.id = id; self.startedAt = startedAt; self.finishedAt = finishedAt; self.exercise = exercise
        self.instrument = instrument; self.bpm = bpm; self.startTick = startTick; self.endTick = endTick ?? exercise.durationTicks
        self.calibration = calibration; self.result = DocumentEnvelope(schemaVersion: 1, payload: result)
        try validate()
    }

    public func validate() throws {
        guard result.schemaVersion == 1 else { throw StorageError.unsupportedVersion(result.schemaVersion) }
        try result.payload.validate()
        try calibration?.validate()
        try exercise.validateForPractice(instrument: instrument.tuning, bpm: bpm)
        guard startedAt.timeIntervalSinceReferenceDate.isFinite, finishedAt.timeIntervalSinceReferenceDate.isFinite,
              finishedAt >= startedAt, startTick >= 0, startTick < endTick, endTick <= exercise.durationTicks else {
            throw StorageError.invalidRecord
        }
        let selected = exercise.events.filter { $0.startTick >= startTick && $0.startTick < endTick }
        guard selected.allSatisfy({ $0.endTick <= endTick }),
              !exercise.events.contains(where: { $0.startTick < startTick && $0.endTick > startTick }),
              selected.filter({ $0.kind == .note }).count == result.payload.expectedCount else { throw StorageError.invalidRecord }
        if result.payload.validity == .valid && calibration == nil { throw StorageError.invalidRecord }
    }
}

extension DocumentEnvelope: Equatable where Payload: Equatable {}

public struct StorageIssue: Identifiable, Sendable, Equatable {
    public enum Reason: String, Sendable { case corrupt, unsupported, unreadable, indexUnavailable }
    public let fileName: String
    public let reason: Reason
    public var id: String { "\(fileName):\(reason.rawValue)" }
    public init(fileName: String, reason: Reason) { self.fileName = fileName; self.reason = reason }
}

public struct HistoryLoad: Sendable {
    public let records: [PracticeRecord]
    public let issues: [StorageIssue]
}

public enum PreferencesLoad: Sendable {
    case available(InstrumentPreferences, migrated: Bool)
    case needsRecovery(StorageIssue)
}
