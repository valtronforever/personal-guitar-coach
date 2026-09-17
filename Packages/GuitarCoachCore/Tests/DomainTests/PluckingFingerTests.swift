import Foundation
import Testing
@testable import Domain

struct PluckingFingerTests {
    @Test func instructionCannotContradictPickRestChordOrMovingTechniqueAndOldEncodingStaysAbsent() throws {
        let position = try FretPosition(string: 2, fret: 5)
        for finger in PluckingFinger.allCases {
            let event = try MusicalEvent(id: "pluck", startTick: 0, durationTicks: 960, kind: .note, positions: [position], pluckFinger: finger)
            #expect(try JSONDecoder().decode(MusicalEvent.self, from: JSONEncoder().encode(event)) == event)
            #expect(event.pickingDirection == nil && event.pluckFinger == finger)
        }
        #expect(PluckingFinger.allCases.map(\.symbol) == ["p", "i", "m", "a"])
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "x", startTick: 0, durationTicks: 960, kind: .rest, pluckFinger: .middle) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "x", startTick: 0, durationTicks: 960, kind: .note, positions: [position], pickStroke: .down, pluckFinger: .middle) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "x", startTick: 0, durationTicks: 960, kind: .note, positions: [position, FretPosition(string: 1, fret: 5)], pluckFinger: .middle) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "x", startTick: 0, durationTicks: 1920, kind: .note, positions: [position], pitchTransition: PitchTransition(kind: .hammerOn, semitones: 2, startTick: 960), pluckFinger: .middle) }
        let ordinary = try MusicalEvent(id: "x", startTick: 0, durationTicks: 960, kind: .note, positions: [position])
        #expect(!String(decoding: try JSONEncoder().encode(ordinary), as: UTF8.self).contains("pluckFinger"))
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(PluckingFinger.self, from: Data("\"unknown\"".utf8)) }
    }
}
