import Foundation
import Testing
@testable import Domain

struct HarmonicNoteTests {
    @Test func nodesUseOpenStringPartialsRatherThanStoppedFretPitches() throws {
        for (partial,fret,offset) in [(2,12,12),(3,7,19),(4,5,24)] {
            let harmonic = try HarmonicNote(kind: .natural, partial: partial)
            for tuning in TuningProfile.presets {
                for string in 1...6 {
                    let position = try FretPosition(string: string, fret: fret)
                    let event = try MusicalEvent(id: "harmonic", startTick: 0, durationTicks: 960, kind: .note, positions: [position], harmonic: harmonic)
                    let open = tuning.strings[string - 1].openPitch.midi
                    #expect(try event.soundingPitches(in: tuning).map(\.midi) == [open + offset])
                    let exact = 440 * pow(2, Double(open - 69) / 12) * Double(partial)
                    #expect(try abs(event.soundingFrequencies(in: tuning)[0] - exact) < 1e-10)
                    #expect(event.techniquePositions == [position])
                    let targets = try event.visualTargets(in: tuning)
                    #expect(targets.count == 1 && targets[0].role == .harmonicTouch && targets[0].pitch.midi == open + offset)
                    #expect(try JSONDecoder().decode(MusicalEvent.self, from: JSONEncoder().encode(event)) == event)
                }
            }
        }
        let natural = try HarmonicNote(kind: .natural, partial: 3)
        let event = try MusicalEvent(id: "third", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 7)], harmonic: natural)
        let exact = try event.soundingFrequencies(in: .standard)[0]
        let label = try event.soundingPitches(in: .standard)[0].frequency()
        #expect(abs(1200 * log2(exact / label) - 1.9550008653874) < 1e-8)
        #expect(try event.soundingPitches(in: .standard)[0].midi == 74)
    }

    @Test func artificialOctaveKeepsStoppedAndTouchedPositionsDistinct() throws {
        let harmonic = try HarmonicNote(kind: .artificial)
        let event = try MusicalEvent(id: "artificial", startTick: 0, durationTicks: 1920, kind: .note, positions: [FretPosition(string: 3, fret: 5)], harmonic: harmonic)
        #expect(event.techniquePositions.map(\.fret) == [5,17])
        #expect(try event.soundingPitches(in: .standard).map(\.midi) == [72])
        #expect(try event.soundingPitches(in: .cStandard).map(\.midi) == [68])
        let targets = try event.visualTargets(in: .cStandard)
        #expect(targets.map(\.role) == [.harmonicBase,.harmonicTouch])
        #expect(targets.map(\.pitch.midi) == [56,68])
        let region = try FretRegion(firstFret: 5, windowFrets: 13)
        #expect(event.techniquePositions.allSatisfy { region.contains($0, maximumFret: 19) })
        #expect(throws: (any Error).self) { try FretRegion(firstFret: 5, windowFrets: 14) }
        let high = try MusicalEvent(id: "high", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 12)], harmonic: harmonic)
        #expect(high.techniquePositions.last?.fret == 24)
        #expect(!high.techniquePositions.allSatisfy(InstrumentProfile(frets: .nineteen).contains))
    }

    @Test func malformedAndContradictoryHarmonicsFailWhileOrdinaryEncodingStaysUnchanged() throws {
        for partial in [Int.min,0,1,5,Int.max] { #expect(throws: (any Error).self) { try HarmonicNote(kind: .natural, partial: partial) } }
        #expect(throws: (any Error).self) { try HarmonicNote(kind: .artificial, partial: 3) }
        let harmonic = try HarmonicNote(kind: .natural, partial: 3)
        #expect(throws: (any Error).self) { try MusicalEvent(id: "wrong-node", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 5)], harmonic: harmonic) }
        #expect(throws: (any Error).self) { try MusicalEvent(id: "rest", startTick: 0, durationTicks: 960, kind: .rest, harmonic: harmonic) }
        #expect(throws: (any Error).self) { try MusicalEvent(id: "chord", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 7),FretPosition(string: 2, fret: 7)], harmonic: harmonic) }
        #expect(throws: (any Error).self) { try MusicalEvent(id: "muted", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 7)], palmMuted: true, harmonic: harmonic) }
        #expect(throws: (any Error).self) { try MusicalEvent(id: "finger", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 7)], pluckFinger: .index, harmonic: harmonic) }
        let artificial = try HarmonicNote(kind: .artificial)
        for fret in [0,13,24] { #expect(throws: (any Error).self) { try artificial.validate(position: FretPosition(string: 3, fret: fret)) } }
        let ordinary = try MusicalEvent(id: "ordinary", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 7)])
        let encoded = try JSONEncoder().encode(ordinary)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("harmonic"))
        #expect(try ordinary.soundingPitches(in: .standard).map(\.midi) == [62])
        #expect(try ordinary.soundingFrequencies(in: .standard)[0] == Pitch(midi: 62).frequency())
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: encoded) == ordinary)
    }
}
