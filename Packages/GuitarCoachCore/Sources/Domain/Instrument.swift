import Foundation

public struct FretPosition: Hashable, Codable, Sendable {
    public let string: Int
    public let fret: Int

    public init(string: Int, fret: Int) throws {
        guard (1...6).contains(string) else { throw MusicError.invalidString }
        guard (0...24).contains(fret) else { throw MusicError.invalidFret }
        self.string = string
        self.fret = fret
    }

    private enum CodingKeys: String, CodingKey { case string, fret }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(string: values.decode(Int.self, forKey: .string), fret: values.decode(Int.self, forKey: .fret))
    }
}

public struct TunedString: Hashable, Codable, Sendable, Identifiable {
    public let number: Int
    public let openPitch: Pitch
    public var id: Int { number }

    public init(number: Int, openPitch: Pitch) throws {
        guard (1...6).contains(number) else { throw MusicError.invalidString }
        guard openPitch.midi <= 103 else { throw MusicError.invalidTuning } // All 24 frets remain MIDI pitches.
        self.number = number
        self.openPitch = openPitch
    }

    private enum CodingKeys: String, CodingKey { case number, openPitch }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(number: values.decode(Int.self, forKey: .number), openPitch: values.decode(Pitch.self, forKey: .openPitch))
    }
}

public struct TuningProfile: Hashable, Codable, Identifiable, Sendable {
    public let id: String
    public let revision: Int
    public let name: String
    /// Explicitly numbered, stored in order 1 → 6. Never infer string number from UI orientation.
    public let strings: [TunedString]
    public let referenceA4: Double

    public init(id: String, revision: Int = 1, name: String, strings: [TunedString], referenceA4: Double = 440) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              revision > 0, strings.count == 6, Set(strings.map(\.number)) == Set(1...6) else {
            throw MusicError.invalidTuning
        }
        try Pitch.validateReference(referenceA4)
        self.id = id; self.revision = revision; self.name = name
        self.strings = strings.sorted { $0.number < $1.number }
        self.referenceA4 = referenceA4
    }

    public func pitch(at position: FretPosition) throws -> Pitch {
        guard let string = strings.first(where: { $0.number == position.string }) else { throw MusicError.invalidString }
        return try Pitch(midi: string.openPitch.midi + position.fret)
    }

    public func frequency(at position: FretPosition) throws -> Double {
        try pitch(at: position).frequency(referenceA4: referenceA4)
    }

    /// Profile names/IDs may differ even when the physical target pitches are identical.
    public func hasSamePitches(as other: TuningProfile) -> Bool {
        strings == other.strings && referenceA4 == other.referenceA4
    }

    public func revised(name: String, strings: [TunedString], referenceA4: Double) throws -> TuningProfile {
        if self.name == name, self.strings == strings.sorted(by: { $0.number < $1.number }), self.referenceA4 == referenceA4 { return self }
        guard revision < Int.max else { throw MusicError.invalidTuning }
        return try TuningProfile(id: id, revision: revision + 1, name: name, strings: strings, referenceA4: referenceA4)
    }

    // Keep the original serialized name/ID so existing preferences and lesson snapshots remain valid.
    // The localized UI label is E Standard.
    public static let standard = preset(id: "standard", name: "Standard", lowToHigh: [40, 45, 50, 55, 59, 64])
    public static let dropD = preset(id: "drop-d", name: "Drop D", lowToHigh: [38, 45, 50, 55, 59, 64])
    public static let dStandard = preset(id: "d-standard", name: "D Standard", lowToHigh: [38, 43, 48, 53, 57, 62])
    public static let cStandard = preset(id: "c-standard", name: "C Standard", lowToHigh: [36, 41, 46, 51, 55, 60])
    public static let bStandard = preset(id: "b-standard", name: "B Standard", lowToHigh: [35, 40, 45, 50, 54, 59])
    public static let dropC = preset(id: "drop-c", name: "Drop C", lowToHigh: [36, 43, 48, 53, 57, 62])
    public static let dropBFlat = preset(id: "drop-b-flat", name: "Drop B♭", lowToHigh: [34, 41, 46, 51, 55, 60])
    public static let dropA = preset(id: "drop-a", name: "Drop A", lowToHigh: [33, 40, 45, 50, 54, 59])
    public static let presets = [standard, dropD, dStandard, dropC, cStandard, dropBFlat, bStandard, dropA]

    /// Chromatic enharmonic labels follow the string-1 transposition, including custom profiles.
    /// Presentation only: the serialized pitches, frequencies and assessment targets do not change.
    public var preferredSpelling: PitchSpelling { [1, 3, 5, 8, 10].contains((strings[0].openPitch.midi - 64 + 120) % 12) ? .flats : .sharps }

    private static func preset(id: String, name: String, lowToHigh: [Int]) -> TuningProfile {
        // Compile-time musical constants; all externally supplied data uses throwing initializers.
        try! TuningProfile(id: id, name: name, strings: lowToHigh.enumerated().map {
            try TunedString(number: 6 - $0.offset, openPitch: Pitch(midi: $0.element))
        })
    }

    private enum CodingKeys: String, CodingKey { case id, revision, name, strings, referenceA4 }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: values.decode(String.self, forKey: .id), revision: values.decode(Int.self, forKey: .revision),
            name: values.decode(String.self, forKey: .name), strings: values.decode([TunedString].self, forKey: .strings),
            referenceA4: values.decode(Double.self, forKey: .referenceA4))
    }
}

public enum FretboardOrientation: String, Codable, CaseIterable, Sendable {
    case rightHanded, leftHanded
}

public struct Fingering: Hashable, Codable, Sendable {
    public let positions: [FretPosition]
    public let mutedStrings: [Int]
    /// Optional suggested finger 1…4 keyed by string number. Never inferred from audio.
    public let fingerNumbers: [Int: Int]

    public init(positions: [FretPosition], mutedStrings: [Int] = [], fingerNumbers: [Int: Int] = [:]) throws {
        let sounding = Set(positions.map(\.string)), muted = Set(mutedStrings)
        guard sounding.count == positions.count, muted.count == mutedStrings.count,
              muted.isSubset(of: Set(1...6)), sounding.isDisjoint(with: muted),
              fingerNumbers.allSatisfy({ string, finger in
                  (1...4).contains(finger) && positions.contains { $0.string == string && $0.fret > 0 }
              }) else { throw MusicError.invalidFingering }
        self.positions = positions.sorted { $0.string < $1.string }
        self.mutedStrings = mutedStrings.sorted()
        self.fingerNumbers = fingerNumbers
    }

    private enum CodingKeys: String, CodingKey { case positions, mutedStrings, fingerNumbers }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(positions: values.decode([FretPosition].self, forKey: .positions),
            mutedStrings: values.decodeIfPresent([Int].self, forKey: .mutedStrings) ?? [],
            fingerNumbers: values.decodeIfPresent([Int: Int].self, forKey: .fingerNumbers) ?? [:])
    }
}
