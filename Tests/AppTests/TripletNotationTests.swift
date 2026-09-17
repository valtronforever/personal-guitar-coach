import Foundation
import Testing
import Domain
@testable import PersonalGuitarCoach

struct TripletNotationTests {
    static func exercise() throws -> Exercise {
        let durations: [Int64] = [320,320,320,640,320,320,320,320,480,480]
        var tick: Int64 = 0
        let events = try durations.enumerated().map { index, duration -> MusicalEvent in
            defer { tick += duration }
            let rest = index == 6
            return try MusicalEvent(id: "n\(index)", startTick: tick, durationTicks: duration, kind: rest ? .rest : .note,
                positions: rest ? [] : [FretPosition(string: 3, fret: 5)], accented: [0,3,5,8].contains(index))
        }
        let groups = try [TripletGroup(id:"a",eventIDs:["n0","n1","n2"]), TripletGroup(id:"b",eventIDs:["n3","n4"]), TripletGroup(id:"c",eventIDs:["n5","n6","n7"])]
        return try Exercise(id:"triplet-notation",events:events,triplets:groups)
    }
    @Test func writtenValuesAndGroupsPreserveActualTimeIncludingShuffleAndRest() throws {
        let exercise = try Self.exercise(), timeline = try TimelineModel(exercise:exercise,instrument:.standard)
        let model = StaffModel(timeline:timeline,key:.neutral), symbols = try model.symbols(in:0)
        #expect(symbols.map(\.startTick) == [0,320,640,960,1600,1920,2240,2560,2880,3360])
        #expect(symbols.map { $0.fragment.duration.baseTicks } == [480,480,480,960,480,480,480,480,480,480])
        #expect(symbols.map { $0.fragment.duration.ticks } == exercise.events.map(\.durationTicks))
        #expect(symbols.map { $0.fragment.tripletID } == ["a","a","a","b","b","c","c","c",nil,nil])
        #expect(symbols.allSatisfy { !$0.fragment.tieFromPrevious && !$0.fragment.tieToNext })
        #expect(model.beams(symbols).map { $0.ids.map(\.eventID) } == [["n0","n1","n2"],["n8","n9"]])
        #expect(symbols[6].pitch == nil && symbols[6].flags == 1)
        #expect(symbols[3].flags == 0 && symbols[3].hasStem && !symbols[3].hollow)
        #expect(timeline.triplets(in:0).map(\.startTick) == [0,960,1920])
        #expect(timeline.triplets(in:0).map(\.endTick) == [960,1920,2880])
        for segment in timeline.segments(in:0) {
            let x = timeline.x(tick:segment.startTick,bar:0,zoom:1) + 1
            #expect(timeline.eventID(atX:x,bar:0,zoom:1) == segment.id)
        }
        let layout = PracticeScoreLayout(timeline:timeline,firstBar:1,width:600)
        #expect(layout.contentRowHeight == 180)
        let plain = try TimelineModel(exercise:Exercise(id:"plain",events:exercise.events),instrument:.standard)
        #expect(PracticeScoreLayout(timeline:plain,firstBar:1,width:600).contentRowHeight == 164)
        // Explicit metadata, not a guess from unusual durations, controls conventional triplet notation.
        #expect(throws: StaffLimitation.duration) { try StaffModel(timeline:plain,key:.neutral).symbols(in:0) }
    }
    @Test func bracketTimeGeometryIsIndependentOfZoomCountInAndBarSelection() throws {
        let source = try Self.exercise()
        var events = source.events
        events += try source.events.map { try MusicalEvent(id:"second-"+$0.id,startTick:$0.startTick+3840,durationTicks:$0.durationTicks,kind:$0.kind,positions:$0.positions) }
        let groups = source.triplets + (try source.triplets.map { try TripletGroup(id:"second-"+$0.id,eventIDs:$0.eventIDs.map { "second-"+$0 }) })
        let timeline = try TimelineModel(exercise:Exercise(id:"two-bars",events:events,triplets:groups),instrument:.standard)
        for zoom in [0.8,1,1.5] {
            let layout = PracticeScoreLayout(timeline:timeline,firstBar:2,width:620,zoom:zoom)
            #expect(layout.bar(for:layout.countInSlot) == nil)
            #expect(timeline.triplets(in:1).map(\.startTick) == [3840,4800,5760])
            for group in timeline.triplets(in:1) {
                let width = layout.x(tick:Double(group.endTick),bar:1)-layout.x(tick:Double(group.startTick),bar:1)
                #expect(abs(width-layout.barWidth/4)<1e-8)
            }
        }
    }
}
