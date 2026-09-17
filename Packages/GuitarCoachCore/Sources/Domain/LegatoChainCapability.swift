import Foundation

/// Slow, clean same-string phrases. A correct contour does not establish which hand produced it.
public enum LegatoChainCapability {
    public static let version = "legato-chain-capability-1"
    public static let baseFrequencyRange = 195.9...880.0
    public static let targetFrequencyRange = 195.9...1100.0
    public static let minimumPlateauSeconds = 0.4
    public static func supportsFrequencies(_ chain: LegatoChain, frequency: Double) -> Bool {
        baseFrequencyRange.contains(frequency) && chain.semitoneOffsets.allSatisfy {
            targetFrequencyRange.contains(frequency * pow(2, Double($0) / 12))
        }
    }
    public static func supports(chain: LegatoChain, durationTicks: Int64, bpm: Double, frequency: Double, pulseTicks: Int64) -> Bool {
        guard bpm.isFinite, bpm > 0, pulseTicks > 0, durationTicks > chain.targets.last!.startTick,
              supportsFrequencies(chain, frequency: frequency) else { return false }
        let boundaries = chain.boundaryTicks + [durationTicks], secondsPerTick = 60 / bpm / Double(pulseTicks)
        return zip(boundaries, boundaries.dropFirst()).allSatisfy {
            Double($1 - $0) * secondsPerTick >= minimumPlateauSeconds - 1e-9
        }
    }
}
