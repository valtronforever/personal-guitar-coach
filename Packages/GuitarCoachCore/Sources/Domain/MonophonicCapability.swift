import Foundation

/// Versioned software capability from the task 12 corpus. Physical-route validation remains separate.
public enum MonophonicCapability {
    public static let version = "mono-capability-1"
    public static let frequencyRange = 55.0...1500.0
    public static let minimumNoteSeconds = 0.2
    public static let sampleRates: Set<Double> = [44100, 48000]

    public struct Limitation: Equatable, Sendable {
        public enum Reason: Sendable { case frequency, duration }
        public let eventID: String
        public let reason: Reason
        public let frequency: Double
        public let durationSeconds: Double
    }

    /// Does not restrict display, preview, saved history, or rewrite the requested BPM.
    public static func limitations(exercise: Exercise, instrument: TuningProfile, bpm: Double) throws -> [Limitation] {
        try exercise.validatePracticeSnapshot(instrument: instrument, bpm: bpm)
        let tuning = exercise.requiredTuning ?? instrument
        return try exercise.resolvedEvents(instrument: instrument).compactMap { resolved in
            guard let pitch = resolved.pitches.first else { return nil }
            let hz = try pitch.frequency(referenceA4: tuning.referenceA4)
            let duration = try MusicalTime.seconds(forTicks: resolved.event.durationTicks, bpm: bpm)
            if !Exercise.monophonicMIDITarget.contains(pitch.midi) || !frequencyRange.contains(hz) {
                return Limitation(eventID: resolved.id, reason: .frequency, frequency: hz, durationSeconds: duration)
            }
            if duration + 1e-9 < minimumNoteSeconds {
                return Limitation(eventID: resolved.id, reason: .duration, frequency: hz, durationSeconds: duration)
            }
            return nil
        }
    }
}
