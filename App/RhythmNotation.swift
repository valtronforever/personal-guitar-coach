import Domain

/// Written fragments never become playback/assessment events. The source keeps one attack.
struct NotationFragmentID: Hashable, Sendable {
    let eventID: String
    let startTick: Int64
}

struct NotationDuration: Equatable, Sendable {
    let baseTicks: Int64
    let dotted: Bool
    var triplet = false
    var ticks: Int64 {
        let written = baseTicks + (dotted ? baseTicks / 2 : 0)
        return triplet ? written / 3 * 2 : written
    }
    var flags: Int { baseTicks == 240 ? 2 : baseTicks == 480 ? 1 : 0 }
    var label: String { TimelineModel.durationLabel(baseTicks) + (dotted ? "·" : "") }
    static let values: [Self] = [
        .init(baseTicks: 3840, dotted: false), .init(baseTicks: 1920, dotted: true),
        .init(baseTicks: 1920, dotted: false), .init(baseTicks: 960, dotted: true),
        .init(baseTicks: 960, dotted: false), .init(baseTicks: 480, dotted: true),
        .init(baseTicks: 480, dotted: false), .init(baseTicks: 240, dotted: false)
    ]
}

struct NotationFragment: Identifiable, Sendable {
    let id: NotationFragmentID
    let duration: NotationDuration
    let tieFromPrevious: Bool
    let tieToNext: Bool
    var tripletID: String? = nil
    var startTick: Int64 { id.startTick }
    var endTick: Int64 { startTick + duration.ticks }
}

enum RhythmNotation {
    /// Simple-meter notation down to sixteenths. Unsupported grids remain explicit.
    static func fragments(_ segment: TimelineSegment) throws -> [NotationFragment] {
        if let group = segment.triplet {
            guard segment.startTick == segment.resolved.event.startTick,
                  segment.endTick == segment.resolved.event.endTick,
                  let written = NotationDuration.values.first(where: { $0.ticks == segment.writtenDurationTicks }) else { throw StaffLimitation.duration }
            return [NotationFragment(id: .init(eventID: segment.id, startTick: segment.startTick),
                duration: NotationDuration(baseTicks: written.baseTicks, dotted: written.dotted, triplet: true),
                tieFromPrevious: false, tieToNext: false, tripletID: group.id)]
        }
        guard segment.startTick % 240 == 0, segment.endTick % 240 == 0 else { throw StaffLimitation.duration }
        var tick = segment.startTick, result: [NotationFragment] = []
        while tick < segment.endTick {
            // Split a long off-beat note at the next beat, keeping the pulse readable.
            let untilBoundary: Int64
            if segment.notationBoundaries.isEmpty {
                let remainder = tick % MusicalTime.ppq
                untilBoundary = remainder == 0 ? .max : MusicalTime.ppq - remainder
            } else {
                untilBoundary = segment.notationBoundaries.contains(tick) ? .max : (segment.notationBoundaries.first(where: { $0 > tick }) ?? segment.endTick) - tick
            }
            let available = min(segment.endTick - tick, untilBoundary)
            guard let value = NotationDuration.values.first(where: { $0.ticks <= available }) else { throw StaffLimitation.duration }
            let note = segment.resolved.event.kind == .note
            result.append(NotationFragment(id: .init(eventID: segment.resolved.id, startTick: tick), duration: value,
                tieFromPrevious: note && tick > segment.resolved.event.startTick,
                tieToNext: note && tick + value.ticks < segment.resolved.event.endTick))
            tick += value.ticks
        }
        return result
    }
}
