import Foundation

/// Conservative clean-signal envelope. Real instrument validation is tracked separately.
public enum PitchTransitionCapability {
    public static let version = "pitch-transition-capability-1"
    public static let baseFrequencyRange = 195.9...880.0
    public static let targetFrequencyRange = 195.9...1100.0
    public static func supportsFrequencies(_ transition: PitchTransition, frequency: Double) -> Bool {
        baseFrequencyRange.contains(frequency) && targetFrequencyRange.contains(frequency * pow(2, Double(transition.semitones) / 12))
    }
    public static func supports(transition: PitchTransition, durationTicks: Int64, bpm: Double, frequency: Double, pulseTicks: Int64) -> Bool {
        guard bpm.isFinite, bpm > 0, pulseTicks > 0, durationTicks > transition.endTick,
              supportsFrequencies(transition, frequency: frequency) else { return false }
        let secondsPerTick = 60 / bpm / Double(pulseTicks)
        guard Double(transition.startTick) * secondsPerTick >= 0.4 - 1e-9,
              Double(durationTicks - transition.endTick) * secondsPerTick >= 0.4 - 1e-9 else { return false }
        if transition.kind == .slide {
            let travel = Double(transition.travelTicks) * secondsPerTick
            return travel >= 0.5 - 1e-9 && Double(abs(transition.semitones) * 100) / travel <= 200 + 1e-9
        }
        return true
    }
}
