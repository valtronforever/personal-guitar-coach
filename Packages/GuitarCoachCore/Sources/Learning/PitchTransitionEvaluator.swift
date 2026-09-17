import Foundation
import Domain

enum PitchTransitionEvaluator {
    static func evaluate(_ evidence: PracticeEvidence, notes: [AssessedNote]) throws -> PitchTransitionAssessment? {
        let config = evidence.configuration, targets = config.selectedEvents.filter { $0.pitchTransition != nil }
        guard !targets.isEmpty else { return nil }
        let assessed = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let attacks = Dictionary(uniqueKeysWithValues: evidence.attacks.map { ($0.id, $0) })
        let frames = evidence.pitchContour?.frames ?? [], secondsPerTick = config.exercise.timeSignature.secondsPerTick(bpm: config.bpm)
        return try PitchTransitionAssessment(notes: targets.map { event in
            let transition = event.pitchTransition!, note = assessed[event.id]!
            let kinds: [PitchTransitionPhaseAssessment.Kind] = transition.kind == .slide ? [.base, .travel, .target] : [.base, .target]
            let boundaries: [Int64] = transition.kind == .slide
                ? [0, transition.startTick, transition.endTick, event.durationTicks]
                : [0, transition.startTick, event.durationTicks]
            let expected: Double?
            if let epoch = evidence.renderEpochSeconds {
                expected = try config.route.expectedTime(renderEpochSeconds: epoch,
                    sampleFrame: Int64(((config.countInSeconds + Double(event.startTick - config.range.lowerBound) * secondsPerTick) * config.route.output.sampleRate).rounded())) + (config.calibration?.residualOffsetSeconds ?? 0)
            } else { expected = nil }
            let start = note.attackID.flatMap { attacks[$0]?.normalizedOnset } ?? expected
            let supported = PitchTransitionCapability.supports(transition: transition, durationTicks: event.durationTicks, bpm: config.bpm,
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
                var intermediateCoverage = [Double](repeating: 0, count: max(0, abs(transition.semitones) - 1))
                while cursor + 1 < frames.count, frames[cursor].normalizedTime < upper {
                    let frame = frames[cursor], next = frames[cursor + 1]
                    let low = max(lower, frame.normalizedTime), high = min(upper, next.normalizedTime), seconds = max(0, high - low)
                    if seconds > 0 {
                        switch frame.state {
                        case .silence: known += seconds; silent += seconds
                        case .pitched:
                            known += seconds
                            let expectedCents = transition.cents(at: (frame.normalizedTime - start) / secondsPerTick)
                            let heardCents = 1200 * (log2(frame.frequency!) - log2(note.targetFrequency))
                            let error = heardCents - expectedCents
                            if kinds[index] == .travel {
                                for step in intermediateCoverage.indices {
                                    let center = Double((step + 1) * (transition.semitones > 0 ? 100 : -100))
                                    if abs(heardCents - center) <= 35 { intermediateCoverage[step] += seconds }
                                }
                            }
                            errors.append(error)
                            // Fretted slides cross semitone steps: half a fret plus normal pitch tolerance.
                            let tolerance = kinds[index] == .travel ? 85.0 : 35.0
                            if abs(error) <= tolerance { matched += seconds }
                        case .uncertain: break
                        }
                    }
                    cursor += 1
                }
                // A multi-fret slide must audibly cross its intermediate pitches. A direct jump can
                // otherwise earn travel credit merely by arriving early inside the wide fret tolerance.
                if kinds[index] == .travel && intermediateCoverage.contains(where: { $0 < 0.1 - 1e-9 }) { matched = 0 }
                let unknown = min(1, max(0, 1 - known / length)), sorted = errors.sorted()
                let median: Double? = sorted.isEmpty ? nil : sorted.count % 2 == 0 ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
                return try PitchTransitionPhaseAssessment(kind: kinds[index], matchedFraction: unknown > 0.2 + 1e-9 ? nil : min(1, matched / length),
                    silentFraction: min(1, silent / length), unknownFraction: unknown, medianErrorCents: median)
            }
            return try PitchTransitionNoteAssessment(id: event.id, kind: transition.kind, normalizedStart: start, phases: phases)
        })
    }
}
