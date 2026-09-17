import Foundation
import Testing
@testable import Domain

struct MutedStringAttackTests {
    @Test func unpitchedAttackHasStringsButNoFretOrPitchAndCannotBeGraded() throws {
        let attack = try MutedStringAttack(strings: [1,2,3], direction: .up)
        let event = try MusicalEvent(id: "scratch", startTick: 0, durationTicks: 480, kind: .note, accented: true, mutedAttack: attack)
        #expect(event.positions.isEmpty && event.techniquePositions.isEmpty && event.pickingDirection == .up)
        for tuning in TuningProfile.presets {
            #expect(try event.soundingPitches(in: tuning).isEmpty)
            #expect(try event.soundingFrequencies(in: tuning).isEmpty)
            #expect(try event.visualTargets(in: tuning).isEmpty)
            let exercise = try Exercise(id: "unpitched", events: [event], assessmentMode: .displayOnly)
            #expect(exercise.noteCount == 1 && exercise.durationTicks == 480)
            #expect(try exercise.resolvedEvents(instrument: tuning)[0].pitches.isEmpty)
            #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm: 60) }
        }
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "grade", events: [event]) }
        let ordinary = try MusicalEvent(id: "ordinary", startTick: 480, durationTicks: 480, kind: .note, positions: [FretPosition(string: 3, fret: 5)])
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "mixed", events: [event,ordinary]) }
        let encoded = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: encoded) == event)
        let old = try JSONEncoder().encode(ordinary)
        #expect(!String(decoding: old, as: UTF8.self).contains("mutedAttack"))
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: old) == ordinary)
    }
    @Test func malformedOrAmbiguousMutedEventsFailInsteadOfInventingATarget() throws {
        for strings in [[],[0],[7],[1,1],[3,1],Array(1...7)] {
            #expect(throws: MusicError.invalidEvent) { try MutedStringAttack(strings: strings) }
        }
        let attack = try MutedStringAttack(strings: [2,3])
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "rest", startTick: 0, durationTicks: 480, kind: .rest, mutedAttack: attack) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "pitch", startTick: 0, durationTicks: 480, kind: .note, positions: [FretPosition(string: 3, fret: 5)], mutedAttack: attack) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "sustain", startTick: 0, durationTicks: 480, kind: .note, assessSustain: true, mutedAttack: attack) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "palm", startTick: 0, durationTicks: 480, kind: .note, palmMuted: true, mutedAttack: attack) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "pick", startTick: 0, durationTicks: 480, kind: .note, pickStroke: .down, mutedAttack: attack) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "harmonic", startTick: 0, durationTicks: 480, kind: .note, harmonic: HarmonicNote(kind: .natural), mutedAttack: attack) }
        let bad = Data(#"{"strings":[2,2],"direction":"down"}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(MutedStringAttack.self, from: bad) }
    }
}
