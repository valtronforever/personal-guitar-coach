import Foundation

/// Periodic window estimates may move in pitch. This is distinct from stable-note sustain evidence.
/// Frame structure and clock validation are shared; the version identifies the different quality contract.
public struct PitchContourTrace: Codable, Equatable, Sendable {
    public static let currentVersion = "periodic-window-center-1"
    public static let maximumFrames = SustainTrace.maximumFrames
    public let version: String
    public let frames: [SustainFrame]
    public init(version: String = Self.currentVersion, frames: [SustainFrame]) throws {
        guard version == Self.currentVersion else { throw PracticeError.invalidEvidence }
        _ = try SustainTrace(frames: frames)
        self.version = version; self.frames = frames
    }
    private enum CodingKeys: String, CodingKey { case version, frames }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy:CodingKeys.self)
        try self.init(version:values.decode(String.self,forKey:.version),frames:values.decode([SustainFrame].self,forKey:.frames))
    }
}
