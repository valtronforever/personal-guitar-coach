import Foundation

/// An unpitched damped-string attack, not a rest or a palm-muted pitched note.
/// Physical strings/direction are authored instructions; no gesture or pitch grade is implied.
public struct MutedStringAttack: Hashable, Codable, Sendable {
    public let strings: [Int]
    public let direction: StrumDirection?
    public init(strings: [Int], direction: StrumDirection? = nil) throws {
        guard !strings.isEmpty, strings.count <= 6, strings == strings.sorted(),
              Set(strings).count == strings.count, strings.allSatisfy({ (1...6).contains($0) }) else { throw MusicError.invalidEvent }
        self.strings = strings; self.direction = direction
    }
    private enum CodingKeys: String, CodingKey { case strings, direction }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(strings: values.decode([Int].self, forKey: .strings), direction: values.decodeIfPresent(StrumDirection.self, forKey: .direction))
    }
}
