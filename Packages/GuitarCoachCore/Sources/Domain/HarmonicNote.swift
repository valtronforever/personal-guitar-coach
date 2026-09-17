import Foundation

/// Authored physical instruction. The measured target is sound, not proof of its production method.
public struct HarmonicNote: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable { case natural, artificial }
    public let kind: Kind
    public let partial: Int
    public init(kind: Kind, partial: Int = 2) throws {
        guard (2...4).contains(partial), kind == .natural || partial == 2 else { throw MusicError.invalidEvent }
        self.kind = kind; self.partial = partial
    }
    /// Approximate node landmark; an actual string's best touch point may be slightly displaced.
    public var nodeOffset: Int { partial == 2 ? 12 : partial == 3 ? 7 : 5 }
    /// Nearest equal-tempered label; the third partial is ~1.96 cents above this MIDI pitch.
    public var soundingSemitones: Int { partial == 2 ? 12 : partial == 3 ? 19 : 24 }
    public func validate(position: FretPosition) throws {
        if kind == .natural {
            guard position.fret == nodeOffset else { throw MusicError.invalidEvent }
        } else {
            guard position.fret > 0, position.fret <= 12 else { throw MusicError.invalidEvent }
        }
    }
    public func basePosition(from position: FretPosition) throws -> FretPosition {
        try validate(position: position)
        return try FretPosition(string: position.string, fret: kind == .natural ? 0 : position.fret)
    }
    public func touchPosition(from position: FretPosition) throws -> FretPosition {
        try validate(position: position)
        return try FretPosition(string: position.string, fret: kind == .natural ? position.fret : position.fret + nodeOffset)
    }
    private enum CodingKeys: String, CodingKey { case kind, partial }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(kind: values.decode(Kind.self, forKey: .kind), partial: values.decodeIfPresent(Int.self, forKey: .partial) ?? 2)
    }
}

public enum EventFretRole: String, Sendable { case ordinary, harmonicTouch, harmonicBase }
public struct EventFretTarget: Hashable, Sendable {
    public let position: FretPosition
    public let pitch: Pitch
    public let role: EventFretRole
    public init(position: FretPosition, pitch: Pitch, role: EventFretRole = .ordinary) {
        self.position = position; self.pitch = pitch; self.role = role
    }
}

extension MusicalEvent {
    /// Single source of audible initial targets, independent of physical node placement.
    public func soundingPitches(in tuning: TuningProfile) throws -> [Pitch] {
        if let harmonic, let position = positions.first {
            let base = try tuning.pitch(at: harmonic.basePosition(from: position))
            return [try Pitch(midi: base.midi + harmonic.soundingSemitones)]
        }
        return try positions.map { try tuning.pitch(at: $0) }
    }
    public func soundingFrequencies(in tuning: TuningProfile) throws -> [Double] {
        if let harmonic, let position = positions.first {
            let base = try tuning.pitch(at: harmonic.basePosition(from: position))
            return [try base.frequency(referenceA4: tuning.referenceA4) * Double(harmonic.partial)]
        }
        return try soundingPitches(in: tuning).map { try $0.frequency(referenceA4: tuning.referenceA4) }
    }
    public func visualTargets(in tuning: TuningProfile) throws -> [EventFretTarget] {
        if let harmonic, let position = positions.first {
            let touch = try EventFretTarget(position: harmonic.touchPosition(from: position), pitch: soundingPitches(in: tuning)[0], role: .harmonicTouch)
            if harmonic.kind == .natural { return [touch] }
            return [try EventFretTarget(position: position, pitch: tuning.pitch(at: position), role: .harmonicBase), touch]
        }
        return try techniquePositions.map { try EventFretTarget(position: $0, pitch: tuning.pitch(at: $0)) }
    }
}
