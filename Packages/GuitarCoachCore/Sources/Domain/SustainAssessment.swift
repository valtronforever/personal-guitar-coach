import Foundation

public struct SustainNoteAssessment: Codable, Equatable, Sendable, Identifiable {
    public enum State: String, Codable, Sendable { case measured, missed, uncertain }
    public let id: String
    public let state: State
    public let heldFraction: Double?
    public let silentFraction: Double?
    public let unknownFraction: Double
    public init(id: String, state: State, heldFraction: Double?, silentFraction: Double?, unknownFraction: Double) throws {
        guard !id.isEmpty, unknownFraction.isFinite, (0...1).contains(unknownFraction),
              [heldFraction, silentFraction].compactMap({ $0 }).allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              state == .uncertain ? heldFraction == nil && silentFraction == nil : heldFraction != nil && silentFraction != nil,
              state != .missed || heldFraction == 0,
              state == .uncertain || unknownFraction <= 0.2 + 1e-9,
              (heldFraction ?? 0) + (silentFraction ?? 0) + unknownFraction <= 1 + 1e-9 else { throw AssessmentError.invalidResult }
        self.id = id; self.state = state; self.heldFraction = heldFraction
        self.silentFraction = silentFraction; self.unknownFraction = unknownFraction
    }
    private enum CodingKeys: String, CodingKey { case id, state, heldFraction, silentFraction, unknownFraction }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(String.self, forKey: .id), state: v.decode(State.self, forKey: .state),
            heldFraction: v.decodeIfPresent(Double.self, forKey: .heldFraction), silentFraction: v.decodeIfPresent(Double.self, forKey: .silentFraction),
            unknownFraction: v.decode(Double.self, forKey: .unknownFraction))
    }
}

public struct SustainAssessment: Codable, Equatable, Sendable {
    public static let currentVersion = "sustain-assessment-1"
    public let version: String
    public let notes: [SustainNoteAssessment]
    public var score: Double? {
        guard notes.allSatisfy({ $0.state != .uncertain }) else { return nil }
        return 100 * notes.compactMap(\.heldFraction).reduce(0, +) / Double(notes.count)
    }
    public init(version: String = Self.currentVersion, notes: [SustainNoteAssessment]) throws {
        guard version == Self.currentVersion, !notes.isEmpty, notes.count <= PracticeConfiguration.maximumNotes,
              Set(notes.map(\.id)).count == notes.count else { throw AssessmentError.invalidResult }
        self.version = version; self.notes = notes
    }
    private enum CodingKeys: String, CodingKey { case version, notes }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(version: v.decode(String.self, forKey: .version), notes: v.decode([SustainNoteAssessment].self, forKey: .notes))
    }
}
