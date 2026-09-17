import Foundation
import Testing
import Domain
@testable import Learning

struct VibratoStatisticsTests {
    private func trace(width: Double = 80, rate: Double = 2, offset: Double = 0, irregular: Bool = false, gap: Bool = false) throws -> [SustainFrame] {
        try (0...300).map { index in
            let time = Double(index) * 0.02
            let phase = irregular && time > 3 ? 3 * rate + (time - 3) * rate * 0.5 : time * rate
            let cents = offset + width * (1 - cos(2 * .pi * phase)) / 2
            if gap && (2...4).contains(time) { return try SustainFrame(id: UInt64(index + 1), normalizedTime: time, state: .uncertain, frequency: nil) }
            return try SustainFrame(id: UInt64(index + 1), normalizedTime: time, state: .pitched, frequency: 220 * pow(2, cents / 1200))
        }
    }
    @Test func phaseIndependentWidthRateAndIrregularityAreMeasured() throws {
        for rate in [1.0, 2, 3] {
            let value = VibratoStatistics(frames: try trace(rate: rate), range: 0..<6, baseFrequency: 220)
            #expect(abs((value.widthCents ?? 0) - 80) < 4)
            #expect(abs((value.rateHz ?? 0) - rate) < 0.03)
            #expect((value.periodVariation ?? 1) < 0.03)
        }
        let wrong = VibratoStatistics(frames: try trace(width: 150, rate: 4, offset: 100), range: 0..<6, baseFrequency: 220)
        #expect((wrong.lowCents ?? 0) > 99 && (wrong.widthCents ?? 0) > 140 && (wrong.rateHz ?? 0) > 3.9)
        let irregular = VibratoStatistics(frames: try trace(irregular: true), range: 0..<6, baseFrequency: 220)
        #expect((irregular.periodVariation ?? 0) > 0.4)
        let flat = VibratoStatistics(frames: try trace(width: 0), range: 0..<6, baseFrequency: 220)
        #expect(flat.widthCents == 0 && flat.rateHz == nil && flat.measuredPeriods == 0)
        let gap = VibratoStatistics(frames: try trace(gap: true), range: 0..<6, baseFrequency: 220)
        #expect(abs((gap.rateHz ?? 0) - 2) < 0.03 && (gap.periodVariation ?? 1) < 0.03)
        let absent = VibratoStatistics(frames: [], range: 0..<6, baseFrequency: 220)
        #expect(absent.widthCents == nil && absent.rateHz == nil)
    }
}
