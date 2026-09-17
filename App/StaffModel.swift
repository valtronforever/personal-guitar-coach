import Foundation
import Domain

/// Presentation only: these settings never transpose the exercise, playback or assessment.
enum StaffKey: String, CaseIterable, Identifiable, Sendable {
    case neutral, gMajor, fMajor
    var id: String { rawValue }
    var titleKey: String { "staff.key.\(rawValue)" }
    func alteration(letter: Int) -> Int {
        if self == .gMajor && letter == 3 { return 1 } // F sharp
        if self == .fMajor && letter == 6 { return -1 } // B flat
        return 0
    }
}

struct StaffPitch: Equatable, Sendable {
    let soundingMIDI: Int
    let writtenMIDI: Int
    let letter: Int // C D E F G A B
    let alteration: Int
    let octave: Int
    var step: Int { octave * 7 + letter }
    var name: String { ["C", "D", "E", "F", "G", "A", "B"][letter] + (alteration == 1 ? "♯" : alteration == -1 ? "♭" : "") + String(octave) }
    init(sounding: Pitch, key: StaffKey, preferredSpelling: PitchSpelling = .sharps) {
        soundingMIDI = sounding.midi; writtenMIDI = sounding.midi + 12
        let sharp: [(Int, Int)] = [(0,0),(0,1),(1,0),(1,1),(2,0),(3,0),(3,1),(4,0),(4,1),(5,0),(5,1),(6,0)]
        let flat: [(Int, Int)] = [(0,0),(1,-1),(1,0),(2,-1),(2,0),(3,0),(4,-1),(4,0),(5,-1),(5,0),(6,-1),(6,0)]
        let spelling = ((key == .fMajor || (key == .neutral && preferredSpelling == .flats)) ? flat : sharp)[writtenMIDI % 12]
        letter = spelling.0; alteration = spelling.1; octave = writtenMIDI / 12 - 1
    }
}

struct StaffSymbol: Identifiable, Sendable {
    let resolved: ResolvedEvent
    let fragment: NotationFragment
    let pitch: StaffPitch?
    let accidental: String?
    var id: NotationFragmentID { fragment.id }
    var eventID: String { resolved.id }
    var accentedAttack: Bool { resolved.event.accented && !fragment.tieFromPrevious }
    var startTick: Int64 { fragment.startTick }
    var endTick: Int64 { fragment.endTick }
    var flags: Int { fragment.duration.flags }
    var hollow: Bool { fragment.duration.baseTicks >= 1920 }
    var hasStem: Bool { fragment.duration.baseTicks != 3840 && pitch != nil }
    var hintKey: String {
        if fragment.tieFromPrevious && fragment.tieToNext { return "staff.tie.middle" }
        if fragment.tieFromPrevious { return "staff.tie.end" }
        if fragment.tieToNext { return "staff.tie.start" }
        return "staff.selectHint"
    }
}
struct StaffBeam: Equatable, Sendable { let ids: [NotationFragmentID]; let flags: Int; let stemsUp: Bool }
enum StaffLimitation: String, Error { case range, polyphony, duration, gaps }

struct StaffModel: Sendable {
    let timeline: TimelineModel
    let key: StaffKey
    static let canvasHeight = 280.0
    static let bottomStep = 30 // Written E4, bottom line of treble staff.
    static func y(step: Int) -> Double { 160 - Double(step - bottomStep) * 6 }
    static func ledgerSteps(for step: Int) -> [Int] {
        if step < 29 { return Array(stride(from: 28, through: step, by: -2)) }
        if step > 39 { return Array(stride(from: 40, through: step, by: 2)) }
        return []
    }
    func symbols(in bar: Int64) throws -> [StaffSymbol] {
        let segments = timeline.segments(in: bar)
        var accidentals: [Int: Int] = [:], result: [StaffSymbol] = []
        var end = timeline.startTick(of: bar)
        for segment in segments {
            let resolved = segment.resolved
            guard segment.startTick == end else { throw StaffLimitation.gaps }
            guard resolved.pitches.count <= 1 else { throw StaffLimitation.polyphony }
            let pitch = resolved.pitches.first.map { StaffPitch(sounding: $0, key: key, preferredSpelling: timeline.tuning.preferredSpelling) }
            if let pitch, !(33...88).contains(pitch.soundingMIDI) { throw StaffLimitation.range }
            for fragment in try RhythmNotation.fragments(segment) {
                var accidental: String?
                // A tie carries its pitch over the barline, but does not establish an
                // accidental for a later, freshly attacked note in this new bar.
                if let pitch, !fragment.tieFromPrevious {
                    let current = accidentals[pitch.step] ?? key.alteration(letter: pitch.letter)
                    if current != pitch.alteration { accidental = pitch.alteration == 0 ? "♮" : pitch.alteration == 1 ? "♯" : "♭" }
                    accidentals[pitch.step] = pitch.alteration
                }
                result.append(StaffSymbol(resolved: resolved, fragment: fragment, pitch: pitch, accidental: accidental))
            }
            end = segment.endTick
        }
        let start = timeline.startTick(of: bar)
        let expectedEnd = start + min(timeline.ticksPerBar, timeline.exercise.durationTicks - start)
        guard end == expectedEnd else { throw StaffLimitation.gaps }
        // The last bar may end with the authored fragment; do not fabricate trailing rests.
        return result
    }
    /// Uniform eighth/sixteenth runs within a quarter beat; no rest or gap is bridged.
    func beams(_ symbols: [StaffSymbol]) -> [StaffBeam] {
        var result: [StaffBeam] = [], group: [StaffSymbol] = []
        func finish() {
            if group.count > 1 {
                let sum = group.compactMap(\.pitch).map(\.step).reduce(0, +)
                result.append(StaffBeam(ids: group.map(\.id), flags: group[0].flags, stemsUp: Double(sum) / Double(group.count) < 34))
            }
            group = []
        }
        for symbol in symbols {
            guard symbol.flags > 0 && symbol.pitch != nil && !symbol.fragment.duration.dotted else { finish(); continue }
            if let last = group.last,
               last.fragment.tripletID != symbol.fragment.tripletID || last.flags != symbol.flags || last.endTick != symbol.startTick ||
               timeline.notationGroupStart(at: last.startTick) != timeline.notationGroupStart(at: symbol.startTick) { finish() }
            group.append(symbol)
        }
        finish(); return result
    }
    func adjacent(to id: NotationFragmentID, offset: Int) -> StaffSymbol? {
        let bar = timeline.bar(containing: id.startTick)
        guard let symbols = try? symbols(in: bar), let index = symbols.firstIndex(where: { $0.id == id }) else { return nil }
        let next = index + offset
        if symbols.indices.contains(next) { return symbols[next] }
        let adjacentBar = bar + (offset < 0 ? -1 : 1)
        guard (0..<timeline.barCount).contains(adjacentBar), let adjacent = try? self.symbols(in: adjacentBar) else { return nil }
        return offset < 0 ? adjacent.last : adjacent.first
    }
}
