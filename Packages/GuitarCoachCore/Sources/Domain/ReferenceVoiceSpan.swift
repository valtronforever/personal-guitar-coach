import Foundation

/// A single reference attack and all its explicitly held continuations.
public struct ReferenceVoiceSpan: Hashable, Sendable {
    public let eventID: String
    public let position: FretPosition
    public let startTick: Int64
    public let endTick: Int64
    public let accented: Bool
}

extension Exercise {
    public var hasHeldVoices: Bool { events.contains { !$0.heldStrings.isEmpty } }

    /// Used only by the plain, display-only held-voice contract. Technique references
    /// retain their existing renderer. Construction runs outside the audio callback.
    public var referenceVoiceSpans: [ReferenceVoiceSpan] {
        guard hasHeldVoices else { return [] }
        var result: [ReferenceVoiceSpan] = [], preceding: [Int: Int] = [:]
        for event in events {
            var current: [Int: Int] = [:]
            for position in event.positions {
                if event.heldStrings.contains(position.string), let index = preceding[position.string] {
                    let old = result[index]
                    result[index] = ReferenceVoiceSpan(eventID: old.eventID, position: old.position,
                        startTick: old.startTick, endTick: event.endTick, accented: old.accented)
                    current[position.string] = index
                } else {
                    current[position.string] = result.count
                    result.append(ReferenceVoiceSpan(eventID: event.id, position: position, startTick: event.startTick,
                        endTick: event.endTick, accented: event.accented))
                }
            }
            preceding = current
        }
        return result
    }
}
