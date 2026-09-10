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
        guard (TuningProfile.presets + customTunings).contains(instrument.tuning) else { throw StorageError.invalidRecord }
    }
    public var availableTunings: [TuningProfile] { TuningProfile.presets + customTunings }

    public func selectingTuning(id: String) throws -> InstrumentPreferences {
        guard let tuning = availableTunings.first(where: { $0.id == id }) else { throw StorageError.invalidRecord }
        return try InstrumentPreferences(instrument: InstrumentProfile(tuning: tuning, orientation: instrument.orientation, source: instrument.source),
                                         customTunings: customTunings, practiceBPM: practiceBPM)
    }

    public func savingCustomTuning(_ tuning: TuningProfile, expectedRevision: Int?) throws -> InstrumentPreferences {
        guard !TuningProfile.presets.contains(where: { $0.id == tuning.id }) else { throw StorageError.invalidRecord }
        var profiles = customTunings
        if let index = profiles.firstIndex(where: { $0.id == tuning.id }) {
            let old = profiles[index]
            guard expectedRevision == old.revision,
                  tuning == old || (old.revision < Int.max && tuning.revision == old.revision + 1) else { throw StorageError.identifierConflict }
            profiles[index] = tuning
        } else {
            guard expectedRevision == nil, tuning.revision == 1 else { throw StorageError.identifierConflict }
            profiles.append(tuning)
        }
        return try InstrumentPreferences(instrument: InstrumentProfile(tuning: tuning, orientation: instrument.orientation, source: instrument.source),
                                         customTunings: profiles, practiceBPM: practiceBPM)
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
              uncertainCount >= 0, uncertainCount <= expectedCount,
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
    public let assessment: DocumentEnvelope<AssessedPractice>?

    public init(id: UUID = UUID(), startedAt: Date, finishedAt: Date, exercise: Exercise,
                instrument: InstrumentProfile, bpm: Double, startTick: Int64 = 0, endTick: Int64? = nil,
                calibration: CalibrationSnapshot? = nil, result: AssessmentSnapshot, assessment: AssessedPractice? = nil) throws {
        self.id = id; self.startedAt = startedAt; self.finishedAt = finishedAt; self.exercise = exercise
        self.instrument = instrument; self.bpm = bpm; self.startTick = startTick; self.endTick = endTick ?? exercise.durationTicks
        self.calibration = calibration; self.result = DocumentEnvelope(schemaVersion: 1, payload: result)
        self.assessment = assessment.map { DocumentEnvelope(schemaVersion: 1, payload: $0) }
        try validate()
    }

    public func validate() throws {
        guard result.schemaVersion == 1 else { throw StorageError.unsupportedVersion(result.schemaVersion) }
        try result.payload.validate()
        if let assessment {
            guard assessment.schemaVersion == 1 else { throw StorageError.unsupportedVersion(assessment.schemaVersion) }
            let value = assessment.payload, input = value.evidence, configuration = input.configuration
            guard id == input.id, startedAt == input.startedAt, finishedAt == input.finishedAt,
                  exercise == configuration.exercise, instrument == configuration.instrument, bpm == configuration.bpm,
                  startTick == configuration.range.lowerBound, endTick == configuration.range.upperBound,
                  calibration == (try configuration.calibration.map(CalibrationSnapshot.init)),
                  result.payload == (try AssessmentSnapshot(value)) else { throw StorageError.invalidRecord }
        }
        try calibration?.validate()
        try exercise.validatePracticeSnapshot(instrument: instrument.tuning, bpm: bpm)
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

    private enum CodingKeys: String, CodingKey { case id, startedAt, finishedAt, exercise, instrument, bpm, startTick, endTick, calibration, result, assessment }
    private enum ResultKeys: String, CodingKey { case schemaVersion, payload }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let result = try values.nestedContainer(keyedBy: ResultKeys.self, forKey: .result)
        let version = try result.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else { throw StorageError.unsupportedVersion(version) }
        let assessment: AssessedPractice?
        if values.contains(.assessment), try !values.decodeNil(forKey: .assessment) {
            let detail = try values.nestedContainer(keyedBy: ResultKeys.self, forKey: .assessment)
            let detailVersion = try detail.decode(Int.self, forKey: .schemaVersion)
            guard detailVersion == 1 else { throw StorageError.unsupportedVersion(detailVersion) }
            assessment = try detail.decode(AssessedPractice.self, forKey: .payload)
        } else { assessment = nil }
        try self.init(id: values.decode(UUID.self, forKey: .id), startedAt: values.decode(Date.self, forKey: .startedAt),
                      finishedAt: values.decode(Date.self, forKey: .finishedAt), exercise: values.decode(Exercise.self, forKey: .exercise),
                      instrument: values.decode(InstrumentProfile.self, forKey: .instrument), bpm: values.decode(Double.self, forKey: .bpm),
                      startTick: values.decode(Int64.self, forKey: .startTick), endTick: values.decode(Int64.self, forKey: .endTick),
                      calibration: values.decodeIfPresent(CalibrationSnapshot.self, forKey: .calibration),
                      result: result.decode(AssessmentSnapshot.self, forKey: .payload), assessment: assessment)
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
    public init(records: [PracticeRecord], issues: [StorageIssue]) { self.records = records; self.issues = issues }
}

public enum PreferencesLoad: Sendable {
    case available(InstrumentPreferences, migrated: Bool)
    case needsRecovery(StorageIssue)
}


extension AssessmentSnapshot {
    public init(_ assessment: AssessedPractice) throws {
        guard let validity = StoredResultValidity(rawValue: assessment.validity.rawValue) else { throw StorageError.invalidRecord }
        try self.init(algorithmVersion: assessment.parameters.version,
            validity: validity,
            overallScore: assessment.overallScore, pitchScore: assessment.pitchScore, timingScore: assessment.timingScore,
            expectedCount: assessment.expectedCount, matchedCount: assessment.matchedCount, missedCount: assessment.missedCount,
            extraCount: assessment.extras.count, uncertainCount: assessment.uncertainCount)
    }
}
extension CalibrationSnapshot {
    public init(_ profile: CalibrationProfile) throws {
        guard let method = Method(rawValue: profile.method.rawValue) else { throw StorageError.invalidRecord }
        try self.init(id: profile.id, revision: profile.revision, routeSignature: profile.route.signature,
            residualOffsetSeconds: profile.residualOffsetSeconds, uncertaintySeconds: profile.uncertaintySeconds,
            method: method)
    }
}
extension PracticeRecord {
    public init(assessment: AssessedPractice) throws {
        let input = assessment.evidence, configuration = input.configuration
        try self.init(id: input.id, startedAt: input.startedAt, finishedAt: input.finishedAt,
            exercise: configuration.exercise, instrument: configuration.instrument, bpm: configuration.bpm,
            startTick: configuration.range.lowerBound, endTick: configuration.range.upperBound,
            calibration: configuration.calibration.map(CalibrationSnapshot.init), result: AssessmentSnapshot(assessment), assessment: assessment)
    }
}
