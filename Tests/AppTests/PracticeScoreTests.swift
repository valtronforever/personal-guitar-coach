import Testing
import Domain
@testable import PersonalGuitarCoach

struct PracticeScoreTests {
    private func timeline(signature: TimeSignature = .fourFour) throws -> TimelineModel {
        let events = try (0..<48).map { index in
            try MusicalEvent(id: "n\(index)", startTick: Int64(index) * 960, durationTicks: 960,
                kind: .note, positions: [FretPosition(string: 1, fret: index % 20)])
        }
        return try TimelineModel(exercise: Exercise(id: "reading", events: events, timeSignature: signature), instrument: .cStandard)
    }
    @Test func countInPrecedesSelectedRangeAndDoesNotChangeCanonicalBars() throws {
        let model = try timeline(), layout = PracticeScoreLayout(timeline: model, firstBar: 4, width: 620)
        #expect(layout.barsPerRow == 2)
        #expect(layout.countInSlot == 3 && layout.bar(for: 3) == nil)
        #expect(layout.bar(for: 2) == 2 && layout.bar(for: 4) == 3)
        #expect(layout.slot(for: 2) == 2 && layout.slot(for: 3) == 4)
        let start = try #require(layout.cursor(layout.startTick - 3840, endTick: model.exercise.durationTicks))
        let lastClick = try #require(layout.cursor(layout.startTick - 960, endTick: model.exercise.durationTicks))
        let playing = try #require(layout.cursor(layout.startTick, endTick: model.exercise.durationTicks))
        #expect(start.row == 1 && lastClick.row == 1 && lastClick.x > start.x)
        #expect(playing.row == 2 && playing.x == PracticeScoreLayout.gutter)
    }
    @Test func cursorIsContinuousAcrossAdjacentBarsAndWrapsOnlyAtRowBoundary() throws {
        let model = try timeline(), layout = PracticeScoreLayout(timeline: model, firstBar: 1, width: 900)
        #expect(layout.barsPerRow == 3)
        let before = try #require(layout.cursor(3839.5, endTick: 46080))
        let after = try #require(layout.cursor(3840.5, endTick: 46080))
        #expect(before.row == after.row && after.x > before.x && after.x - before.x < 1)
        let next = try #require(layout.cursor(7680, endTick: 46080))
        #expect(next.row == 1 && next.x == PracticeScoreLayout.gutter)
        #expect(layout.cursor(nil, endTick: 46080) == nil)
        #expect(layout.cursor(.nan, endTick: 46080) == nil)
    }
    @Test func zoomResizeAndFinalPartialBarsKeepEveryBarReachable() throws {
        let model = try timeline()
        for width in [480.0, 620, 900, 1400] { for zoom in [0.8, 1, 1.5] {
            let layout = PracticeScoreLayout(timeline: model, firstBar: 1, width: width, zoom: zoom)
            let slots = (0..<layout.rowCount).flatMap { Array(layout.slots(in: $0)) }
            #expect(slots == Array(0...model.barCount))
            #expect(slots.compactMap { layout.bar(for: $0) } == Array(0..<model.barCount))
            #expect(layout.barWidth * Double(layout.barsPerRow) + PracticeScoreLayout.gutter <= width + 0.001)
            let end = try #require(layout.cursor(7680, endTick: 7680))
            #expect(end.row == layout.slot(for: 1) / layout.barsPerRow)
            #expect(layout.cursor(7681, endTick: 7680) == nil)
            let partial = try #require(layout.cursor(4320, endTick: 4320))
            #expect(partial.row == layout.slot(for: 1) / layout.barsPerRow)
        } }
    }
    @Test func threeFourCountInAndSharedSoundingNotesRemainCorrect() throws {
        let model = try timeline(signature: .threeFour)
        let layout = PracticeScoreLayout(timeline: model, firstBar: 2, width: 620)
        #expect(layout.beatsPerBar == 3 && layout.ticksPerBar == 2880)
        #expect(layout.cursor(layout.startTick - 2880, endTick: model.exercise.durationTicks) != nil)
        #expect(layout.cursor(layout.startTick - 2881, endTick: model.exercise.durationTicks) == nil)
        #expect(model.events[0].pitches[0].midi == 60)
        #expect(model.segments(in: 1).map(\.id) == ["n3", "n4", "n5"])
    }
}
