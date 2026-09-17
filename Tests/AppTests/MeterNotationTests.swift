import Domain
import Testing
@testable import PersonalGuitarCoach

struct MeterNotationTests {
    @Test func eighthBeamsRespectCompoundPulsesAndAuthoredOddGroups() throws {
        let cases: [(TimeSignature,[Int]?,[[Int]])] = [
            (.sixEight,nil,[[0,1,2],[3,4,5]]), (.twelveEight,nil,[[0,1,2],[3,4,5],[6,7,8],[9,10,11]]),
            (.fiveFour,nil,[[0,1],[2,3],[4,5],[6,7],[8,9]]),
            (.sevenEight,nil,[[0,1],[2,3],[4,5,6]]), (.sevenEight,[3,2,2],[[0,1,2],[3,4],[5,6]])]
        for (meter,grouping,expected) in cases {
            let count = Int(meter.ticksPerBar/480)
            let events = try (0..<count).map { i in
                try MusicalEvent(id:"n\(i)",startTick:Int64(i*480),durationTicks:480,kind:.note,positions:[FretPosition(string:3,fret:5)])
            }
            let timeline = try TimelineModel(exercise:Exercise(id:"meter",events:events,timeSignature:meter,beatGrouping:grouping),instrument:.standard)
            let staff = StaffModel(timeline:timeline,key:.neutral), symbols = try staff.symbols(in:0)
            #expect(staff.beams(symbols).map { $0.ids.map(\.eventID) } == expected.map { $0.map { "n\($0)" } })
            #expect(symbols.map { $0.fragment.duration.ticks } == Array(repeating:480,count:count))
            for zoom in [0.8,1.0,1.5] {
                #expect(abs(timeline.x(tick:meter.ticksPerBar,bar:0,zoom:zoom)-timeline.barWidth(zoom:zoom))<1e-9)
                for pulse in 0..<meter.beatsPerBar {
                    let tick = Int64(pulse)*meter.pulseTicks
                    let x = timeline.x(tick:tick,bar:0,zoom:zoom)
                    #expect(timeline.tick(x:x,bar:0,zoom:zoom) == tick)
                }
            }
            let layout = PracticeScoreLayout(timeline:timeline,firstBar:1,width:600)
            #expect(layout.beatsPerBar == meter.beatsPerBar && layout.ticksPerBar == meter.ticksPerBar)
        }
    }
    @Test func offbeatCompoundHoldSplitsAtDottedPulseAndKeepsOneAttack() throws {
        let events = try [MusicalEvent(id:"r1",startTick:0,durationTicks:480,kind:.rest),
            MusicalEvent(id:"held",startTick:480,durationTicks:1920,kind:.note,positions:[FretPosition(string:3,fret:5)]),
            MusicalEvent(id:"r2",startTick:2400,durationTicks:480,kind:.rest)]
        let timeline = try TimelineModel(exercise:Exercise(id:"hold",events:events,timeSignature:.sixEight),instrument:.standard)
        let symbols = try StaffModel(timeline:timeline,key:.neutral).symbols(in:0)
        let held = symbols.filter { $0.eventID == "held" }
        #expect(held.map(\.startTick) == [480,1440])
        #expect(held.map { $0.fragment.duration.ticks } == [960,960])
        #expect(held.map { $0.fragment.tieFromPrevious } == [false,true])
        #expect(held.map { $0.fragment.tieToNext } == [true,false])
        #expect(timeline.exercise.noteCount == 1)
    }
}
