import Foundation
import Domain

public enum FeedbackKind: String, Sendable {
    case inputLevel, signal, interrupted, restart, calibration, early, late, missed, pitch, tuning, rests, repeatFragment
}
public enum FeedbackAction: Sendable { case audioSetup, tuner, repeatFragment }

/// Advice is derived from archived measurements, never from an inferred hand, finger, or string.
public struct PracticeRecommendation: Equatable, Sendable, Identifiable {
    public static let ruleVersion = "feedback-1"
    public var id: String { kind.rawValue }
    public let sourceAttemptID: UUID
    public let kind: FeedbackKind
    public let action: FeedbackAction
    public let eventIDs: [String]
    public let attackIDs: [UInt64]
    public let evidenceCount: Int
    public let denominator: Int
    public let firstBar: Int
    public let lastBar: Int
    public let bpm: Double
}

public enum FeedbackEngine {
    public static func recommendations(for result: AssessedPractice) -> [PracticeRecommendation] {
        let config = result.evidence.configuration
        let barTicks = config.exercise.timeSignature.ticksPerBar
        let first = Int(config.range.lowerBound / barTicks) + 1
        let last = Int((config.range.upperBound - 1) / barTicks) + 1
        let notesByID = Dictionary(uniqueKeysWithValues: result.notes.map { ($0.id, $0) })
        let barsByID = Dictionary(uniqueKeysWithValues: config.selectedEvents.map { ($0.id, Int($0.startTick / barTicks) + 1) })
        let nextBPM = max(config.exercise.minimumBPM, floor(config.bpm * 0.85 / 5) * 5)
        func advice(_ kind: FeedbackKind, _ action: FeedbackAction, events: [String] = [], attacks: [UInt64] = [],
                    count: Int = 0, denominator: Int = 0, firstBar: Int? = nil, lastBar: Int? = nil) -> PracticeRecommendation {
            PracticeRecommendation(sourceAttemptID: result.id, kind: kind, action: action, eventIDs: events, attackIDs: attacks,
                evidenceCount: count, denominator: denominator, firstBar: firstBar ?? first, lastBar: lastBar ?? last,
                bpm: action == .repeatFragment && kind != .repeatFragment && kind != .restart ? nextBPM : config.bpm)
        }
        if result.validity == .insufficientSignal {
            if !result.evidence.clipping.isEmpty {
                return [advice(.inputLevel, .audioSetup, count: result.evidence.clipping.count)]
            }
            return [advice(.signal, .audioSetup, events: result.notes.filter(\.uncertain).map(\.id),
                attacks: result.extras.filter(\.uncertain).map(\.id), count: result.uncertainCount + result.uncertainExtraCount,
                denominator: result.expectedCount)]
        }
        if result.validity == .interrupted {
            let intentional: Set<PracticeStopReason> = [.userCancelled, .paused, .changedTempo, .changedRange, .changedInstrument, .changedExercise]
            return [advice(intentional.contains(result.evidence.reason ?? .audioFailure) ? .restart : .interrupted,
                intentional.contains(result.evidence.reason ?? .audioFailure) ? .repeatFragment : .audioSetup)]
        }
        var answer: [PracticeRecommendation] = []
        if result.validity == .uncalibrated { answer.append(advice(.calibration, .audioSetup)) }

        // Only cut at legal whole-bar boundaries. A held event cannot be split by a retry link.
        var windows: [ClosedRange<Int>] = []
        for start in first...last {
            for end in start...min(start + 3, last) {
                let lower = Int64(start - 1) * barTicks, upper = min(Int64(end) * barTicks, config.range.upperBound)
                guard !config.selectedEvents.contains(where: { $0.startTick < lower && $0.endTick > lower || $0.startTick < upper && $0.endTick > upper }),
                      config.selectedEvents.contains(where: { $0.kind == .note && (lower..<upper).contains($0.startTick) }) else { continue }
                windows.append(start...end)
            }
        }
        func best(_ candidates: [AssessedNote], minimum: Int, kind: FeedbackKind, action: FeedbackAction = .repeatFragment) -> PracticeRecommendation? {
            var chosen: PracticeRecommendation?
            for window in windows {
                let selected = candidates.filter { barsByID[$0.id].map(window.contains) ?? false }
                guard selected.count >= minimum else { continue }
                let denominator = result.notes.filter { barsByID[$0.id].map(window.contains) ?? false }.count
                let item = advice(kind, action, events: selected.map(\.id), attacks: selected.compactMap(\.attackID),
                    count: selected.count, denominator: denominator, firstBar: window.lowerBound, lastBar: window.upperBound)
                if item.evidenceCount > (chosen?.evidenceCount ?? -1) { chosen = item }
            }
            return chosen
        }
        if result.validity == .valid {
            let timing = result.notes.filter { !$0.uncertain && abs($0.timingErrorSeconds ?? 0) > result.rhythmToleranceSeconds }
            for (kind, sign) in [(FeedbackKind.early, -1.0), (.late, 1.0)] {
                let same = timing.filter { ($0.timingErrorSeconds ?? 0) * sign > 0 }
                if let candidate = best(same, minimum: 3, kind: kind) {
                    let total = timing.filter { (candidate.firstBar...candidate.lastBar).contains(barsByID[$0.id] ?? 0) }.count
                    if Double(candidate.evidenceCount) >= Double(total) * 0.75 { answer.append(candidate) }
                }
            }
        }
        if let missed = best(result.notes.filter { !$0.uncertain && $0.attackID == nil }, minimum: 2, kind: .missed) { answer.append(missed) }
        let wrong = result.notes.filter { !$0.uncertain && abs($0.centsError ?? 0) >= result.parameters.pitchToleranceCents }
        let pitchGroups = Dictionary(grouping: wrong, by: \.targetFrequency)
        let pitchAdvice = pitchGroups.values.compactMap { best($0, minimum: 2, kind: .pitch) }.sorted {
            if $0.evidenceCount != $1.evidenceCount { return $0.evidenceCount > $1.evidenceCount }
            if $0.firstBar != $1.firstBar { return $0.firstBar < $1.firstBar }
            return $0.eventIDs.lexicographicallyPrecedes($1.eventIDs)
        }
        if let pitch = pitchAdvice.first { answer.append(pitch) }
        for sign in [-1.0, 1.0] {
            let detuned = result.notes.filter { !$0.uncertain && (20..<50).contains(abs($0.centsError ?? 0)) }
            let same = detuned.filter { ($0.centsError ?? 0) * sign > 0 }
            if let candidate = best(same, minimum: 3, kind: .tuning, action: .tuner) {
                let total = detuned.filter { (candidate.firstBar...candidate.lastBar).contains(barsByID[$0.id] ?? 0) }.count
                let pitches = Set(candidate.eventIDs.compactMap { notesByID[$0]?.targetFrequency })
                if pitches.count >= 3 && Double(candidate.evidenceCount) >= Double(total) * 0.75 { answer.append(candidate); break }
            }
        }
        var restAdvice: PracticeRecommendation?
        for window in windows {
            let rests = config.selectedEvents.filter { $0.kind == .rest && window.contains(barsByID[$0.id] ?? 0) }.map(\.id)
            let extras = result.extras.filter { !$0.uncertain && $0.restID.map(rests.contains) == true }
            guard extras.count >= 2 else { continue }
            let events = rests.filter { id in extras.contains { $0.restID == id } }
            let item = advice(.rests, .repeatFragment, events: events, attacks: extras.map(\.id), count: extras.count,
                denominator: rests.count, firstBar: window.lowerBound, lastBar: window.upperBound)
            if item.evidenceCount > (restAdvice?.evidenceCount ?? -1) { restAdvice = item }
        }
        if let restAdvice { answer.append(restAdvice) }
        if answer.isEmpty || answer.count == 1 && answer[0].kind == .calibration {
            let window = first...last
            let events = result.notes
            answer.append(advice(.repeatFragment, .repeatFragment, events: events.map(\.id), attacks: events.compactMap(\.attackID),
                count: events.count, denominator: events.count, firstBar: window.lowerBound, lastBar: window.upperBound))
        }
        return Array(answer.prefix(3))
    }
}

public enum PracticeComparison {
    /// Conservative equality of archived conditions; no historical regrading or cross-tempo ranking.
    public static func compatible(_ lhs: AssessedPractice, _ rhs: AssessedPractice) -> Bool {
        let a = lhs.evidence.configuration, b = rhs.evidence.configuration
        return lhs.validity == rhs.validity && (lhs.validity == .valid || lhs.validity == .uncalibrated)
            && a.exercise == b.exercise && a.instrument.tuning == b.instrument.tuning && a.instrument.source == b.instrument.source && a.instrument.frets == b.instrument.frets
            && a.bpm == b.bpm && a.range == b.range && a.countInBars == b.countInBars
            && a.route == b.route && a.calibration == b.calibration && a.capabilityVersion == b.capabilityVersion
            && lhs.evidence.analysisVersion == rhs.evidence.analysisVersion && lhs.parameters == rhs.parameters
            && lhs.rhythmCapability == rhs.rhythmCapability && lhs.rhythmToleranceSeconds == rhs.rhythmToleranceSeconds
    }
    public static func score(_ result: AssessedPractice) -> Double? {
        result.validity == .valid ? result.overallScore : result.validity == .uncalibrated ? result.pitchScore : nil
    }
    public static func previous(to result: AssessedPractice, in history: [AssessedPractice]) -> AssessedPractice? {
        history.filter { $0.id != result.id && $0.evidence.startedAt < result.evidence.startedAt && compatible(result, $0) }
            .sorted { $0.evidence.startedAt == $1.evidence.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.evidence.startedAt > $1.evidence.startedAt }.first
    }
    public static func best(for result: AssessedPractice, in history: [AssessedPractice]) -> AssessedPractice? {
        history.filter { compatible(result, $0) && score($0) != nil }.sorted {
            if score($0) != score($1) { return (score($0) ?? 0) > (score($1) ?? 0) }
            return $0.evidence.startedAt == $1.evidence.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.evidence.startedAt < $1.evidence.startedAt
        }.first
    }
}
