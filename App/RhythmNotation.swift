import Domain

/// Written fragments never become playback/assessment events. The source keeps one attack.
struct NotationFragmentID: Hashable, Sendable {
    let eventID: String
    let startTick: Int64
}

struct NotationDuration: Equatable, Sendable {
    let baseTicks: Int64
    let dotted: Bool
    var ticks: Int64 { baseTicks + (dotted ? baseTicks / 2 : 0) }
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
    var startTick: Int64 { id.startTick }
    var endTick: Int64 { startTick + duration.ticks }
}

enum RhythmNotation {
    /// Simple-meter notation down to sixteenths. Unsupported grids remain explicit.
    static func fragments(_ segment: TimelineSegment) throws -> [NotationFragment] {
        guard segment.startTick % 240 == 0, segment.endTick % 240 == 0 else { throw StaffLimitation.duration }
        var tick = segment.startTick, result: [NotationFragment] = []
        while tick < segment.endTick {
            // Split a long off-beat note at the next beat, keeping the pulse readable.
            let beatRemainder = tick % MusicalTime.ppq
            let available = min(segment.endTick - tick, beatRemainder == 0 ? Int64.max : MusicalTime.ppq - beatRemainder)
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
