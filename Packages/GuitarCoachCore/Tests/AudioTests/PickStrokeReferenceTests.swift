import Foundation
import Testing
import Domain
@testable import Audio

struct PickStrokeReferenceTests {
    @Test func pickingCueDoesNotChangePitchTimingOrAudio() throws {
        let position = try FretPosition(string:3,fret:5)
        for rate in [44100.0,48000.0] {
            func plan(_ stroke: StrumDirection?) throws -> TransportPlan {
                let event=try MusicalEvent(id:"n",startTick:0,durationTicks:960,kind:.note,positions:[position],pickStroke:stroke)
                let exercise=try Exercise(id:"cue",events:[event])
                try exercise.validateForPractice(instrument:.standard,bpm:60)
                return try TransportPlan(request:TransportRequest(exercise:exercise,tuning:.standard,bpm:60,countInBars:0,clickEnabled:false),sampleRate:rate)
            }
            let plain=try plan(nil).render(startFrame:0,count:12000)
            #expect(try plan(.down).render(startFrame:0,count:12000) == plain)
            #expect(try plan(.up).render(startFrame:0,count:12000) == plain)
        }
    }
    @Test func pickCueRejectsAmbiguousAuthoringAndPreservesLegacyEncoding() throws {
        let p=try FretPosition(string:3,fret:5)
        let note=try MusicalEvent(id:"n",startTick:0,durationTicks:960,kind:.note,positions:[p],pickStroke:.up)
        #expect(note.pickingDirection == .up)
        #expect(try JSONDecoder().decode(MusicalEvent.self,from:JSONEncoder().encode(note)) == note)
        let old=try MusicalEvent(id:"n",startTick:0,durationTicks:960,kind:.note,positions:[p])
        #expect(!(String(data:try JSONEncoder().encode(old),encoding:.utf8) ?? "").contains("pickStroke"))
        #expect(throws:MusicError.invalidEvent) { try MusicalEvent(id:"r",startTick:0,durationTicks:960,kind:.rest,pickStroke:.down) }
        let chord=try [p,FretPosition(string:2,fret:5)]
        #expect(throws:MusicError.invalidEvent) { try MusicalEvent(id:"c",startTick:0,durationTicks:960,kind:.note,positions:chord,pickStroke:.down) }
        #expect(throws:MusicError.invalidEvent) { try MusicalEvent(id:"c",startTick:0,durationTicks:960,kind:.note,positions:chord,strum:StrumPattern(direction:.up),pickStroke:.down) }
        let strum=try MusicalEvent(id:"c",startTick:0,durationTicks:960,kind:.note,positions:chord,strum:StrumPattern(direction:.up))
        #expect(strum.pickingDirection == .up && strum.pickStroke == nil)
    }
}
