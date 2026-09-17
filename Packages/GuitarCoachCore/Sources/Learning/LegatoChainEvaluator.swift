import Foundation
import Domain

enum LegatoChainEvaluator {
    static func evaluate(_ evidence: PracticeEvidence, notes: [AssessedNote]) throws -> LegatoChainAssessment? {
        let config = evidence.configuration, targets = config.selectedEvents.filter { $0.legatoChain != nil }
        guard !targets.isEmpty else { return nil }
        let assessed = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let attacks = Dictionary(uniqueKeysWithValues: evidence.attacks.map { ($0.id, $0) })
        let frames = evidence.pitchContour?.frames ?? [], secondsPerTick = config.exercise.timeSignature.secondsPerTick(bpm: config.bpm)
        return try LegatoChainAssessment(notes: targets.map { event in
            let chain = event.legatoChain!, note = assessed[event.id]!
            let kinds: [PitchTransitionPhaseAssessment.Kind] = [.base] + Array(repeating: .target, count: chain.targets.count)
            let boundaries = chain.boundaryTicks + [event.durationTicks]
            let expected: Double?
            if let epoch = evidence.renderEpochSeconds {
                expected = try config.route.expectedTime(renderEpochSeconds: epoch,
                    sampleFrame: Int64(((config.countInSeconds + Double(event.startTick - config.range.lowerBound) * secondsPerTick) * config.route.output.sampleRate).rounded())) + (config.calibration?.residualOffsetSeconds ?? 0)
            } else { expected = nil }
            let start = note.attackID.flatMap { attacks[$0]?.normalizedOnset } ?? expected
            let supported = LegatoChainCapability.supports(chain: chain, durationTicks: event.durationTicks, bpm: config.bpm,
                frequency: note.targetFrequency, pulseTicks: config.exercise.timeSignature.pulseTicks)
            let phases = try kinds.indices.map { index -> PitchTransitionPhaseAssessment in
                guard let start, supported, frames.count >= 2 else {
                    return try PitchTransitionPhaseAssessment(kind: kinds[index], matchedFraction: nil, silentFraction: 0, unknownFraction: 1, medianErrorCents: nil)
                }
                // Initial pitch needs transient settling; other boundaries allow half the detector window.
                let lower = start + Double(boundaries[index]) * secondsPerTick + (index == 0 ? 0.2 : 0.06)
                let upper = start + Double(boundaries[index + 1]) * secondsPerTick - 0.06, length = upper - lower
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
                            let expectedCents = chain.cents(at: (frame.normalizedTime - start) / secondsPerTick)
                            let heardCents = 1200 * (log2(frame.frequency!) - log2(note.targetFrequency))
                            let error = heardCents - expectedCents
                            errors.append(error)
                            let tolerance = 35.0
                            if abs(error) <= tolerance { matched += seconds }
                        case .uncertain: break
                        }
                    }
                    cursor += 1
                }
                let unknown = min(1, max(0, 1 - known / length)), sorted = errors.sorted()
                let median: Double? = sorted.isEmpty ? nil : sorted.count % 2 == 0 ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
                return try PitchTransitionPhaseAssessment(kind: kinds[index], matchedFraction: unknown > 0.2 + 1e-9 ? nil : min(1, matched / length),
                    silentFraction: min(1, silent / length), unknownFraction: unknown, medianErrorCents: median)
            }
            return try LegatoChainNoteAssessment(id: event.id, normalizedStart: start, semitoneOffsets: chain.semitoneOffsets, phases: phases)
        })
    }
}
