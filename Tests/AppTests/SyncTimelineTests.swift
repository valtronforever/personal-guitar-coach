import Foundation
import Testing
@testable import PersonalGuitarCoach

struct SyncTimelineTests {
    @Test func projectionKeepsWarmupMissingExtraAndUncertainEventsWithSavedAlignment() throws {
        var run = SyncTimelineRun(source: .guitar, origin: 100, alignment: 0.2)
        run.events = [
            .init(id: 1, time: 100.2, kind: .matching),
            .init(id: 2, time: 104.25, kind: .matching),
            .init(id: 3, time: 104.4, kind: .wrong),
            .init(id: 4, time: 104.65, kind: .uncertain),
            .init(id: 5, time: 121, kind: .uncertain)
        ]
        #expect(run.position(run.events[0])?.beat == 0)
        #expect(run.position(run.events[1])?.beat == 4)
        #expect(abs(try #require(run.position(run.events[1])?.delta) - 0.05) < 1e-9)
        #expect(run.events.filter { run.position($0)?.beat == 4 }.count == 3)
        #expect(run.outsideCount == 1)
        for status in [SyncTimelineRun.Status.completed, .failed, .cancelled, .stale] {
            run.status = status
            #expect(run.events.count == 5 && run.outsideCount == 1)
        }
        run.origin = nil
        #expect(run.outsideCount == 5 && run.events.count == 5)
    }
    @Test func queuedInputUsesEventTimeAndInvalidClockValuesAreRejected() {
        #expect(SyncInputTimestamp.hostSeconds(event: 100, uptime: 100.12, hostNow: 400.12) == 400)
        #expect(SyncInputTimestamp.hostSeconds(event: 100, uptime: 100, hostNow: 400) == 400)
        for invalid in [-1.0, 101, .nan, .infinity] {
            #expect(SyncInputTimestamp.hostSeconds(event: invalid, uptime: 100, hostNow: 400) == nil)
        }
        #expect(SyncInputTimestamp.hostSeconds(event: 97, uptime: 100, hostNow: 400) == nil)
        #expect(SyncTimelineView.signedMilliseconds(.nan) == "—")
        #expect(SyncTimelineView.signedMilliseconds(0.023) == "+23")
        #expect(SyncTimelineView.signedMilliseconds(-0.023) == "-23")
    }
}

struct LatencyEntryTests {
    @Test func nonnegativeMillisecondsAcceptLocaleDecimalsButRejectNegativeOrPartialInput() {
        for (text, expected) in [("+120", 0.12), ("25,5", 0.0255), ("  25.5 ", 0.0255), ("0", 0), (".5", 0.0005), ("1000", 1.0)] {
            #expect(LatencyEntryParser.seconds(text) == expected)
        }
        for text in ["-25", "−25,5", "-0", "-0.001", "", "120ms", "12,3,4", "1 000", "NaN", "inf", "1e2", "+-20", "1001", "-1001"] {
            #expect(LatencyEntryParser.seconds(text) == nil)
        }
    }
}
