import Foundation
import Testing
@testable import Domain

struct MetronomePatternTests {
    @Test func omissionsValidateScopeAndPreserveHistoricalEncoding() throws {
        for ticks: [Int64] in [[], [-960], [240], [960,0], [0,0]] {
            #expect(throws: MusicError.invalidTime) { try MetronomePattern(silentBeatTicks: ticks) }
        }
        #expect(throws: MusicError.invalidTime) {
            try JSONDecoder().decode(MetronomePattern.self, from: Data(#"{"silentBeatTicks":[1]}"#.utf8))
        }
        let pattern = try MetronomePattern(silentBeatTicks: [0,1920,3840,4800,5760,6720])
        #expect(try pattern.scoped(to: 3840..<7680)?.silentBeatTicks == [0,960,1920,2880])
        #expect(try pattern.scoped(to: 960..<1920) == nil)
        #expect(throws: MusicError.invalidTime) { try pattern.scoped(to: 480..<3840) }
        let events = try (0..<8).map { i in
            try MusicalEvent(id: "n\(i)", startTick: Int64(i*960), durationTicks: 960, kind: .note, positions: [FretPosition(string:3,fret:5)])
        }
        let old = try Exercise(id: "clock", events: events)
        let adapted = try Exercise(id: "clock", events: events, metronome: pattern)
        #expect(old.events == adapted.events && old.durationTicks == adapted.durationTicks)
        let encoder = JSONEncoder()
        let json = try #require(JSONSerialization.jsonObject(with: encoder.encode(old)) as? [String:Any])
        #expect(json["metronome"] == nil)
        #expect(try JSONDecoder().decode(Exercise.self, from: encoder.encode(old)) == old)
        #expect(try JSONDecoder().decode(Exercise.self, from: encoder.encode(adapted)) == adapted)
        #expect(throws: MusicError.invalidTime) {
            try Exercise(id: "outside", events: events, metronome: MetronomePattern(silentBeatTicks: [7680]))
        }
    }
}
