import Foundation

/// A lesson fingering constrained to up to five consecutive frets, with unchanged sounding pitches.
public struct LessonPosition: Codable, Equatable, Hashable, Sendable {
    public let firstFret: Int
    public init(firstFret: Int) throws {
        guard (0...24).contains(firstFret) else { throw MusicError.invalidFret }
        self.firstFret = firstFret
    }
    public func contains(_ position: FretPosition, maximumFret: Int) -> Bool {
        position.fret >= firstFret && position.fret <= min(firstFret + 4, maximumFret)
    }
    private enum CodingKeys: String, CodingKey { case firstFret }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(firstFret: values.decode(Int.self, forKey: .firstFret))
    }
}
