import Foundation

struct SyncTimelineEvent: Identifiable, Equatable {
    enum Kind: String { case tap, matching, wrong, uncertain }
    let id: UInt64
    /// Normalized host seconds (input hardware latency removed for guitar only).
    let time: Double
    let kind: Kind
}
struct SyncTimelineRun: Identifiable, Equatable {
    enum Source: String { case taps, guitar }
    enum Status: String { case running, completed, failed, cancelled, stale }
    let id = UUID()
    let source: Source
    var status: Status = .running
    var context = ""
    var origin: Double?
    let alignment: Double
    var events: [SyncTimelineEvent] = []
    var cursor: Double?
    /// The first four lines are listening clicks, followed by sixteen measured clicks.
    func position(_ event: SyncTimelineEvent) -> (beat: Int, delta: Double)? {
        guard let origin, origin.isFinite, alignment.isFinite, event.time.isFinite else { return nil }
        let relative = event.time - origin - alignment
        guard relative >= -0.5, relative < 19.5 else { return nil }
        let beat = Int(floor(relative + 0.5))
        return (beat, relative - Double(beat))
    }
    var outsideCount: Int { events.filter { position($0) == nil }.count }
}

/// Convert NSEvent's uptime timestamp at delivery, preserving queued-event age.
/// A delayed callback does not become a late tap merely because the main thread was busy.
enum SyncInputTimestamp {
    static func hostSeconds(event: Double, uptime: Double, hostNow: Double) -> Double? {
        guard event.isFinite, uptime.isFinite, hostNow.isFinite, event >= 0, hostNow >= 0,
              uptime >= event, uptime - event <= 2 else { return nil }
        let result = hostNow - (uptime - event)
        return result >= 0 ? result : nil
    }
}
