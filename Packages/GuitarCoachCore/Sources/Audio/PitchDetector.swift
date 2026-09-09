import Accelerate
import Foundation
import Domain

public enum PitchMethod: String, CaseIterable, Codable, Sendable { case yin, mpm }

public struct PeriodEstimate: Equatable, Codable, Sendable {
    public let frequency: Double
    /// Periodicity/clarity, not a calibrated probability of correctness.
    public let clarity: Double
    public let octaveAmbiguous: Bool
    public let fundamentalFraction: Double
}

/// Worker-owned reusable storage. No exercise, target note or tuning enters the estimator.
/// Original implementation of YIN steps 2–5 and MPM NSDF; see docs/decisions/002-monophonic-analysis.md.
public final class PitchDetector {
    public static let windowFrames = 4096
    public let sampleRate: Double
    public let method: PitchMethod
    private let maximumLag: Int
    private let minimumLag: Int
    private var centered = [Float](repeating: 0, count: windowFrames)
    private var curve: [Float]
    private var raw: [Float]
    private let hann: [Float]

    public init(sampleRate: Double, method: PitchMethod = .mpm) throws {
        guard MonophonicCapability.sampleRates.contains(sampleRate) else { throw AudioBackendError.invalidFormat }
        self.sampleRate = sampleRate; self.method = method
        maximumLag = Int(sampleRate / 35)
        minimumLag = max(2, Int(sampleRate / 2500))
        curve = .init(repeating: 0, count: maximumLag + 2)
        raw = curve
        hann = (0..<Self.windowFrames).map { Float(0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(Self.windowFrames - 1))) }
    }

    public func estimate(_ samples: UnsafeBufferPointer<Float>) -> PeriodEstimate? {
        guard samples.count == Self.windowFrames, samples.allSatisfy(\.isFinite) else { return nil }
        var mean: Float = 0
        vDSP_meanv(samples.baseAddress!, 1, &mean, vDSP_Length(samples.count))
        for i in centered.indices { centered[i] = samples[i] - mean }
        return centered.withUnsafeBufferPointer { signal in
            var energy: Float = 0
            vDSP_svesq(signal.baseAddress!, 1, &energy, vDSP_Length(signal.count))
            guard energy > 1e-10 else { return nil }
            let lag: Int?
            switch method {
            case .yin: lag = yin(signal)
            case .mpm: lag = mpm(signal, energy: energy)
            }
            guard let lag else { return nil }
            let offset = Self.parabolicOffset(raw[lag - 1], raw[lag], raw[lag + 1])
            let period = Double(lag) + offset
            let frequency = sampleRate / period
            guard frequency.isFinite, (35...2500).contains(frequency) else { return nil }
            let selectedValue = interpolatedValue(at: lag)
            let clarity = min(1, max(0, method == .mpm ? selectedValue : 1 - selectedValue))
            // A materially better double-period candidate is exposed, never silently octave-corrected.
            let twice = Int((period * 2).rounded())
            let ambiguous: Bool
            if twice + 1 < curve.count {
                let alternate = (max(1, twice - 1)...min(maximumLag, twice + 1)).map { interpolatedValue(at: $0) }
                ambiguous = method == .mpm
                    ? (alternate.max() ?? 0) - selectedValue > 0.008
                    : selectedValue - (alternate.min() ?? 1) > 0.008
            } else { ambiguous = false }
            // A harmonic pair may imply an absent sub-fundamental. Retain this evidence for the quality gate.
            let coefficient = 2 * cos(2 * Double.pi * frequency / sampleRate)
            var first = 0.0, second = 0.0
            for i in signal.indices {
                let next = Double(signal[i] * hann[i]) + coefficient * first - second
                second = first; first = next
            }
            let power = max(0, first * first + second * second - coefficient * first * second)
            let fraction = min(1, 8 * power / (Double(signal.count) * Double(energy)))
            return PeriodEstimate(frequency: frequency, clarity: clarity, octaveAmbiguous: ambiguous,
                                  fundamentalFraction: fraction)
        }
    }

    private func interpolatedValue(at lag: Int) -> Double {
        let offset = Self.parabolicOffset(curve[lag - 1], curve[lag], curve[lag + 1])
        return Double(curve[lag]) - 0.25 * Double(curve[lag - 1] - curve[lag + 1]) * offset
    }

    private func yin(_ signal: UnsafeBufferPointer<Float>) -> Int? {
        let length = signal.count - maximumLag - 1
        var sum: Float = 0
        curve[0] = 1; raw[0] = 0
        for lag in 1...maximumLag + 1 {
            var difference: Float = 0
            vDSP_distancesq(signal.baseAddress!, 1, signal.baseAddress! + lag, 1, &difference, vDSP_Length(length))
            raw[lag] = difference; sum += difference
            curve[lag] = sum > 0 ? difference * Float(lag) / sum : 1
        }
        var lag = minimumLag
        while lag <= maximumLag {
            if curve[lag] < 0.1 {
                while lag < maximumLag && curve[lag + 1] < curve[lag] { lag += 1 }
                return lag
            }
            lag += 1
        }
        // Unlike a forced pitch output, an aperiodic minimum remains explicitly unavailable.
        return nil
    }

    private func mpm(_ signal: UnsafeBufferPointer<Float>, energy: Float) -> Int? {
        var normalization = 2 * energy
        curve[0] = 1
        for lag in 1...maximumLag + 1 {
            normalization -= signal[lag - 1] * signal[lag - 1] + signal[signal.count - lag] * signal[signal.count - lag]
            var correlation: Float = 0
            vDSP_dotpr(signal.baseAddress!, 1, signal.baseAddress! + lag, 1, &correlation, vDSP_Length(signal.count - lag))
            curve[lag] = normalization > 1e-10 ? 2 * correlation / normalization : 0
        }
        for i in curve.indices { raw[i] = curve[i] }
        var maximum: Float = 0
        var leftZeroLobe = false
        // Two passes avoid an unbounded list of candidate peaks.
        for lag in 1...maximumLag {
            if curve[lag] <= 0 { leftZeroLobe = true }
            if leftZeroLobe, lag >= minimumLag, curve[lag] > curve[lag - 1], curve[lag] >= curve[lag + 1] {
                maximum = max(maximum, curve[lag])
            }
        }
        guard maximum >= 0.9 else { return nil }
        leftZeroLobe = false
        var lobeMaximum: Int?
        for lag in 1...maximumLag + 1 {
            if curve[lag] <= 0 || lag == maximumLag + 1 {
                if let candidate = lobeMaximum, curve[candidate] >= maximum * 0.93 { return candidate }
                leftZeroLobe = true; lobeMaximum = nil
            } else if leftZeroLobe, lag >= minimumLag, curve[lag] > curve[lag - 1], curve[lag] >= curve[lag + 1],
                      lobeMaximum == nil || curve[lag] > curve[lobeMaximum!] {
                lobeMaximum = lag
            }
        }
        return nil
    }

    private static func parabolicOffset(_ left: Float, _ center: Float, _ right: Float) -> Double {
        let denominator = Double(left) - 2 * Double(center) + Double(right)
        guard abs(denominator) > 1e-12 else { return 0 }
        return max(-0.5, min(0.5, 0.5 * (Double(left) - Double(right)) / denominator))
    }
}
