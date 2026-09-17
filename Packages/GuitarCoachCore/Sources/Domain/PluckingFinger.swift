/// Authored picking-hand cue, independent of the player's handedness. Audio does not identify a finger.
public enum PluckingFinger: String, Codable, CaseIterable, Sendable {
    case thumb, index, middle, ring
    public var symbol: String {
        switch self { case .thumb: "p"; case .index: "i"; case .middle: "m"; case .ring: "a" }
    }
}
