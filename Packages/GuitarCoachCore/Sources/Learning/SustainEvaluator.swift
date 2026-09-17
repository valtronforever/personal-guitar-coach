import Foundation
import Domain

enum SustainEvaluator {
    /// Coverage of stable target pitch inside a held note. Start/end allowances
    /// exclude onset settling and window smearing; this is not an exact release-time grade.
    static func evaluate(_ evidence: PracticeEvidence, notes: [AssessedNote]) throws -> SustainAssessment? {
        let config = evidence.configuration
        let targets = config.selectedEvents.filter(\.assessSustain)
        guard !targets.isEmpty else { return nil }
        let assessed = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let attacks = Dictionary(uniqueKeysWithValues: evidence.attacks.map { ($0.id, $0) })
        let frames = evidence.sustainTrace?.frames ?? []
        func unknown(_ id: String, fraction: Double = 1) throws -> SustainNoteAssessment {
            try SustainNoteAssessment(id: id, state: .uncertain, heldFraction: nil, silentFraction: nil, unknownFraction: fraction)
        }
        let results = try targets.map { event -> SustainNoteAssessment in
            guard let note = assessed[event.id], !note.uncertain, let epoch = evidence.renderEpochSeconds, frames.count >= 2 else { return try unknown(event.id) }
            let duration = try MusicalTime.seconds(forTicks: event.durationTicks, bpm: config.bpm, pulseTicks: config.exercise.timeSignature.pulseTicks)
            guard duration >= SustainTrace.minimumNoteSeconds - 1e-9 else { return try unknown(event.id) }
            let attack = note.attackID.flatMap { attacks[$0] }
            let expected = try config.route.expectedTime(renderEpochSeconds: epoch,
                sampleFrame: Int64(((config.countInSeconds + Double(event.startTick - config.range.lowerBound) * config.exercise.timeSignature.secondsPerTick(bpm: config.bpm)) * config.route.output.sampleRate).rounded()))
            let start = attack?.normalizedOnset ?? expected + (config.calibration?.residualOffsetSeconds ?? 0)
            let lower = start + 0.2, upper = start + duration - 0.05, length = upper - lower
            var a = 0, b = frames.count
            while a < b {
                let middle = (a + b) / 2
                if frames[middle].normalizedTime < lower { a = middle + 1 } else { b = middle }
            }
            var index = max(0, a - 1), known = 0.0, held = 0.0, silent = 0.0
            while index + 1 < frames.count, frames[index].normalizedTime < upper {
                let frame = frames[index], next = frames[index + 1]
                let seconds = max(0, min(upper, next.normalizedTime) - max(lower, frame.normalizedTime))
                switch frame.state {
                case .silence: known += seconds; silent += seconds
                case .pitched:
                    known += seconds
                    if let hz = frame.frequency, abs(1200 * (log2(hz) - log2(note.targetFrequency))) <= 50 { held += seconds }
                case .uncertain: break
                }
                index += 1
            }
            let missing = min(1, max(0, 1 - known / length))
            guard missing <= 0.2 + 1e-9 else { return try unknown(event.id, fraction: missing) }
            return try SustainNoteAssessment(id: event.id, state: attack == nil ? .missed : .measured,
                heldFraction: attack == nil ? 0 : min(1, held / length), silentFraction: min(1, silent / length), unknownFraction: missing)
        }
        return try SustainAssessment(notes: results)
    }
}
