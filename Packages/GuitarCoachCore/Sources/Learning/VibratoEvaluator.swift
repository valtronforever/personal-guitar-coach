import Foundation
import Domain

enum VibratoEvaluator {
    static func evaluate(_ evidence: PracticeEvidence, notes: [AssessedNote]) throws -> VibratoAssessment? {
        let config = evidence.configuration, targets = config.selectedEvents.filter { $0.vibrato != nil }
        guard !targets.isEmpty else { return nil }
        let assessed = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let attacks = Dictionary(uniqueKeysWithValues: evidence.attacks.map { ($0.id, $0) })
        let frames = evidence.pitchContour?.frames ?? [], secondsPerTick = config.exercise.timeSignature.secondsPerTick(bpm: config.bpm)
        return try VibratoAssessment(notes: targets.map { event in
            let vibrato = event.vibrato!, note = assessed[event.id]!
            let kinds: [VibratoPhaseAssessment.Kind] = [.base, .modulation, .returned]
            let boundaries = [Int64(0), vibrato.startTick, vibrato.endTick, event.durationTicks]
            let expected: Double?
            if let epoch = evidence.renderEpochSeconds {
                expected = try config.route.expectedTime(renderEpochSeconds: epoch,
                    sampleFrame: Int64(((config.countInSeconds + Double(event.startTick - config.range.lowerBound) * secondsPerTick) * config.route.output.sampleRate).rounded())) + (config.calibration?.residualOffsetSeconds ?? 0)
            } else { expected = nil }
            let start = note.attackID.flatMap { attacks[$0]?.normalizedOnset } ?? expected
            let supported = VibratoCapability.supports(vibrato: vibrato, durationTicks: event.durationTicks, bpm: config.bpm,
                frequency: note.targetFrequency, pulseTicks: config.exercise.timeSignature.pulseTicks)
            let statistics = VibratoStatistics(frames: supported ? frames : [],
                range: ((start ?? 0) + Double(vibrato.startTick) * secondsPerTick)..<((start ?? 0) + Double(vibrato.endTick) * secondsPerTick),
                baseFrequency: note.targetFrequency)
            let metrics = try VibratoModulationMetrics(lowCents: statistics.lowCents, widthCents: statistics.widthCents,
                rateHz: statistics.rateHz, periodVariation: statistics.periodVariation, measuredPeriods: statistics.measuredPeriods, slowestRateHz: statistics.slowestRateHz, fastestRateHz: statistics.fastestRateHz)
            let expectedRate = 1 / (Double(vibrato.periodTicks) * secondsPerTick)
            let correctModulation: Bool
            if let low = metrics.lowCents, let width = metrics.widthCents, let slowest = metrics.slowestRateHz, let fastest = metrics.fastestRateHz, let variation = metrics.periodVariation {
                correctModulation = abs(low) <= 20 && abs(width - Double(vibrato.extentCents)) <= max(10, Double(vibrato.extentCents) * 0.25)
                    && slowest >= expectedRate * 0.8 && fastest <= expectedRate * 1.2 && variation <= 0.2
            } else { correctModulation = false }
            let phases = try kinds.indices.map { index -> VibratoPhaseAssessment in
                guard let start, supported, frames.count >= 2 else {
                    return try VibratoPhaseAssessment(kind: kinds[index], matchedFraction: nil, silentFraction: 0, unknownFraction: 1, medianErrorCents: nil)
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
                            let heardCents = 1200 * (log2(frame.frequency!) - log2(note.targetFrequency))
                            if kinds[index] == .modulation {
                                if correctModulation { matched += seconds }
                            } else {
                                errors.append(heardCents)
                                if abs(heardCents) <= 35 { matched += seconds }
                            }
                        case .uncertain: break
                        }
                    }
                    cursor += 1
                }
                let unknown = min(1, max(0, 1 - known / length)), sorted = errors.sorted()
                let median: Double? = sorted.isEmpty ? nil : sorted.count % 2 == 0 ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 : sorted[sorted.count / 2]
                return try VibratoPhaseAssessment(kind: kinds[index], matchedFraction: unknown > 0.2 + 1e-9 ? nil : min(1, matched / length),
                    silentFraction: min(1, silent / length), unknownFraction: unknown, medianErrorCents: median)
            }
            return try VibratoNoteAssessment(id: event.id, normalizedStart: start, phases: phases, modulation: metrics)
        })
    }
}
