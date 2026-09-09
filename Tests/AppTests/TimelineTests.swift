import Testing
import Domain
@testable import PersonalGuitarCoach

struct TimelineTests {
    private func note(_ id: String, _ start: Int64, _ duration: Int64, fret: Int = 0) throws -> MusicalEvent {
        try MusicalEvent(id: id, startTick: start, durationTicks: duration, kind: .note, positions: [FretPosition(string: 1, fret: fret)])
    }
    @Test func mixedDurationsAndRestsShareOneTickGeometry() throws {
        let exercise = try Exercise(id: "rhythm", events: [note("quarter", 0, 960),
            MusicalEvent(id: "rest", startTick: 960, durationTicks: 480, kind: .rest), note("sixteenth", 1440, 240), note("last", 1680, 240)], timeSignature: .threeFour)
        let model = try TimelineModel(exercise: exercise, instrument: .standard)
        #expect(model.barCount == 1)
        for zoom in [1.0, 1.5, 2.0] {
            #expect(model.barWidth(zoom: zoom) == 528 * zoom)
            #expect(model.x(tick: 960, bar: 0, zoom: zoom) == 176 * zoom)
            #expect(model.eventID(atX: 176 * zoom, bar: 0, zoom: zoom) == "rest")
            #expect(model.eventID(atX: 275 * zoom, bar: 0, zoom: zoom) == "sixteenth")
            #expect(model.eventID(atX: 400 * zoom, bar: 0, zoom: zoom) == nil)
            #expect(model.eventID(atX: -1, bar: 0, zoom: zoom) == nil)
        }
        #expect(TimelineModel.durationLabel(960) == "1/4")
        #expect(TimelineModel.durationLabel(480) == "1/8")
        #expect(TimelineModel.durationLabel(240) == "1/16")
        #expect(TimelineModel.durationLabel(1440) == "3/8")
    }
    @Test func sustainedEventsCrossBarlinesWithoutInventingAnotherAttack() throws {
        let exercise = try Exercise(id: "held", events: [note("held", 0, 4320), note("next", 4320, 960)])
        let model = try TimelineModel(exercise: exercise, instrument: .standard)
        let first = try #require(model.segments(in: 0).first)
        let second = try #require(model.segments(in: 1).first)
        #expect(first.id == second.id)
        #expect(!first.isContinuation && second.isContinuation)
        #expect(first.endTick == 3840 && second.startTick == 3840 && second.endTick == 4320)
        #expect(model.eventID(atX: 88, bar: 1, zoom: 1) == "next")
    }
    @Test func cursorUsesIncomingTicksIndependentlyOfZoom() throws {
        let model = try TimelineModel(exercise: Exercise(id: "cursor", events: [note("long", 0, 7680)]), instrument: .standard)
        #expect(model.cursorBar(-1) == nil)
        #expect(model.cursorBar(3840) == 1)
        #expect(model.cursorBar(7680) == 1)
        #expect(model.cursorBar(7681) == nil)
        #expect(model.x(tick: 4080, bar: 1, zoom: 1) == 44)
        #expect(model.x(tick: 4080, bar: 1, zoom: 2) == 88)
        #expect(model.tick(x: 88, bar: 1, zoom: 2) == 4080)
        #expect(model.followTarget(4080) == TimelineFollowTarget(bar: 1, halfBeat: 0))
        #expect(model.followTarget(4319) == model.followTarget(4080))
        #expect(model.followTarget(4320) == TimelineFollowTarget(bar: 1, halfBeat: 1))
        #expect(model.followTarget(7680) == TimelineFollowTarget(bar: 1, halfBeat: 8))
        #expect(model.followTarget(7681) == nil)
    }
    @Test func longExercisePagesAndFinalPartialBarStayBounded() throws {
        let model = try TimelineModel(exercise: Exercise(id: "large", events: [note("long", 0, Int64.max)]), instrument: .standard)
        #expect(model.page(containing: 0) == 0..<16)
        #expect(model.page(containing: 16) == 16..<32)
        let last = model.barCount - 1
        #expect(model.page(containing: last).count <= 16)
        #expect(model.page(containing: Int64.max).upperBound == model.barCount)
        let end = try #require(model.segments(in: last).last)
        #expect(end.endTick == Int64.max)
        #expect(end.isContinuation)
        #expect(model.x(tick: Int64.max, bar: last, zoom: 1) > 0)
        #expect(model.segments(in: -1).isEmpty)
        #expect(model.segments(in: model.barCount).isEmpty)
    }
    @Test func hitTestingAfterScrollAndZoomReturnsStableIDs() throws {
        let events = try (0..<100).map { try note("n\($0)", Int64($0) * 240, 240, fret: $0 % 25) }
        let model = try TimelineModel(exercise: Exercise(id: "scale", events: events), instrument: .standard)
        for zoom in [1.0, 2.0] {
            let bar: Int64 = 3
            let scrollOffset = model.barWidth(zoom: zoom) * 3 + 100
            let worldEventX = model.barWidth(zoom: zoom) * 3 + 150
            let screenX = worldEventX - scrollOffset
            let localX = screenX + scrollOffset - model.barWidth(zoom: zoom) * 3
            #expect(model.eventID(atX: localX, bar: bar, zoom: zoom) == (zoom == 1 ? "n51" : "n49"))
        }
    }
    @Test func chordEventsKeepEveryStringAtOneStartTick() throws {
        let shape = try (1...6).map { try FretPosition(string: $0, fret: [4, 5].contains($0) ? 2 : 0) }
        let chord = try MusicalEvent(id: "em", startTick: 0, durationTicks: 960, kind: .note, positions: shape)
        let model = try TimelineModel(exercise: Exercise(id: "chord", events: [chord], assessmentMode: .displayOnly), instrument: .standard)
        let segment = try #require(model.segments(in: 0).first)
        #expect(segment.resolved.event.positions == shape)
        #expect(segment.resolved.pitches.map(\.midi) == [64, 59, 55, 52, 47, 40])
        #expect(model.eventID(atX: 100, bar: 0, zoom: 1) == "em")
    }
    @Test func rangeSelectionKeepsStableAnchorAcrossDirectionChanges() throws {
        let events = try (0..<5).map { try note("n\($0)", Int64($0) * 960, 960) }
        var selection = TimelineSelection()
        selection.select("n2", extending: false, events: events)
        selection.select("n4", extending: true, events: events)
        #expect(selection.ids == ["n2", "n3", "n4"])
        selection.select("n0", extending: true, events: events)
        #expect(selection.ids == ["n0", "n1", "n2"])
        selection.select("unknown", extending: false, events: events)
        #expect(selection.anchorID == "n2")
        selection.clear()
        #expect(selection.ids.isEmpty && selection.anchorID == nil)
        selection.select("n4", extending: true, events: events)
        #expect(selection.ids == ["n4"])
    }
}
