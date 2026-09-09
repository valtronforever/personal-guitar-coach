import Testing
import Domain
@testable import PersonalGuitarCoach

struct FretboardTests {
    @Test func emDisplaysOpenStringsAndSuggestedFingersTogether() throws {
        let shape = try Fingering(positions: (1...6).map { try FretPosition(string: $0, fret: [4, 5].contains($0) ? 2 : 0) }, fingerNumbers: [4: 3, 5: 2])
        let board = FretboardModel(tuning: .standard, fingering: shape)
        #expect(board.expected.count == 6)
        #expect(try board.pitch(at: FretPosition(string: 6, fret: 0))?.midi == 40)
        #expect(try board.pitch(at: FretPosition(string: 5, fret: 2))?.midi == 47)
        #expect(try board.finger(at: FretPosition(string: 4, fret: 2)) == 3)
        #expect(try board.finger(at: FretPosition(string: 4, fret: 3)) == nil)
        #expect(try board.finger(at: FretPosition(string: 1, fret: 0)) == nil)
    }

    @Test func mirroringMovesCoordinatesWithoutChangingPitchOrStringNumber() throws {
        let right = FretboardModel(tuning: .standard)
        let left = FretboardModel(tuning: .standard, orientation: .leftHanded)
        #expect(left.frets == right.frets.reversed())
        for fret in 0...24 {
            #expect(left.positions(fret: fret).map(\.string) == Array(1...6))
            for position in right.positions(fret: fret) { #expect(left.pitch(at: position) == right.pitch(at: position)) }
        }
        let middle = try FretPosition(string: 3, fret: 12)
        #expect(right.neighbor(of: middle, horizontal: 1).fret == 13)
        #expect(left.neighbor(of: middle, horizontal: 1).fret == 11)
        #expect(left.neighbor(of: middle, vertical: 1).string == 4)
        #expect(try right.neighbor(of: FretPosition(string: 1, fret: 24), horizontal: 1, vertical: -1) == FretPosition(string: 1, fret: 24))
    }

    @Test func tuningUpdateResolvesEveryFretWhileKeepingExpectedPositions() throws {
        let fragment = try [0, 2, 4, 5].map { try FretPosition(string: 6, fret: $0) }
        let standard = FretboardModel(tuning: .standard, positions: fragment)
        let drop = FretboardModel(tuning: .dropD, positions: fragment)
        #expect(drop.expected == standard.expected)
        for fret in 0...24 {
            for position in standard.positions(fret: fret) {
                #expect(drop.pitch(at: position)?.midi == standard.pitch(at: position)!.midi - (position.string == 6 ? 2 : 0))
            }
        }
        #expect(try drop.pitch(at: FretPosition(string: 1, fret: 24))?.name() == "E6")
    }

    @Test func mutedAndEmptySelectionDoNotInventSoundingMarkers() throws {
        let shape = try Fingering(positions: [FretPosition(string: 1, fret: 0)], mutedStrings: [6])
        let board = FretboardModel(tuning: .standard, fingering: shape)
        let muted = try FretPosition(string: 6, fret: 0)
        #expect(board.isMuted(muted))
        #expect(!board.expected.contains(muted))
        #expect(try !board.isMuted(FretPosition(string: 6, fret: 1)))
        let empty = FretboardModel(tuning: .standard)
        #expect(empty.expected.isEmpty)
        #expect(empty.mutedStrings.isEmpty)
    }
}
