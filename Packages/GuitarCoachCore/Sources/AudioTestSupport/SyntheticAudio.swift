import Foundation

public struct SyntheticNote: Sendable {
    public let onset: Double
    public let duration: Double
    public let frequency: Double
    public let amplitude: Double
    public let harmonics: [Double]
    public let attack: Double
    public init(onset: Double = 0.1, duration: Double = 0.6, frequency: Double, amplitude: Double = 0.25,
                harmonics: [Double] = [1, 0.4, 0.2, 0.1], attack: Double = 0.003) {
        self.onset = onset; self.duration = duration; self.frequency = frequency
        self.amplitude = amplitude; self.harmonics = harmonics; self.attack = attack
    }
}

/// Original deterministic fixtures, generated locally. Never presented as a guitar recording.
public enum SyntheticAudio {
    public static func render(rate: Double, duration: Double, notes: [SyntheticNote], noise: Double = 0.0001,
                              seed: UInt64 = 42, clip: Bool = false) -> [Float] {
        var random = seed
        var samples = [Float](repeating: 0, count: Int((duration * rate).rounded()))
        for i in samples.indices {
            random = random &* 6364136223846793005 &+ 1442695040888963407
            var value = (Double(random >> 11) / Double(UInt64(1) << 53) * 2 - 1) * noise
            let time = Double(i) / rate
            for note in notes {
                let age = time - note.onset
                guard age >= 0, age < note.duration else { continue }
                let envelope = min(1, age / max(1 / rate, note.attack)) * min(1, (note.duration - age) / 0.015) * exp(-age * 0.7)
                let normalization = max(1, note.harmonics.reduce(0, +))
                for (index, harmonic) in note.harmonics.enumerated() where Double(index + 1) * note.frequency < rate / 2 {
                    value += note.amplitude * envelope * harmonic / normalization * sin(2 * .pi * note.frequency * Double(index + 1) * age)
                }
            }
            samples[i] = Float(clip ? max(-1, min(1, value)) : value)
        }
        return samples
    }
}
