import Foundation
import Domain

/// Bounded deterministic assignment; identical pitches are never substituted across octaves.
enum LessonFingeringResolver {
    static func resolve(_ positions: [FretPosition], sourceTuning: TuningProfile, tuning: TuningProfile,
                        shift: Int, maximumFret: Int, region: FretRegion?) throws -> [FretPosition] {
        guard !positions.isEmpty else { return [] }
        let candidates = try positions.map { position -> [FretPosition] in
            let midi = try sourceTuning.pitch(at: position).midi + shift
            return tuning.strings.compactMap { string in
                try? FretPosition(string: string.number, fret: midi - string.openPitch.midi)
            }.filter { $0.fret <= maximumFret && (region?.contains($0, maximumFret: maximumFret) ?? true) }.sorted {
                let a = abs($0.string - position.string) * 12 + abs($0.fret - position.fret)
                let b = abs($1.string - position.string) * 12 + abs($1.fret - position.fret)
                return a == b ? $0.string < $1.string : a < b
            }
        }
        guard candidates.allSatisfy({ !$0.isEmpty }) else { throw LessonAdaptationError.unplayable }
        if positions.count == 1 { return [candidates[0][0]] }
        // At most six voices × six string choices. Never assign two chord voices to one string.
        var best: [FretPosition]?, bestCost = Int.max
        func search(_ chosen: [FretPosition], cost: Int) {
            guard cost < bestCost else { return }
            if chosen.count == positions.count {
                let fretted = chosen.filter { $0.fret > 0 }.map(\.fret)
                guard (fretted.max() ?? 0) - (fretted.min() ?? 0) <= 4 else { return }
                best = chosen; bestCost = cost; return
            }
            let index = chosen.count, original = positions[index]
            for candidate in candidates[index] where !chosen.contains(where: { $0.string == candidate.string }) {
                search(chosen + [candidate], cost: cost + abs(candidate.string - original.string) * 12 + abs(candidate.fret - original.fret))
            }
        }
        search([], cost: 0)
        guard let best else { throw LessonAdaptationError.unplayable }
        return best
    }
}
