import Foundation
import Testing
@testable import Domain

struct TripletGroupTests {
    private func exercise(durations: [Int64], groupIDs: [String]? = nil, start: Int64 = 0) throws -> Exercise {
        var tick = start
        let events = try durations.enumerated().map { index, duration -> MusicalEvent in
            defer { tick += duration }
            return try MusicalEvent(id: "e\(index)", startTick: tick, durationTicks: duration,
                kind: index == 1 ? .rest : .note, positions: index == 1 ? [] : [FretPosition(string: 3, fret: 5)])
        }
        return try Exercise(id: "triplet", events: events,
            triplets: [TripletGroup(id: "group", eventIDs: groupIDs ?? events.map(\.id))])
    }
    @Test func tripletsAndShuffleFreezeActualTimeAndPreserveOldCanonicalEncoding() throws {
        for durations: [Int64] in [[320,320,320],[640,320],[320,640]] {
            let value = try exercise(durations: durations)
            #expect(value.durationTicks == 960 && value.triplets.count == 1)
            #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(value)) == value)
            #expect(try MusicalTime.seconds(forTicks: value.durationTicks, bpm: 60) == 1)
            try value.validateForPractice(instrument: .standard, bpm: 90)
        }
        let grouped = try exercise(durations: [320,320,320])
        let old = try Exercise(id: "old", events: grouped.events)
        let data = try JSONEncoder().encode(old)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["triplets"] == nil)
        #expect(try JSONDecoder().decode(Exercise.self, from: data) == old)
        var oldJSON = json; oldJSON["triplets"] = []
        let explicit = try JSONDecoder().decode(Exercise.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        #expect(explicit == old)
    }
    @Test func incompleteReorderedOverlappingAndOffBeatGroupsAreRejected() throws {
        for durations: [Int64] in [[320,320],[480,480],[320,320,640],[960]] {
            #expect(throws: (any Error).self) { try exercise(durations: durations) }
        }
        #expect(throws: MusicError.invalidEvent) { try exercise(durations: [320,320,320], groupIDs: ["e0","missing","e2"]) }
        #expect(throws: MusicError.invalidTime) { try exercise(durations: [320,320,320], groupIDs: ["e1","e0","e2"]) }
        #expect(throws: MusicError.invalidTime) { try exercise(durations: [320,320,320], start: 320) }
        let source = try exercise(durations: [320,320,320])
        #expect(throws: MusicError.invalidEvent) {
            try Exercise(id: "overlap", events: source.events, triplets: source.triplets + [TripletGroup(id: "other", eventIDs: ["e0","e1","e2"])])
        }
        #expect(throws: MusicError.duplicateIdentifier) { try Exercise(id: "duplicate", events: source.events, triplets: source.triplets + source.triplets) }
        #expect(throws: MusicError.invalidEvent) { try JSONDecoder().decode(TripletGroup.self, from: Data(#"{"id":"group","eventIDs":["same","same"]}"#.utf8)) }
    }
}
