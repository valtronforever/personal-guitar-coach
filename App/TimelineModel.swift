import Foundation
import Domain

struct TimelineFollowTarget: Hashable, Sendable { let bar: Int64; let halfBeat: Int }

struct TimelineSegment: Identifiable, Sendable {
    let resolved: ResolvedEvent
    let bar: Int64
    let startTick: Int64
    let endTick: Int64
    var id: String { resolved.id }
    var isContinuation: Bool { startTick > resolved.event.startTick }
}

/// Geometry uses bar-relative integer ticks, preserving precision even for large absolute times.
struct TimelineModel: Sendable {
    static let barsPerPage: Int64 = 16
    static let baseBeatWidth = 176.0 // A sixteenth retains a 44-point target at the smallest zoom.
    let exercise: Exercise
    let events: [ResolvedEvent]
    let tuning: TuningProfile
    var ticksPerBar: Int64 { exercise.timeSignature.ticksPerBar }
    var barCount: Int64 { (exercise.durationTicks - 1) / ticksPerBar + 1 }

    init(exercise: Exercise, instrument: TuningProfile) throws {
        self.exercise = exercise
        tuning = exercise.requiredTuning ?? instrument
        events = try exercise.resolvedEvents(instrument: instrument)
    }

    func bar(containing tick: Int64) -> Int64 { min(barCount - 1, max(0, tick) / ticksPerBar) }
    func startTick(of bar: Int64) -> Int64 { min(barCount - 1, max(0, bar)) * ticksPerBar }
    func page(containing bar: Int64) -> Range<Int64> {
        let bounded = min(barCount - 1, max(0, bar))
        let first = bounded / Self.barsPerPage * Self.barsPerPage
        return first..<min(barCount, first + Self.barsPerPage)
    }
    func barWidth(zoom: Double) -> Double { Double(exercise.timeSignature.beatsPerBar) * Self.baseBeatWidth * boundedZoom(zoom) }
    func x(tick: Int64, bar: Int64, zoom: Double) -> Double {
        let start = startTick(of: bar)
        let offset = tick <= start ? 0 : min(ticksPerBar, tick - start)
        return Double(offset) / Double(MusicalTime.ppq) * Self.baseBeatWidth * boundedZoom(zoom)
    }
    func tick(x: Double, bar: Int64, zoom: Double) -> Int64? {
        guard x.isFinite, x >= 0, x < barWidth(zoom: zoom) else { return nil }
        let offset = Int64((x / (Self.baseBeatWidth * boundedZoom(zoom)) * Double(MusicalTime.ppq)).rounded(.down))
        let start = startTick(of: bar)
        guard offset <= exercise.durationTicks - start else { return nil }
        return start + offset
    }
    func segments(in bar: Int64) -> [TimelineSegment] {
        guard (0..<barCount).contains(bar) else { return [] }
        let start = startTick(of: bar)
        let end = start + min(ticksPerBar, exercise.durationTicks - start)
        // First event whose end is after the start of this bar.
        var lower = 0, upper = events.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if events[middle].event.endTick <= start { lower = middle + 1 } else { upper = middle }
        }
        var result: [TimelineSegment] = []
        while lower < events.count, events[lower].event.startTick < end {
            let event = events[lower]
            result.append(TimelineSegment(resolved: event, bar: bar, startTick: max(start, event.event.startTick), endTick: min(end, event.event.endTick)))
            lower += 1
        }
        return result
    }
    func eventID(atX x: Double, bar: Int64, zoom: Double) -> String? {
        guard let tick = tick(x: x, bar: bar, zoom: zoom) else { return nil }
        return segments(in: bar).first { $0.startTick <= tick && tick < $0.endTick }?.id
    }
    func adjacent(to id: String, offset: Int) -> ResolvedEvent? {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return nil }
        return events[min(events.count - 1, max(0, index + offset))]
    }
    func cursorBar(_ tick: Int64?) -> Int64? {
        guard let tick, (0...exercise.durationTicks).contains(tick) else { return nil }
        return bar(containing: tick)
    }
    /// Following half-beat cells keeps the cursor visible at 2× zoom without scrolling every audio/UI frame.
    func followTarget(_ tick: Int64?) -> TimelineFollowTarget? {
        guard let tick, let bar = cursorBar(tick) else { return nil }
        return TimelineFollowTarget(bar: bar, halfBeat: Int((tick - startTick(of: bar)) / (MusicalTime.ppq / 2)))
    }
    static func durationLabel(_ ticks: Int64) -> String {
        var a = ticks, b = MusicalTime.ppq * 4
        while b != 0 { (a, b) = (b, a % b) }
        let numerator = ticks / a, denominator = MusicalTime.ppq * 4 / a
        return denominator == 1 ? String(numerator) : "\(numerator)/\(denominator)"
    }
    private func boundedZoom(_ zoom: Double) -> Double { zoom.isFinite ? min(2, max(1, zoom)) : 1 }
}

struct TimelineSelection: Equatable {
    private(set) var anchorID: String?
    private(set) var ids: Set<String> = []
    mutating func select(_ id: String, extending: Bool, events: [MusicalEvent]) {
        guard let target = events.firstIndex(where: { $0.id == id }) else { return }
        if extending, let anchorID, let anchor = events.firstIndex(where: { $0.id == anchorID }) {
            ids = Set(events[min(anchor, target)...max(anchor, target)].map(\.id))
        } else { anchorID = id; ids = [id] }
    }
    mutating func clear() { anchorID = nil; ids = [] }
}
