import Foundation

public enum MusicError: Error, Equatable, Sendable {
    case invalidPitch
    case invalidReference
    case invalidFrequency
    case invalidString
    case invalidFret
    case invalidTuning
    case invalidFingering
    case invalidTime
    case invalidTempo
    case invalidEvent
    case invalidExercise
    case duplicateIdentifier
    case overlappingEvents
    case unsupportedPolyphony
    case displayOnlyExercise
    case tuningMismatch
}

public enum PitchSpelling: String, Codable, Sendable {
    case sharps, flats
}

/// Sounding pitch. Guitar staff notation's written octave must not alter this value.
public struct Pitch: Hashable, Codable, Sendable {
    public let midi: Int
    public var pitchClass: Int { midi % 12 }
    public var octave: Int { midi / 12 - 1 }

    public init(midi: Int) throws {
        guard (0...127).contains(midi) else { throw MusicError.invalidPitch }
        self.midi = midi
    }

    public func name(spelling: PitchSpelling = .sharps) -> String {
        let names = spelling == .sharps
            ? ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
            : ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
        return "\(names[pitchClass])\(octave)"
    }

    public func frequency(referenceA4: Double = 440) throws -> Double {
        try Self.validateReference(referenceA4)
        return referenceA4 * pow(2, Double(midi - 69) / 12)
    }

    public func cents(from frequency: Double, referenceA4: Double = 440) throws -> Double {
        guard frequency.isFinite, frequency > 0 else { throw MusicError.invalidFrequency }
        let target = try self.frequency(referenceA4: referenceA4)
        return 1200 * (log2(frequency) - log2(target))
    }

    public static func nearest(to frequency: Double, referenceA4: Double = 440) throws -> Pitch {
        try validateReference(referenceA4)
        guard frequency.isFinite, frequency > 0 else { throw MusicError.invalidFrequency }
        let midi = (69 + 12 * (log2(frequency) - log2(referenceA4))).rounded()
        guard midi.isFinite, (0...127).contains(midi) else { throw MusicError.invalidPitch }
        return try Pitch(midi: Int(midi))
    }

    static func validateReference(_ value: Double) throws {
        // A physically useful reference range also prevents overflow/underflow in conversion.
        guard value.isFinite, (400...480).contains(value) else { throw MusicError.invalidReference }
    }

    private enum CodingKeys: String, CodingKey { case midi }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(midi: values.decode(Int.self, forKey: .midi))
    }
}
