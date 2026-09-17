import Foundation
import Testing
@testable import Domain

struct MeterPulseTests {
    @Test func meterHasExplicitPulseGroupingAndIndependentMusicalTime() throws {
        let meters: [(TimeSignature,Int,Int,Int64,Int,Int64,[Int])] = [
            (.threeFour,3,4,960,3,2880,[1,1,1]), (.fourFour,4,4,960,4,3840,[1,1,1,1]),
            (.sixEight,6,8,1440,2,2880,[1,1]), (.twelveEight,12,8,1440,4,5760,[1,1,1,1]),
            (.fiveFour,5,4,960,5,4800,[3,2]), (.sevenEight,7,8,480,7,3360,[2,2,3])]
        for (meter,numerator,denominator,pulse,count,bar,groups) in meters {
            #expect(meter.numerator == numerator && meter.denominator == denominator)
            #expect(meter.pulseTicks == pulse && meter.beatsPerBar == count && meter.ticksPerBar == bar)
            #expect(meter.defaultGrouping == groups)
            #expect(try MusicalTime.seconds(forTicks:bar,bpm:60,pulseTicks:pulse) == Double(count))
            #expect(try MusicalTime.ticks(forSeconds:Double(count),bpm:60,pulseTicks:pulse) == bar)
            #expect(try JSONDecoder().decode(TimeSignature.self,from:JSONEncoder().encode(meter)) == meter)
        }
        #expect(abs(try MusicalTime.seconds(forTicks:480,bpm:60,pulseTicks:1440) - 1.0/3) < 1e-12)
        #expect(try MusicalTime.seconds(forTicks:480,bpm:60) == 0.5)
        #expect(try MusicalTime.seconds(forTicks:480,bpm:60,pulseTicks:480) == 1)
        let event = try MusicalEvent(id:"held",startTick:0,durationTicks:4800,kind:.note,positions:[FretPosition(string:3,fret:5)])
        let odd = try Exercise(id:"odd",events:[event],timeSignature:.fiveFour)
        let shifted = try Exercise(id:"odd",events:[event],timeSignature:.fiveFour,beatGrouping:[2,3])
        #expect(odd.accentedPulseIndices == [0,3] && shifted.accentedPulseIndices == [0,2])
        #expect(try JSONDecoder().decode(Exercise.self,from:JSONEncoder().encode(shifted)) == shifted)
        let json = try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(odd)) as? [String:Any])
        #expect(json["beatGrouping"] == nil)
        for bad in [[],[0,5],[3,3],[Int.max]] {
            #expect(throws: MusicError.invalidTime) { try Exercise(id:"bad",events:[event],timeSignature:.fiveFour,beatGrouping:bad) }
        }
        let partial = try MusicalEvent(id:"bar",startTick:0,durationTicks:2880,kind:.note,positions:[FretPosition(string:3,fret:5)])
        #expect(throws: MusicError.invalidTime) {
            try Exercise(id:"wrong-grid",events:[partial],timeSignature:.sixEight,metronome:MetronomePattern(silentBeatTicks:[960]))
        }
        let shortNote = try MusicalEvent(id:"short",startTick:0,durationTicks:240,kind:.note,positions:[FretPosition(string:3,fret:5)])
        let shortSimple = try Exercise(id:"simple",events:[shortNote])
        let shortCompound = try Exercise(id:"compound",events:[shortNote],timeSignature:.sixEight)
        #expect(try MonophonicCapability.limitations(exercise:shortSimple,instrument:.standard,bpm:60).isEmpty)
        #expect(try MonophonicCapability.limitations(exercise:shortCompound,instrument:.standard,bpm:60).first?.reason == .duration)
        let bend = try PitchBend(semitones:2,riseStartTick:480,riseEndTick:960)
        #expect(BendCapability.supports(bend:bend,durationTicks:1440,bpm:60,frequency:261.625))
        #expect(!BendCapability.supports(bend:bend,durationTicks:1440,bpm:60,frequency:261.625,pulseTicks:1440))
        let compound = try Exercise(id:"compound",events:[partial],timeSignature:.sixEight,metronome:MetronomePattern(silentBeatTicks:[1440]))
        #expect(compound.metronome?.silentBeatTicks == [1440])
        #expect(throws: MusicError.invalidTime) {
            try Exercise(id:"quarter-grid",events:[partial],metronome:MetronomePattern(silentBeatTicks:[480]))
        }
    }
}
