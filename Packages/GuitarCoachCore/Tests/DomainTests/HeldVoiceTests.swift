import Foundation
import Testing
@testable import Domain

struct HeldVoiceTests {
    @Test func explicitTiesMergeOnlyTheHeldStringAndPreserveSerialization() throws {
        let bass = try FretPosition(string: 5, fret: 3), e = try FretPosition(string: 2, fret: 5), f = try FretPosition(string: 2, fret: 6)
        let a = try MusicalEvent(id: "a", startTick: 0, durationTicks: 960, kind: .note, positions: [bass,e], accented: true)
        let b = try MusicalEvent(id: "b", startTick: 960, durationTicks: 960, kind: .note, positions: [bass,f], heldStrings: [5])
        let c = try MusicalEvent(id: "c", startTick: 1920, durationTicks: 960, kind: .note, positions: [bass], heldStrings: [5])
        let d = try MusicalEvent(id: "d", startTick: 2880, durationTicks: 960, kind: .note, positions: [bass])
        let exercise = try Exercise(id: "voices", events: [a,b,c,d], assessmentMode: .displayOnly)
        #expect(b.attackedPositions == [f] && c.attackedPositions.isEmpty && d.attackedPositions == [bass])
        let spans = exercise.referenceVoiceSpans
        #expect(spans.map(\.startTick) == [0,0,960,2880])
        #expect(spans.map(\.endTick) == [2880,960,1920,3840])
        #expect(spans.map(\.eventID) == ["a","a","b","d"])
        #expect(spans.map(\.accented) == [true,true,false,false])
        let encoder = JSONEncoder()
        #expect(try JSONDecoder().decode(Exercise.self, from: encoder.encode(exercise)) == exercise)
        #expect(!String(decoding: try encoder.encode(a), as: UTF8.self).contains("heldStrings"))
        #expect(throws: MusicError.unsupportedPolyphony) { try Exercise(id: "grade", events: [a,b]) }
        #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: .standard, bpm: 60) }
    }

    @Test func brokenAmbiguousOrUnsupportedHoldsAreRejected() throws {
        let p = try FretPosition(string: 5, fret: 3), other = try FretPosition(string: 5, fret: 4)
        func event(_ id: String, _ tick: Int64, _ position: FretPosition, _ held: [Int] = []) throws -> MusicalEvent {
            try MusicalEvent(id: id, startTick: tick, durationTicks: 960, kind: .note, positions: [position], heldStrings: held)
        }
        let initial = try event("a",0,p), held = try event("b",960,p,[5])
        for bad in [[5,5],[6],[0],[7]] {
            #expect(throws: MusicError.invalidEvent) { try event("bad",960,p,bad) }
        }
        for events in [[held], [initial,try event("gap",1920,p,[5])], [initial,try event("changed",960,other,[5])],
                       [try MusicalEvent(id: "rest",startTick: 0,durationTicks: 960,kind: .rest),held]] {
            #expect(throws: MusicError.invalidExercise) { try Exercise(id: "invalid",events: events,assessmentMode: .displayOnly) }
        }
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "mono",events: [initial,held]) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "accent",startTick: 960,durationTicks: 960,kind: .note,positions: [p],accented: true,heldStrings: [5]) }
        let muted = try MusicalEvent(id: "muted",startTick: 1920,durationTicks: 960,kind: .note,positions: [p],palmMuted: true)
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "mix",events: [initial,held,muted],assessmentMode: .displayOnly) }
        let json = #"{"id":"bad","startTick":0,"durationTicks":960,"kind":"note","positions":[{"string":5,"fret":3}],"heldStrings":[5,5]}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(MusicalEvent.self,from: Data(json.utf8)) }
    }
}
