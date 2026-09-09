import Foundation

public enum MusicalEventKind: String, Codable, Sendable { case note, rest }
public enum AssessmentMode: String, Codable, Sendable { case monophonic, displayOnly }
public enum TuningPolicy: String, Codable, Sendable { case fixedTuning, followsInstrument }

public struct MusicalEvent: Hashable, Codable, Identifiable, Sendable {
    public let id: String
    public let startTick: Int64
    public let durationTicks: Int64
    public let kind: MusicalEventKind
    public let positions: [FretPosition]
    public var endTick: Int64 { startTick + durationTicks }

    public init(id: String, startTick: Int64, durationTicks: Int64, kind: MusicalEventKind, positions: [FretPosition] = []) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw MusicError.invalidEvent }
        guard startTick >= 0, durationTicks > 0, !startTick.addingReportingOverflow(durationTicks).overflow else {
            throw MusicError.invalidTime
        }
        guard (kind == .rest && positions.isEmpty) || (kind == .note && !positions.isEmpty),
              Set(positions.map(\.string)).count == positions.count else { throw MusicError.invalidEvent }
        self.id = id; self.startTick = startTick; self.durationTicks = durationTicks
        self.kind = kind; self.positions = positions
    }

    private enum CodingKeys: String, CodingKey { case id, startTick, durationTicks, kind, positions }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: values.decode(String.self, forKey: .id), startTick: values.decode(Int64.self, forKey: .startTick),
            durationTicks: values.decode(Int64.self, forKey: .durationTicks), kind: values.decode(MusicalEventKind.self, forKey: .kind),
            positions: values.decodeIfPresent([FretPosition].self, forKey: .positions) ?? [])
    }
}

public struct ResolvedEvent: Hashable, Sendable, Identifiable {
    public let event: MusicalEvent
    public let pitches: [Pitch]
    public var id: String { event.id }
}

public struct Exercise: Hashable, Codable, Identifiable, Sendable {
    /// Initial musical target C2–E6. Actual audio capability also requires task 12's measured limits.
    public static let monophonicMIDITarget = 36...88
    public let id: String
    public let version: Int
    public let ppq: Int64
    public let events: [MusicalEvent]
    public let timeSignature: TimeSignature
    public let defaultBPM: Double
    public let minimumBPM: Double
    public let maximumBPM: Double
    public let tuningPolicy: TuningPolicy
    public let requiredTuning: TuningProfile?
    public let assessmentMode: AssessmentMode
    public var durationTicks: Int64 { events.last?.endTick ?? 0 }
    public var noteCount: Int { events.filter { $0.kind == .note }.count }

    public init(id: String, version: Int = 1, ppq: Int64 = MusicalTime.ppq, events: [MusicalEvent],
                timeSignature: TimeSignature = .fourFour, defaultBPM: Double = 60,
                minimumBPM: Double = 40, maximumBPM: Double = 200,
                tuningPolicy: TuningPolicy = .followsInstrument, requiredTuning: TuningProfile? = nil,
                assessmentMode: AssessmentMode = .monophonic) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, version > 0,
              ppq == MusicalTime.ppq, !events.isEmpty else { throw MusicError.invalidExercise }
        try MusicalTime.validateTempo(minimumBPM)
        try MusicalTime.validateTempo(maximumBPM)
        guard minimumBPM <= maximumBPM, defaultBPM.isFinite,
              (minimumBPM...maximumBPM).contains(defaultBPM) else { throw MusicError.invalidTempo }
        guard Set(events.map(\.id)).count == events.count else { throw MusicError.duplicateIdentifier }
        for pair in zip(events, events.dropFirst()) {
            guard pair.1.startTick >= pair.0.endTick else { throw MusicError.overlappingEvents }
        }
        guard (tuningPolicy == .fixedTuning) == (requiredTuning != nil) else { throw MusicError.invalidTuning }
        if assessmentMode == .monophonic {
            guard events.contains(where: { $0.kind == .note }) else { throw MusicError.invalidExercise }
            guard events.allSatisfy({ $0.positions.count <= 1 }) else { throw MusicError.unsupportedPolyphony }
        }
        self.id = id; self.version = version; self.ppq = ppq; self.events = events
        self.timeSignature = timeSignature; self.defaultBPM = defaultBPM
        self.minimumBPM = minimumBPM; self.maximumBPM = maximumBPM
        self.tuningPolicy = tuningPolicy; self.requiredTuning = requiredTuning; self.assessmentMode = assessmentMode
    }

    /// Preview can show the required tuning even when the user's guitar is different.
    public func resolvedEvents(instrument: TuningProfile) throws -> [ResolvedEvent] {
        let tuning = requiredTuning ?? instrument
        return try events.map { event in
            try ResolvedEvent(event: event, pitches: event.positions.map { try tuning.pitch(at: $0) })
        }
    }

    /// Structural snapshot validation is independent of today's audio capability limits.
    public func validatePracticeSnapshot(instrument: TuningProfile, bpm: Double) throws {
        guard assessmentMode == .monophonic else { throw MusicError.displayOnlyExercise }
        try MusicalTime.validateTempo(bpm)
        guard (minimumBPM...maximumBPM).contains(bpm) else { throw MusicError.invalidTempo }
        if let requiredTuning, !requiredTuning.hasSamePitches(as: instrument) { throw MusicError.tuningMismatch }
    }

    public func validateForPractice(instrument: TuningProfile, bpm: Double) throws {
        try validatePracticeSnapshot(instrument: instrument, bpm: bpm)
        guard try resolvedEvents(instrument: instrument).flatMap(\.pitches).allSatisfy({ Self.monophonicMIDITarget.contains($0.midi) }) else {
            throw MusicError.unsupportedPitch
        }
        if let limitation = try MonophonicCapability.limitations(exercise: self, instrument: instrument, bpm: bpm).first {
            throw limitation.reason == .frequency ? MusicError.unsupportedPitch : MusicError.unsupportedDuration
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, version, ppq, events, timeSignature, defaultBPM, minimumBPM, maximumBPM, tuningPolicy, requiredTuning, assessmentMode
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: values.decode(String.self, forKey: .id), version: values.decode(Int.self, forKey: .version),
            ppq: values.decode(Int64.self, forKey: .ppq), events: values.decode([MusicalEvent].self, forKey: .events),
            timeSignature: values.decode(TimeSignature.self, forKey: .timeSignature), defaultBPM: values.decode(Double.self, forKey: .defaultBPM),
            minimumBPM: values.decode(Double.self, forKey: .minimumBPM), maximumBPM: values.decode(Double.self, forKey: .maximumBPM),
            tuningPolicy: values.decode(TuningPolicy.self, forKey: .tuningPolicy),
            requiredTuning: values.decodeIfPresent(TuningProfile.self, forKey: .requiredTuning),
            assessmentMode: values.decode(AssessmentMode.self, forKey: .assessmentMode))
    }
}
