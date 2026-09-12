import Foundation
import Domain

/// UI projection of canonical positions. Orientation changes only their display order.
struct FretboardModel: Sendable {
    let tuning: TuningProfile
    let fretsCount: GuitarFretCount
    var maximumFret: Int { fretsCount.rawValue }
    let orientation: FretboardOrientation
    let expected: Set<FretPosition>
    let mutedStrings: Set<Int>
    let fingers: [Int: Int]

    init(tuning: TuningProfile, orientation: FretboardOrientation = .rightHanded, frets: GuitarFretCount = .twentyFour,
         positions: [FretPosition] = [], mutedStrings: [Int] = [], fingers: [Int: Int] = [:]) {
        self.tuning = tuning; self.orientation = orientation; self.fretsCount = frets
        expected = Set(positions.filter { $0.fret <= frets.rawValue }); self.mutedStrings = Set(mutedStrings); self.fingers = fingers
    }

    init(tuning: TuningProfile, orientation: FretboardOrientation = .rightHanded, frets: GuitarFretCount = .twentyFour, fingering: Fingering) {
        self.init(tuning: tuning, orientation: orientation, frets: frets, positions: fingering.positions,
                  mutedStrings: fingering.mutedStrings, fingers: fingering.fingerNumbers)
    }

    var frets: [Int] { orientation == .rightHanded ? Array(0...maximumFret) : Array((0...maximumFret).reversed()) }
    func positions(fret: Int) -> [FretPosition] { guard (0...maximumFret).contains(fret) else { return [] }; return (1...6).compactMap { try? FretPosition(string: $0, fret: fret) } }
    func pitch(at position: FretPosition) -> Pitch? { guard position.fret <= maximumFret else { return nil }; return try? tuning.pitch(at: position) }
    func isMuted(_ position: FretPosition) -> Bool { position.fret == 0 && mutedStrings.contains(position.string) }
    func finger(at position: FretPosition) -> Int? { expected.contains(position) && position.fret > 0 ? fingers[position.string] : nil }

    /// Arrow keys follow physical screen direction; vertical keys preserve the fret.
    func neighbor(of position: FretPosition, horizontal: Int = 0, vertical: Int = 0) -> FretPosition {
        let direction = orientation == .rightHanded ? 1 : -1
        return (try? FretPosition(string: min(6, max(1, position.string + vertical)),
                                 fret: min(maximumFret, max(0, position.fret + horizontal * direction)))) ?? position
    }
}
