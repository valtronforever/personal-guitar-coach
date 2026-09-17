import Foundation
import Testing
import Domain
@testable import PersonalGuitarCoach

struct LegatoChainNotationTests {
    @Test func everyReachedPitchHasItsOwnTimeAndOnlyTheInitialNoteIsPicked() throws {
        let chain = try LegatoChain(targets: [.init(kind: .hammerOn, semitones: 3, startTick: 960),
            .init(kind: .tap, semitones: 4, startTick: 1920), .init(kind: .pullOff, semitones: -4, startTick: 2880),
            .init(kind: .pullOff, semitones: -3, startTick: 3840)])
        let event = try MusicalEvent(id: "phrase", startTick: 0, durationTicks: 5760, kind: .note,
            positions: [FretPosition(string: 3, fret: 5)], accented: true, pickStroke: .down, legatoChain: chain)
        let timeline = try TimelineModel(exercise: Exercise(id: "phrase", events: [event]), instrument: .standard)
        let staff = StaffModel(timeline: timeline, key: .neutral)
        let symbols = try (0..<timeline.barCount).flatMap { try staff.symbols(in: $0) }
        #expect(symbols.map(\.startTick) == [0, 960, 1920, 2880, 3840])
        #expect(symbols.map(\.pitch?.soundingMIDI) == [60, 63, 67, 63, 60])
        #expect(symbols.map(\.accentedAttack) == [true, false, false, false, false])
        #expect(symbols.map(\.fragment.isTechniqueTarget) == [false, true, true, true, true])
        #expect(symbols.allSatisfy { !$0.fragment.tieFromPrevious && !$0.fragment.tieToNext && $0.eventID == "phrase" })
        let segments = (0..<timeline.barCount).flatMap { timeline.segments(in: $0) }
        let markers = segments.flatMap(PitchTransitionPresentation.markers)
        #expect(markers.map(\.tick) == [0, 960, 1920, 2880, 3840])
        #expect(markers.map(\.position.fret) == [5, 8, 12, 8, 5])
        #expect(markers.map(\.durationTicks) == [960, 960, 960, 960, 1920])
        #expect(segments[1].displayPitches.map(\.midi) == [60] && segments[1].displayPositions.map(\.fret) == [5])
        #expect(PitchTransitionPresentation.links(event).map(\.mark) == ["h", "t", "p", "p"])
        #expect(timeline.events.count == 1)
    }
    @Test func continuationTiesStayWithinOnePlateauAndUnsupportedGridsAreExplicit() throws {
        let chain = try LegatoChain(targets: [.init(kind: .hammerOn, semitones: 2, startTick: 1920), .init(kind: .pullOff, semitones: -2, startTick: 4800)])
        let event = try MusicalEvent(id: "phrase", startTick: 0, durationTicks: 5760, kind: .note,
            positions: [FretPosition(string: 3, fret: 5)], legatoChain: chain)
        let timeline = try TimelineModel(exercise: Exercise(id: "phrase", events: [event]), instrument: .standard)
        let staff = StaffModel(timeline: timeline, key: .neutral)
        let first = try staff.symbols(in: 0), second = try staff.symbols(in: 1)
        #expect(first.last?.fragment.tieToNext == true && second.first?.fragment.tieFromPrevious == true)
        #expect(second.first?.pitch?.soundingMIDI == 62 && second.last?.pitch?.soundingMIDI == 60)
        #expect(second.first?.fragment.tieToNext == false && second.last?.fragment.tieFromPrevious == false)
        let markers = PitchTransitionPresentation.markers(try #require(timeline.segments(in: 1).first))
        #expect(markers.map(\.continuation) == [true, false])
        let invalid = try MusicalEvent(id: "grid", startTick: 0, durationTicks: 1920, kind: .note,
            positions: [FretPosition(string: 3, fret: 5)], legatoChain: LegatoChain(targets: [.init(kind: .hammerOn, semitones: 2, startTick: 333)]))
        let grid = try TimelineModel(exercise: Exercise(id: "grid", events: [invalid]), instrument: .standard)
        #expect(throws: StaffLimitation.duration) { try StaffModel(timeline: grid, key: .neutral).symbols(in: 0) }
    }
}
