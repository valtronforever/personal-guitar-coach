import Foundation
import Domain

enum BendEvaluator {
    static func evaluate(_ evidence: PracticeEvidence, notes: [AssessedNote]) throws -> BendAssessment? {
        let config = evidence.configuration, targets = config.selectedEvents.filter { $0.bend != nil }
        guard !targets.isEmpty else { return nil }
        let assessed = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let attacks = Dictionary(uniqueKeysWithValues: evidence.attacks.map { ($0.id, $0) })
        let frames = evidence.pitchContour?.frames ?? [], secondsPerTick = config.exercise.timeSignature.secondsPerTick(bpm: config.bpm)
        return try BendAssessment(notes: targets.map { event in
            let bend = event.bend!, points = bend.points(durationTicks: event.durationTicks)
            let kinds: [BendPhaseAssessment.Kind] = bend.releaseEndTick == nil ? [.base, .rise, .target] : [.base, .rise, .target, .release, .returned]
            let note = assessed[event.id]!
            let expected: Double?
            if let epoch = evidence.renderEpochSeconds {
                expected = try config.route.expectedTime(renderEpochSeconds: epoch,
                    sampleFrame: Int64(((config.countInSeconds + Double(event.startTick - config.range.lowerBound) * secondsPerTick) * config.route.output.sampleRate).rounded())) + (config.calibration?.residualOffsetSeconds ?? 0)
            } else { expected = nil }
            let start = note.attackID.flatMap { attacks[$0]?.normalizedOnset } ?? expected
            let supported = BendCapability.supports(bend: bend, durationTicks: event.durationTicks, bpm: config.bpm,
                frequency: note.targetFrequency, pulseTicks: config.exercise.timeSignature.pulseTicks)
            let phases = try kinds.indices.map { index -> BendPhaseAssessment in
                guard let start, supported, frames.count >= 2 else {
                    return try BendPhaseAssessment(kind: kinds[index], matchedFraction: nil, silentFraction: 0, unknownFraction: 1, medianErrorCents: nil)
                }
                // 60 ms exceeds half the longest detector window; initial attack gets 200 ms.
                let lower = start + Double(points[index].tick) * secondsPerTick + (index == 0 ? 0.2 : 0.06)
                let upper = start + Double(points[index + 1].tick) * secondsPerTick - 0.06, length = upper - lower
                var a = 0, b = frames.count
                while a < b { let m = (a + b) / 2; if frames[m].normalizedTime < lower { a = m + 1 } else { b = m } }
                var cursor = max(0, a - 1), known = 0.0, matched = 0.0, silent = 0.0, errors: [Double] = []
                while cursor + 1 < frames.count, frames[cursor].normalizedTime < upper {
                    let frame = frames[cursor], next = frames[cursor + 1]
                    let low = max(lower, frame.normalizedTime), high = min(upper, next.normalizedTime), seconds = max(0, high - low)
                    if seconds > 0 {
                        switch frame.state {
                        case .silence: known += seconds; silent += seconds
                        case .pitched:
                            known += seconds
                            let expectedCents = bend.cents(at: (frame.normalizedTime - start) / secondsPerTick, durationTicks: event.durationTicks)
                            let error = 1200 * (log2(frame.frequency!) - log2(note.targetFrequency)) - expectedCents
                            errors.append(error)
                            if abs(error) <= 35 { matched += seconds }
                        case .uncertain: break
                        }
                    }
                    cursor += 1
                }
                let unknown = min(1, max(0, 1 - known / length)), sorted = errors.sorted()
                let median: Double? = sorted.isEmpty ? nil : sorted.count % 2 == 0 ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
                return try BendPhaseAssessment(kind: kinds[index], matchedFraction: unknown > 0.2 + 1e-9 ? nil : min(1, matched / length),
                    silentFraction: min(1, silent / length), unknownFraction: unknown, medianErrorCents: median)
            }
            return try BendNoteAssessment(id: event.id, normalizedStart: start, phases: phases)
        })
    }
}
