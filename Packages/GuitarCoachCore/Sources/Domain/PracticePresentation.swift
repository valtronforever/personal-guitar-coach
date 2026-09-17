import Foundation

/// Omission means ordinary shown-target practice, preserving pre-extension snapshots.
public enum PracticePresentation: String, Codable, Sendable { case listenAndRepeat }

/// Software-observed preparation for a frozen practice attempt. Completed playback does not prove
/// hearing or understanding. Revealed targets remain guided even if the reference was also played.
public struct PracticeListeningConditions: Codable, Equatable, Sendable {
    public let version: Int
    public let referencePlaybackCompleted: Bool
    public let targetsRevealed: Bool
    public var usedHiddenTargets: Bool { referencePlaybackCompleted && !targetsRevealed }

    public init(referencePlaybackCompleted: Bool, targetsRevealed: Bool) throws {
        guard referencePlaybackCompleted || targetsRevealed else { throw PracticeError.invalidEvidence }
        version = 1; self.referencePlaybackCompleted = referencePlaybackCompleted; self.targetsRevealed = targetsRevealed
    }
    private enum CodingKeys: String, CodingKey { case version, referencePlaybackCompleted, targetsRevealed }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .version) == 1 else { throw PracticeError.invalidEvidence }
        try self.init(referencePlaybackCompleted: values.decode(Bool.self, forKey: .referencePlaybackCompleted),
            targetsRevealed: values.decode(Bool.self, forKey: .targetsRevealed))
    }
}
