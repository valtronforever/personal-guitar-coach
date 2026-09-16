import Foundation

/// A bounded, derived pitch trace. It contains no waveform or physical-string claim.
public struct SustainFrame: Codable, Equatable, Sendable, Identifiable {
    public enum State: String, Codable, Sendable { case pitched, silence, uncertain }
    public let id: UInt64
    public let normalizedTime: Double
    public let state: State
    public let frequency: Double?
    public init(id: UInt64, normalizedTime: Double, state: State, frequency: Double?) throws {
        guard id > 0, normalizedTime.isFinite,
              state == .pitched ? (frequency.map { $0.isFinite && $0 > 0 } ?? false) : frequency == nil else {
            throw PracticeError.invalidEvidence
        }
        self.id = id; self.normalizedTime = normalizedTime; self.state = state; self.frequency = frequency
    }
    private enum CodingKeys: String, CodingKey { case id, normalizedTime, state, frequency }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: v.decode(UInt64.self, forKey: .id), normalizedTime: v.decode(Double.self, forKey: .normalizedTime),
            state: v.decode(State.self, forKey: .state), frequency: v.decodeIfPresent(Double.self, forKey: .frequency))
    }
}

public struct SustainTrace: Codable, Equatable, Sendable {
    public static let currentVersion = "sustain-window-center-1"
    public static let maximumFrames = 45_100 // 900-second attempt at 50 Hz plus bounded edges.
    public static let minimumNoteSeconds = 0.5
    public let version: String
    public let frames: [SustainFrame]
    public init(version: String = Self.currentVersion, frames: [SustainFrame]) throws {
        guard version == Self.currentVersion, frames.count <= Self.maximumFrames else { throw PracticeError.invalidEvidence }
        for (a, b) in zip(frames, frames.dropFirst()) {
            let delta = b.normalizedTime - a.normalizedTime
            guard a.id < UInt64.max, b.id == a.id + 1, (0.018...0.022).contains(delta) else { throw PracticeError.invalidEvidence }
        }
        self.version = version; self.frames = frames
    }
    private enum CodingKeys: String, CodingKey { case version, frames }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(version: v.decode(String.self, forKey: .version), frames: v.decode([SustainFrame].self, forKey: .frames))
    }
}
