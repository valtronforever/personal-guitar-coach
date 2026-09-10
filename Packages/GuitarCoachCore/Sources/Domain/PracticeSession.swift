import Foundation

public enum PracticeError: Error, Equatable, Sendable {
    case invalidRange, unsupportedSize, unsupportedFormat, invalidTransition, invalidEvidence
}

public struct PracticeLessonReference: Equatable, Sendable {
    public let id: String
    public let version: Int
    public init(id: String, version: Int) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, id.utf8.count <= 256, version > 0 else {
            throw PracticeError.invalidEvidence
        }
        self.id = id; self.version = version
    }
}

/// Frozen before preflight. Mutable controls belong to the UI and cannot alter this snapshot.
public struct PracticeConfiguration: Equatable, Sendable {
    public static let maximumNotes = 1024
    public static let maximumObservations = 2048
    public static let maximumSeconds = 900.0
    public let lesson: PracticeLessonReference?
    public let exercise: Exercise
    public let instrument: InstrumentProfile
    public let bpm: Double
    public let range: Range<Int64>
    public let countInBars: Int
    public let route: CalibrationRoute
    public let calibration: CalibrationProfile?
    public var selectedEvents: [MusicalEvent] { exercise.events.filter { range.contains($0.startTick) } }
    public var durationSeconds: Double { Double(range.count) / 960 * 60 / bpm }
    public var countInSeconds: Double { Double(countInBars * exercise.timeSignature.beatsPerBar) * 60 / bpm }
    public var finalDrainSeconds: Double { 1.4 + (route.input.hardwareLatencySeconds ?? 0) }

    public init(exercise: Exercise, instrument: InstrumentProfile, bpm: Double, range: Range<Int64>? = nil,
                countInBars: Int = 1, route: CalibrationRoute, calibration: CalibrationProfile? = nil, lesson: PracticeLessonReference? = nil) throws {
        try exercise.validatePracticeSnapshot(instrument: instrument.tuning, bpm: bpm)
        let range = range ?? 0..<exercise.durationTicks
        let bar = exercise.timeSignature.ticksPerBar
        guard range.lowerBound >= 0, range.lowerBound < range.upperBound, range.upperBound <= exercise.durationTicks,
              range.lowerBound % bar == 0, range.upperBound % bar == 0 || range.upperBound == exercise.durationTicks,
              (1...4).contains(countInBars),
              !exercise.events.contains(where: { $0.startTick < range.lowerBound && $0.endTick > range.lowerBound }),
              !exercise.events.contains(where: { range.contains($0.startTick) && $0.endTick > range.upperBound }) else {
            throw PracticeError.invalidRange
        }
        guard MonophonicCapability.sampleRates.contains(route.input.sampleRate) else { throw PracticeError.unsupportedFormat }
        let selected = exercise.events.filter { range.contains($0.startTick) }
        let notes = selected.filter { $0.kind == .note }
        guard !notes.isEmpty else { throw PracticeError.invalidRange }
        guard notes.count <= Self.maximumNotes, Double(range.count) / 960 * 60 / bpm <= Self.maximumSeconds else {
            throw PracticeError.unsupportedSize
        }
        let selectedIDs = Set(selected.map(\.id))
        if let limitation = try MonophonicCapability.limitations(exercise: exercise, instrument: instrument.tuning, bpm: bpm)
            .first(where: { selectedIDs.contains($0.eventID) }) {
            throw limitation.reason == .frequency ? MusicError.unsupportedPitch : MusicError.unsupportedDuration
        }
        if let calibration, calibration.route != route { throw CalibrationError.invalidRoute }
        self.lesson = lesson; self.exercise = exercise; self.instrument = instrument; self.bpm = bpm; self.range = range
        self.countInBars = countInBars; self.route = route; self.calibration = calibration
    }

    /// Audio render epoch is required. The UI's start-button time is never accepted as a substitute.
    public static let edgeGuardSeconds = 0.1
    public static let resolutionAllowanceSeconds = 0.3
    public func expectedEnd(renderEpochSeconds: Double) throws -> Double {
        try route.expectedTime(renderEpochSeconds: renderEpochSeconds,
            sampleFrame: Int64(((countInSeconds + durationSeconds) * route.output.sampleRate).rounded()))
    }
    public func observationWindow(renderEpochSeconds: Double) throws -> Range<Double> {
        let start = try expectedStart(renderEpochSeconds: renderEpochSeconds) - Self.edgeGuardSeconds
        let end = try expectedEnd(renderEpochSeconds: renderEpochSeconds) + Self.edgeGuardSeconds
        guard start < end else { throw CalibrationError.invalidTimestamp }
        return start..<end
    }
    public func expectedStart(renderEpochSeconds: Double) throws -> Double {
        try route.expectedTime(renderEpochSeconds: renderEpochSeconds,
            sampleFrame: Int64((countInSeconds * route.output.sampleRate).rounded()))
    }
}

public enum PracticePhase: String, Sendable {
    case idle, preflight, preflightFailed, countIn, running, finalizing, completed, paused, interrupted, cancelled
    public var active: Bool { self == .preflight || self == .countIn || self == .running || self == .finalizing }
}
public enum PracticeStopReason: String, Codable, Sendable {
    case userCancelled, paused, changedTempo, changedRange, changedInstrument, changedExercise
    case routeChanged, permissionDenied, suspended, dataLoss, streamStalled, invalidFormat, audioFailure
    case noTestSignal, tuningNotConfirmed, evidenceOverflow, missingTimestamp
}

public struct PracticeStateMachine: Sendable {
    public private(set) var phase: PracticePhase = .idle
    public private(set) var reason: PracticeStopReason?
    public private(set) var attemptID: UUID?
    public private(set) var configuration: PracticeConfiguration?
    public init() {}

    public mutating func begin(_ configuration: PracticeConfiguration, id: UUID = UUID()) throws {
        guard !phase.active else { throw PracticeError.invalidTransition }
        self.configuration = configuration; attemptID = id; reason = nil; phase = .preflight
    }
    public mutating func preflightPassed() throws {
        guard phase == .preflight else { throw PracticeError.invalidTransition }; phase = .countIn
    }
    public mutating func beginPlaying() throws {
        guard phase == .countIn else { throw PracticeError.invalidTransition }; phase = .running
    }
    public mutating func beginFinalizing() throws {
        guard phase == .running else { throw PracticeError.invalidTransition }; phase = .finalizing
    }
    public mutating func complete() throws {
        guard phase == .finalizing else { throw PracticeError.invalidTransition }; phase = .completed
    }
    public mutating func stop(_ reason: PracticeStopReason) {
        guard phase.active else { return }
        self.reason = reason
        if phase == .preflight && reason != .paused && reason != .userCancelled { phase = .preflightFailed }
        else if reason == .paused { phase = .paused }
        else if reason == .userCancelled { phase = .cancelled }
        else { phase = .interrupted }
    }
}
