import Foundation

/// Conservative periodic-contour envelope; physical guitar acceptance is tracked separately.
public enum VibratoCapability {
    public static let version = "vibrato-capability-1"
    public static let baseFrequencyRange = 195.9...880.0
    public static let extentRange = 30...100
    public static let rateRange = 1.0...3.0
    public static func supportsFrequencies(_ vibrato: PitchVibrato, frequency: Double) -> Bool {
        baseFrequencyRange.contains(frequency) && frequency * pow(2, Double(vibrato.extentCents) / 1200) <= 1100
    }
    public static func supports(vibrato: PitchVibrato, durationTicks: Int64, bpm: Double, frequency: Double, pulseTicks: Int64) -> Bool {
        guard bpm.isFinite, bpm > 0, pulseTicks > 0, durationTicks > vibrato.endTick,
              extentRange.contains(vibrato.extentCents), vibrato.cycles >= 4,
              supportsFrequencies(vibrato, frequency: frequency) else { return false }
        let secondsPerTick = 60 / bpm / Double(pulseTicks)
        let rate = 1 / (Double(vibrato.periodTicks) * secondsPerTick)
        return rate >= rateRange.lowerBound - 1e-9 && rate <= rateRange.upperBound + 1e-9
            && Double(vibrato.startTick) * secondsPerTick >= 0.4 - 1e-9
            && Double(durationTicks - vibrato.endTick) * secondsPerTick >= 0.4 - 1e-9
    }
}
