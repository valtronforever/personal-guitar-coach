import Foundation
import Domain

/// Statistics describe audible oscillation, independently of its arbitrary phase relative to the click.
/// Uncertain/silent frames break cycle continuity; they are never bridged into a measured period.
struct VibratoStatistics {
    let lowCents: Double?
    let highCents: Double?
    let slowestRateHz: Double?
    let fastestRateHz: Double?
    let rateHz: Double?
    let periodVariation: Double?
    let measuredPeriods: Int
    var widthCents: Double? { lowCents.flatMap { low in highCents.map { $0 - low } } }

    init(frames: [SustainFrame], range: Range<Double>, baseFrequency: Double) {
        let selected = frames.filter { range.contains($0.normalizedTime) }
        let cents = selected.compactMap { frame -> Double? in
            guard frame.state == .pitched, let frequency = frame.frequency else { return nil }
            return 1200 * (log2(frequency) - log2(baseFrequency))
        }.sorted()
        func percentile(_ fraction: Double) -> Double? {
            guard !cents.isEmpty else { return nil }
            let location = Double(cents.count - 1) * fraction, index = Int(location)
            return cents[index] + (cents[min(cents.count - 1, index + 1)] - cents[index]) * (location - Double(index))
        }
        lowCents = percentile(0.05); highCents = percentile(0.95)
        guard let lowCents, let highCents, highCents - lowCents >= 5 else {
            rateHz = nil; slowestRateHz = nil; fastestRateHz = nil; periodVariation = nil; measuredPeriods = 0; return
        }
        let lower = lowCents + 0.2 * (highCents - lowCents), upper = lowCents + 0.8 * (highCents - lowCents)
        var armed = false, previous: (time: Double, cents: Double)?, crossing: Double?, periods: [Double] = []
        for frame in selected {
            guard frame.state == .pitched, let frequency = frame.frequency else {
                armed = false; previous = nil; crossing = nil; continue
            }
            let point = (time: frame.normalizedTime, cents: 1200 * (log2(frequency) - log2(baseFrequency)))
            if let previous, point.time - previous.time > 0.1 + 1e-9 { armed = false; crossing = nil }
            if point.cents <= lower { armed = true }
            if armed, point.cents >= upper, let previous, point.cents > previous.cents, previous.cents < upper {
                let time = previous.time + (point.time - previous.time) * (upper - previous.cents) / (point.cents - previous.cents)
                if let crossing, time > crossing { periods.append(time - crossing) }
                crossing = time; armed = false
            }
            previous = point
        }
        measuredPeriods = periods.count
        guard periods.count >= 2 else { rateHz = nil; slowestRateHz = nil; fastestRateHz = nil; periodVariation = nil; return }
        let sorted = periods.sorted(), middle = sorted.count / 2
        let median = sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        slowestRateHz = 1 / sorted.last!; fastestRateHz = 1 / sorted.first!
        rateHz = 1 / median
        // Maximum relative deviation prevents a few erratic cycles being hidden by the median.
        periodVariation = periods.map { abs($0 - median) / median }.max()
    }
}
