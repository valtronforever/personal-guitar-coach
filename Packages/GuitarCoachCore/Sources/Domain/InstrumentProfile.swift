import Foundation

public struct InstrumentProfile: Codable, Equatable, Sendable {
    public let tuning: TuningProfile
    public let orientation: FretboardOrientation
    public let source: InputSource
    public var fretCount: Int { 24 }

    public init(tuning: TuningProfile = .standard, orientation: FretboardOrientation = .rightHanded,
                source: InputSource = .electricInterface) {
        self.tuning = tuning; self.orientation = orientation; self.source = source
    }
}
