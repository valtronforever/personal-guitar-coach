import Foundation
import Domain

public enum AssessmentEngine {
    /// Bounded dynamic programming: pitch never changes the assignment of an attack to a note.
    public static func evaluate(_ evidence: PracticeEvidence) throws -> AssessedPractice {
        let config = evidence.configuration, parameters = AssessmentParameters.current
        let expected = config.selectedEvents.filter { $0.kind == .note }
        let tuning = config.exercise.requiredTuning ?? config.instrument.tuning
        let frequencies = try expected.map { try tuning.pitch(at: $0.positions[0]).frequency(referenceA4: tuning.referenceA4) }
        let secondsPerTick = 60 / config.bpm / Double(config.exercise.ppq)
        let relative = expected.map { Double($0.startTick - config.range.lowerBound) * secondsPerTick }
        let intervals = zip(relative, relative.dropFirst()).map { $1 - $0 }
        let tolerance = min(parameters.rhythmToleranceSeconds, (intervals.min() ?? .infinity) * parameters.rhythmIntervalFraction)
        let capability = config.calibration?.rhythmCapability(route: config.route, toleranceSeconds: tolerance,
            durationSeconds: config.durationSeconds, clockDriftSeconds: evidence.maximumClockDriftSeconds,
            onsetUncertaintySeconds: parameters.onsetUncertaintySeconds) ?? .unmeasured
        guard let epoch = evidence.renderEpochSeconds else {
            return try AssessedPractice(evidence: evidence, validity: evidence.signalConfirmed ? .interrupted : .insufficientSignal,
                rhythmCapability: capability, rhythmToleranceSeconds: tolerance,
                notes: try zip(expected, frequencies).map { try AssessedNote(id: $0.id, attackID: nil, targetFrequency: $1,
                    centsError: nil, timingErrorSeconds: nil, uncertain: false) }, extras: [], overallScore: nil, pitchScore: nil, timingScore: nil)
        }
        func time(_ tick: Int64) throws -> Double {
            try config.route.expectedTime(renderEpochSeconds: epoch,
                sampleFrame: Int64(((config.countInSeconds + Double(tick - config.range.lowerBound) * secondsPerTick) * config.route.output.sampleRate).rounded()))
        }
        let expectedTimes = try expected.map { try time($0.startTick) }
        let rests = try config.selectedEvents.filter { $0.kind == .rest }.map { (id: $0.id, start: try time($0.startTick), end: try time($0.endTick)) }
        let offset = config.calibration?.residualOffsetSeconds ?? 0
        let window = try config.observationWindow(renderEpochSeconds: epoch)
        let attacks = evidence.attacks.filter { window.contains($0.normalizedOnset - offset) }
        let observed = attacks.map { $0.normalizedOnset - offset }
        let restIDs = observed.map { value in rests.first { $0.start <= value && value < $0.end }?.id }
        let radii = expected.indices.map { i in
            let before = i > 0 ? expectedTimes[i] - expectedTimes[i - 1] : Double.infinity
            let after = i + 1 < expected.count ? expectedTimes[i + 1] - expectedTimes[i] : Double.infinity
            return min(parameters.maximumMatchSeconds, parameters.matchIntervalFraction * min(before, after))
        }
        let matches = align(expected: expectedTimes, observed: observed, radii: radii, restIDs: restIDs)
        var notes: [AssessedNote] = [], used = Set<Int>()
        var pitchPoints = 0.0, rhythmPoints = 0.0
        for i in expected.indices {
            let index = matches[i], attack = index.map { attacks[$0] }
            if let index { used.insert(index) }
            let qualityStart = attack.map { $0.normalizedOnset - offset } ?? expectedTimes[i]
            let qualityEnd = min(try time(expected[i].endTick), qualityStart + PracticeConfiguration.resolutionAllowanceSeconds)
            let clipped = evidence.clipping.contains { $0.start - offset < qualityEnd && $0.end - offset >= qualityStart }
            // Reliable onset resolution supersedes normal transient settling. Without an onset,
            // sustained non-silent uncertainty cannot be reported as healthy all-missed silence.
            let uncertainDuration = evidence.uncertainSignal.reduce(0.0) { total, span in
                total + max(0, min(qualityEnd, span.interval.end - offset) - max(qualityStart, span.interval.start - offset))
            }
            let uncertain = clipped || (attack.map { !$0.reliable } ?? (uncertainDuration >= 0.1))
            let cents: Double?
            if !uncertain, let frequency = attack?.frequency {
                // Subtract logarithms to keep very small finite input frequencies from underflowing a ratio.
                cents = 1200 * (log2(frequency) - log2(frequencies[i]))
            } else { cents = nil }
            let timing = !uncertain && capability == .available ? index.map { observed[$0] - expectedTimes[i] } : nil
            if let cents { pitchPoints += max(0, 1 - abs(cents) / parameters.pitchToleranceCents) }
            if let timing { rhythmPoints += max(0, 1 - abs(timing) / tolerance) }
            notes.append(try AssessedNote(id: expected[i].id, attackID: attack?.id, targetFrequency: frequencies[i],
                centsError: cents, timingErrorSeconds: timing, uncertain: uncertain))
        }
        let extras = try attacks.indices.filter { !used.contains($0) }.map {
            try AssessedExtra(id: attacks[$0].id, restID: restIDs[$0], uncertain: !attacks[$0].reliable)
        }
        let uncertain = notes.filter(\.uncertain).count + extras.filter(\.uncertain).count
        let validity: AssessmentValidity
        if !evidence.signalConfirmed { validity = .insufficientSignal }
        else if evidence.phase != .completed { validity = .interrupted }
        else if Double(uncertain) / Double(expected.count) > parameters.uncertaintyFraction { validity = .insufficientSignal }
        else { validity = capability == .available ? .valid : .uncalibrated }
        let pitch = 100 * pitchPoints / Double(expected.count), rhythm = 100 * rhythmPoints / Double(expected.count)
        let overall = min(100, max(0, (parameters.pitchWeight * pitch + (1 - parameters.pitchWeight) * rhythm
            - parameters.extraPenalty * Double(extras.count) / Double(expected.count + extras.count)).rounded()))
        return try AssessedPractice(evidence: evidence, validity: validity, rhythmCapability: capability,
            rhythmToleranceSeconds: tolerance, notes: notes, extras: extras,
            overallScore: validity == .valid ? overall : nil,
            pitchScore: validity == .valid || validity == .uncalibrated ? pitch : nil,
            timingScore: validity == .valid ? rhythm : nil)
    }

    private static func align(expected: [Double], observed: [Double], radii: [Double], restIDs: [String?]) -> [Int?] {
        let width = observed.count + 1
        // 0 = delete expected note, 1 = insert extra attack, 2 = match. At most ~2.1 MB.
        var path = [UInt8](repeating: 0, count: (expected.count + 1) * width)
        var previous = (0...observed.count).map(Double.init)
        for j in 1..<width { path[j] = 1 }
        for i in expected.indices {
            var current = [Double](repeating: 0, count: width); current[0] = Double(i + 1)
            for j in observed.indices {
                let delta = abs(observed[j] - expected[i])
                let candidate = restIDs[j] == nil && delta <= radii[i]
                var cost = previous[j + 1] + 1, step: UInt8 = 0
                let insertion = current[j] + 1
                if insertion < cost { cost = insertion; step = 1 }
                if candidate {
                    let matched = previous[j] + delta / radii[i]
                    if matched <= cost { cost = matched; step = 2 }
                }
                current[j + 1] = cost; path[(i + 1) * width + j + 1] = step
            }
            previous = current
        }
        var result = [Int?](repeating: nil, count: expected.count), i = expected.count, j = observed.count
        while i > 0 || j > 0 {
            switch path[i * width + j] {
            case 2: result[i - 1] = j - 1; i -= 1; j -= 1
            case 1: j -= 1
            default: i -= 1
            }
        }
        return result
    }
}
