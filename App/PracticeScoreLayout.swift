import Foundation
import Domain

/// Whole bars wrap; a synthetic count-in slot is inserted before the selected practice range.
/// This is presentation geometry only: count-in never becomes an Exercise event.
struct PracticeScoreLayout: Equatable {
    static let gutter = 28.0
    static let rowHeight = 164.0
    static let rowSpacing = 16.0
    let barCount: Int64
    let firstBar: Int64
    let ticksPerBar: Int64
    let beatsPerBar: Int
    let barsPerRow: Int64
    let contentRowHeight: Double
    let barWidth: Double
    var rowCount: Int64 { (barCount + barsPerRow) / barsPerRow }
    var countInSlot: Int64 { firstBar }
    var startTick: Double { Double(firstBar * ticksPerBar) }

    init(timeline: TimelineModel, firstBar: Int, width: Double, zoom: Double = 1) {
        contentRowHeight = Self.rowHeight + (timeline.exercise.triplets.isEmpty ? 0 : 16)
        barCount = timeline.barCount
        self.firstBar = min(barCount - 1, max(0, Int64(firstBar - 1)))
        ticksPerBar = timeline.ticksPerBar; beatsPerBar = timeline.exercise.timeSignature.beatsPerBar
        let usable = max(240, (width.isFinite ? width : 600) - Self.gutter)
        let scale = zoom.isFinite ? min(1.5, max(0.8, zoom)) : 1
        barsPerRow = Int64(max(1, min(4, floor(usable / (Double(beatsPerBar) * 60 * scale)))))
        barWidth = usable / Double(barsPerRow)
    }

    func slots(in row: Int64) -> Range<Int64> {
        let lower = row * barsPerRow
        return lower..<min(barCount + 1, lower + barsPerRow)
    }
    func bar(for slot: Int64) -> Int64? {
        if slot == countInSlot { return nil }
        return slot < countInSlot ? slot : slot - 1
    }
    func slot(for bar: Int64) -> Int64 { bar < firstBar ? bar : bar + 1 }
    func x(tick: Double, bar: Int64) -> Double {
        min(barWidth, max(0, (tick - Double(bar * ticksPerBar)) / Double(ticksPerBar) * barWidth))
    }
    func cursor(_ tick: Double?, endTick: Int64) -> (row: Int64, x: Double)? {
        guard let tick, tick.isFinite, tick >= startTick - Double(ticksPerBar), tick <= Double(endTick) else { return nil }
        let slot: Int64, progress: Double
        if tick < startTick {
            slot = countInSlot
            progress = (tick - startTick + Double(ticksPerBar)) / Double(ticksPerBar)
        } else {
            // At an exact end boundary keep the line at the right edge of the preceding bar.
            let bar = min(barCount - 1, max(firstBar, Int64(floor(tick / Double(ticksPerBar))) - (tick == Double(endTick) && endTick % ticksPerBar == 0 ? 1 : 0)))
            slot = self.slot(for: bar)
            progress = (tick - Double(bar * ticksPerBar)) / Double(ticksPerBar)
        }
        return (slot / barsPerRow, Self.gutter + (Double(slot % barsPerRow) + min(1, max(0, progress))) * barWidth)
    }
}
