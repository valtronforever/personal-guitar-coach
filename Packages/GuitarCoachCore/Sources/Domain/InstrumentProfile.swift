import Foundation

public enum GuitarFretCount: Int, Codable, CaseIterable, Sendable {
    case nineteen = 19, twenty = 20, twentyOne = 21, twentyTwo = 22, twentyFour = 24
}

public struct InstrumentProfile: Codable, Equatable, Sendable {
    public let tuning: TuningProfile
    public let orientation: FretboardOrientation
    public let source: InputSource
    public let frets: GuitarFretCount
    public var fretCount: Int { frets.rawValue }

    public init(tuning: TuningProfile = .standard, orientation: FretboardOrientation = .rightHanded,
                source: InputSource = .electricInterface, frets: GuitarFretCount = .twentyFour) {
        self.tuning = tuning; self.orientation = orientation; self.source = source; self.frets = frets
    }

    public func contains(_ position: FretPosition) -> Bool { position.fret <= fretCount }

    private enum CodingKeys: String, CodingKey { case tuning, orientation, source, fretCount }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(tuning: try values.decode(TuningProfile.self, forKey: .tuning),
                  orientation: try values.decode(FretboardOrientation.self, forKey: .orientation),
                  source: try values.decode(InputSource.self, forKey: .source),
                  frets: try values.contains(.fretCount) ? values.decode(GuitarFretCount.self, forKey: .fretCount) : .twentyFour)
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(tuning, forKey: .tuning); try values.encode(orientation, forKey: .orientation)
        try values.encode(source, forKey: .source); try values.encode(frets, forKey: .fretCount)
    }
}
