import Foundation
import Domain

/// UI projection of canonical positions. Orientation changes only their display order.
struct FretboardModel: Sendable {
    let tuning: TuningProfile
    let orientation: FretboardOrientation
    let expected: Set<FretPosition>
    let mutedStrings: Set<Int>
    let fingers: [Int: Int]

    init(tuning: TuningProfile, orientation: FretboardOrientation = .rightHanded,
         positions: [FretPosition] = [], mutedStrings: [Int] = [], fingers: [Int: Int] = [:]) {
        self.tuning = tuning; self.orientation = orientation
        expected = Set(positions); self.mutedStrings = Set(mutedStrings); self.fingers = fingers
    }

    init(tuning: TuningProfile, orientation: FretboardOrientation = .rightHanded, fingering: Fingering) {
        self.init(tuning: tuning, orientation: orientation, positions: fingering.positions,
                  mutedStrings: fingering.mutedStrings, fingers: fingering.fingerNumbers)
    }

    var frets: [Int] { orientation == .rightHanded ? Array(0...24) : Array((0...24).reversed()) }
    func positions(fret: Int) -> [FretPosition] { (1...6).compactMap { try? FretPosition(string: $0, fret: fret) } }
    func pitch(at position: FretPosition) -> Pitch? { try? tuning.pitch(at: position) }
    func isMuted(_ position: FretPosition) -> Bool { position.fret == 0 && mutedStrings.contains(position.string) }
    func finger(at position: FretPosition) -> Int? { expected.contains(position) && position.fret > 0 ? fingers[position.string] : nil }

    /// Arrow keys follow physical screen direction; vertical keys preserve the fret.
    func neighbor(of position: FretPosition, horizontal: Int = 0, vertical: Int = 0) -> FretPosition {
        let direction = orientation == .rightHanded ? 1 : -1
        return (try? FretPosition(string: min(6, max(1, position.string + vertical)),
                                 fret: min(24, max(0, position.fret + horizontal * direction)))) ?? position
    }
}
