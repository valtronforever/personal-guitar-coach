import Foundation
import Domain

/// A generation token keeps canceled output completions from preparing a different attempt.
/// Revealing is sticky for this selection, including tempo/range changes and replays.
struct ListeningPreparation {
    private(set) var playbackID: UUID?
    private(set) var referenceCompleted = false
    private(set) var targetsRevealed = false
    var conditions: PracticeListeningConditions? {
        try? PracticeListeningConditions(referencePlaybackCompleted: referenceCompleted, targetsRevealed: targetsRevealed)
    }
    mutating func begin(_ id: UUID) { playbackID = id; referenceCompleted = false }
    @discardableResult mutating func complete(_ id: UUID) -> Bool {
        guard playbackID == id else { return false }
        playbackID = nil; referenceCompleted = true; return true
    }
    mutating func invalidate() { playbackID = nil; referenceCompleted = false }
    mutating func reveal() { targetsRevealed = true }
}
