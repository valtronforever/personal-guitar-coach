import Foundation

/// Conservative initial clean-signal envelope; physical guitar validation is tracked separately.
public enum BendCapability {
    public static let version = "bend-capability-1"
    public static let baseFrequencyRange = 195.9...880.0
    public static let maximumTargetFrequency = 1100.0
    public static func supports(bend: PitchBend, durationTicks: Int64, bpm: Double, frequency: Double) -> Bool {
        guard baseFrequencyRange.contains(frequency), frequency * pow(2, Double(bend.semitones) / 12) <= maximumTargetFrequency else { return false }
        let points = bend.points(durationTicks: durationTicks), secondsPerTick = 60 / bpm / 960
        return zip(points, points.dropFirst()).allSatisfy { a, b in
            let seconds = Double(b.tick - a.tick) * secondsPerTick
            return seconds >= 0.4 - 1e-9 && abs(b.cents - a.cents) / seconds <= 400 + 1e-9
        }
    }
}
