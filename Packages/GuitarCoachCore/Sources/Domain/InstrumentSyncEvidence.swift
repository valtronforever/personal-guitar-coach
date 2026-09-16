import Foundation

/// One 16-beat measurement. Offset is personal timing plus audio delay, never isolated hardware latency.
public struct SyncPassEvidence: Codable, Equatable, Sendable {
    public let offset: Double
    public let spread: Double
    public let drift: Double
    public init(offset: Double, spread: Double, drift: Double) throws {
        guard offset.isFinite, abs(offset) <= 0.4, spread.isFinite, (0...0.06).contains(spread),
              drift.isFinite, abs(drift) <= 0.04 else { throw CalibrationError.insufficientEvidence }
        self.offset = offset; self.spread = spread; self.drift = drift
    }
    private enum CodingKeys: String, CodingKey { case offset, spread, drift }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(offset: v.decode(Double.self, forKey: .offset), spread: v.decode(Double.self, forKey: .spread), drift: v.decode(Double.self, forKey: .drift))
    }
}

public enum ManualOutputReference: String, Codable, CaseIterable, Sendable {
    case additional, total
}

/// The user may enter a signed correction or the total delay quoted by a device specification.
public struct ManualOutputAlignment: Codable, Equatable, Sendable {
    public let seconds: Double
    public let reference: ManualOutputReference
    public init(seconds: Double, reference: ManualOutputReference) throws {
        guard seconds.isFinite, (-1...1).contains(seconds), reference != .total || seconds >= 0 else { throw CalibrationError.invalidProfile }
        self.seconds = seconds; self.reference = reference
    }
    private enum CodingKeys: String, CodingKey { case seconds, reference }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(seconds: v.decode(Double.self, forKey: .seconds), reference: v.decode(ManualOutputReference.self, forKey: .reference))
    }
}

/// Separate output preference; measured taps and user-entered values have distinct provenance.
public struct OutputAlignmentProfile: Codable, Equatable, Sendable, Identifiable {
    public static let version = "output-taps-16-v1"
    public static let manualVersion = "output-manual-v1"
    public let id: UUID
    public let algorithmVersion: String
    public let output: CalibrationEndpoint
    public let evidence: SyncPassEvidence?
    public let manual: ManualOutputAlignment?
    public let clockDriftSeconds: Double
    public var isManual: Bool { manual != nil }
    /// Current settings policy; signed historical snapshots and measurement evidence still decode unchanged.
    public var isNonnegativeSetting: Bool {
        (0...1).contains(seconds) && (manual.map { (0...1).contains($0.seconds) } ?? true)
    }
    public var seconds: Double {
        if let evidence { return evidence.offset }
        guard let manual else { return 0 }
        return manual.seconds - (manual.reference == .total ? output.hardwareLatencySeconds ?? 0 : 0)
    }
    public var measuredAllowance: Double {
        evidence.map { $0.spread + abs($0.drift) + clockDriftSeconds } ?? 0
    }
    public init(id: UUID = UUID(), output: CalibrationEndpoint, evidence: SyncPassEvidence, clockDriftSeconds: Double = 0) throws {
        guard clockDriftSeconds.isFinite, (0...0.02).contains(clockDriftSeconds) else { throw CalibrationError.insufficientEvidence }
        self.id = id; algorithmVersion = Self.version; self.output = output; self.evidence = evidence
        self.clockDriftSeconds = clockDriftSeconds; manual = nil
    }
    public init(id: UUID = UUID(), output: CalibrationEndpoint, manual: ManualOutputAlignment) throws {
        let offset = manual.seconds - (manual.reference == .total ? output.hardwareLatencySeconds ?? 0 : 0)
        guard offset.isFinite, (-1...1).contains(offset) else { throw CalibrationError.invalidProfile }
        self.id = id; algorithmVersion = Self.manualVersion; self.output = output; self.manual = manual
        evidence = nil; clockDriftSeconds = 0
    }
    private enum CodingKeys: String, CodingKey { case id, algorithmVersion, output, evidence, manual, clockDriftSeconds }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        let id = try v.decode(UUID.self, forKey: .id), output = try v.decode(CalibrationEndpoint.self, forKey: .output)
        let version = try v.decode(String.self, forKey: .algorithmVersion)
        let evidence = try v.decodeIfPresent(SyncPassEvidence.self, forKey: .evidence)
        let manual = try v.decodeIfPresent(ManualOutputAlignment.self, forKey: .manual)
        let clock = try v.decode(Double.self, forKey: .clockDriftSeconds)
        if version == Self.version, let evidence, manual == nil {
            try self.init(id: id, output: output, evidence: evidence, clockDriftSeconds: clock)
        } else if version == Self.manualVersion, let manual, evidence == nil, clock == 0 {
            try self.init(id: id, output: output, manual: manual)
        } else { throw CalibrationError.invalidProfile }
    }
}

/// Instrument timing measured against the separately selected output alignment (nil means zero).
public struct InstrumentSyncEvidence: Codable, Equatable, Sendable {
    public static let version = "instrument-sync-16-v1"
    public let algorithmVersion: String
    public let instrument: InstrumentProfile
    public let string: Int
    public let outputSetting: OutputAlignmentProfile?
    public let guitar: SyncPassEvidence
    public var offset: Double { (outputSetting?.seconds ?? 0) + guitar.offset }
    public var uncertainty: Double {
        guitar.spread + abs(guitar.drift) + (outputSetting?.measuredAllowance ?? 0) + 0.01
    }
    public init(instrument: InstrumentProfile, string: Int, outputSetting: OutputAlignmentProfile?, guitar: SyncPassEvidence) throws {
        guard (1...6).contains(string) else { throw CalibrationError.invalidProfile }
        algorithmVersion = Self.version; self.instrument = instrument; self.string = string; self.outputSetting = outputSetting; self.guitar = guitar
    }
    private enum CodingKeys: String, CodingKey { case algorithmVersion, instrument, string, outputSetting, guitar }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        guard try v.decode(String.self, forKey: .algorithmVersion) == Self.version else { throw CalibrationError.invalidProfile }
        try self.init(instrument: v.decode(InstrumentProfile.self, forKey: .instrument), string: v.decode(Int.self, forKey: .string),
                      outputSetting: v.decodeIfPresent(OutputAlignmentProfile.self, forKey: .outputSetting), guitar: v.decode(SyncPassEvidence.self, forKey: .guitar))
    }
}

/// User-selected timing, not successful measurement evidence. The allowance is scoring policy, not measured accuracy.
public struct ManualInstrumentSyncEvidence: Codable, Equatable, Sendable {
    public static let version = "manual-instrument-sync-v1"
    public static let scoringAllowance = 0.05
    public let algorithmVersion: String
    public let instrument: InstrumentProfile
    public let outputSetting: OutputAlignmentProfile?
    public let remainingOffset: Double
    public var offset: Double { (outputSetting?.seconds ?? 0) + remainingOffset }
    public init(instrument: InstrumentProfile, outputSetting: OutputAlignmentProfile?, remainingOffset: Double) throws {
        guard remainingOffset.isFinite, (-1...1).contains(remainingOffset),
              (-1...1).contains((outputSetting?.seconds ?? 0) + remainingOffset) else { throw CalibrationError.invalidProfile }
        algorithmVersion = Self.version; self.instrument = instrument; self.outputSetting = outputSetting; self.remainingOffset = remainingOffset
    }
    private enum CodingKeys: String, CodingKey { case algorithmVersion, instrument, outputSetting, remainingOffset }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        guard try v.decode(String.self, forKey: .algorithmVersion) == Self.version else { throw CalibrationError.invalidProfile }
        try self.init(instrument: v.decode(InstrumentProfile.self, forKey: .instrument), outputSetting: v.decodeIfPresent(OutputAlignmentProfile.self, forKey: .outputSetting), remainingOffset: v.decode(Double.self, forKey: .remainingOffset))
    }
}
