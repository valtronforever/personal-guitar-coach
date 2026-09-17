import Foundation

/// Versioned software capability from the task 12 corpus. Physical-route validation remains separate.
public enum MonophonicCapability {
    public static let harmonicVersion = "mono-capability-7"
    public static let legatoChainVersion = "mono-capability-6"
    public static let version = "mono-capability-3"
    public static let vibratoVersion = "mono-capability-5"
    public static let pitchTransitionVersion = "mono-capability-4"
    public static let frequencyRange = 55.0...1500.0
    public static let minimumNoteSeconds = 0.2
    public static let sampleRates: Set<Double> = [44100, 48000]

    public static func supportsTarget(_ pitch: Pitch, referenceA4: Double) -> Bool {
        guard Exercise.monophonicMIDITarget.contains(pitch.midi),
              let hz = try? pitch.frequency(referenceA4: referenceA4) else { return false }
        return frequencyRange.contains(hz)
    }

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
            let hz = try resolved.event.soundingFrequencies(in: tuning)[0]
            let duration = try MusicalTime.seconds(forTicks: resolved.event.durationTicks, bpm: bpm, pulseTicks: exercise.timeSignature.pulseTicks)
            if !supportsTarget(pitch, referenceA4: tuning.referenceA4) || !frequencyRange.contains(hz) {
                return Limitation(eventID: resolved.id, reason: .frequency, frequency: hz, durationSeconds: duration)
            }
            if let bend = resolved.event.bend {
                if !BendCapability.baseFrequencyRange.contains(hz) || hz * pow(2, Double(bend.semitones) / 12) > BendCapability.maximumTargetFrequency {
                    return Limitation(eventID: resolved.id, reason: .frequency, frequency: hz, durationSeconds: duration)
                }
                if !BendCapability.supports(bend: bend, durationTicks: resolved.event.durationTicks, bpm: bpm, frequency: hz, pulseTicks: exercise.timeSignature.pulseTicks) {
                    return Limitation(eventID: resolved.id, reason: .duration, frequency: hz, durationSeconds: duration)
                }
            }
            if let transition = resolved.event.pitchTransition {
                if !PitchTransitionCapability.supportsFrequencies(transition, frequency: hz) {
                    return Limitation(eventID: resolved.id, reason: .frequency, frequency: hz, durationSeconds: duration)
                }
                if !PitchTransitionCapability.supports(transition: transition, durationTicks: resolved.event.durationTicks, bpm: bpm, frequency: hz, pulseTicks: exercise.timeSignature.pulseTicks) {
                    return Limitation(eventID: resolved.id, reason: .duration, frequency: hz, durationSeconds: duration)
                }
            }
            if let chain = resolved.event.legatoChain {
                if !LegatoChainCapability.supportsFrequencies(chain, frequency: hz) {
                    return Limitation(eventID: resolved.id, reason: .frequency, frequency: hz, durationSeconds: duration)
                }
                if !LegatoChainCapability.supports(chain: chain, durationTicks: resolved.event.durationTicks, bpm: bpm, frequency: hz, pulseTicks: exercise.timeSignature.pulseTicks) {
                    return Limitation(eventID: resolved.id, reason: .duration, frequency: hz, durationSeconds: duration)
                }
            }
            if let vibrato = resolved.event.vibrato {
                if !VibratoCapability.supportsFrequencies(vibrato, frequency: hz) {
                    return Limitation(eventID: resolved.id, reason: .frequency, frequency: hz, durationSeconds: duration)
                }
                if !VibratoCapability.supports(vibrato: vibrato, durationTicks: resolved.event.durationTicks, bpm: bpm, frequency: hz, pulseTicks: exercise.timeSignature.pulseTicks) {
                    return Limitation(eventID: resolved.id, reason: .duration, frequency: hz, durationSeconds: duration)
                }
            }
            if duration + 1e-9 < (resolved.event.assessSustain ? SustainTrace.minimumNoteSeconds : minimumNoteSeconds) {
                return Limitation(eventID: resolved.id, reason: .duration, frequency: hz, durationSeconds: duration)
            }
            return nil
        }
    }
}
