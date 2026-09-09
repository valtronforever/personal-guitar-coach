import Foundation
import Domain

public enum TunerMode: Equatable, Sendable { case automatic, manual(string: Int) }
public enum TunerFeedback: String, Sendable {
    case waiting, flat, sharp, centering, inTune, chooseString, unsupportedTarget
    case silence, quiet, unstable, clipping, outOfRange, invalid
}

public struct TunerReading: Equatable, Sendable {
    public let feedback: TunerFeedback
    public let detectedPitch: Pitch?
    public let frequency: Double?
    public let targetString: Int?
    public let targetPitch: Pitch?
    public let targetFrequency: Double?
    public let cents: Double?
    public let indicatorCents: Double?
    public let clarity: Double?
}

/// Tuning feedback over measured evidence. It never changes the detected frequency or infers a physical string.
public struct TunerTracker: Sendable {
    public private(set) var tuning: TuningProfile
    public private(set) var mode: TunerMode
    public private(set) var reading: TunerReading
    private var automaticString: Int?
    private var lastTime: Double?
    private var stableSince: Double?
    private var recentCents: [Double] = []

    public init(tuning: TuningProfile = .standard, mode: TunerMode = .automatic) throws {
        if case let .manual(string) = mode, !(1...6).contains(string) { throw MusicError.invalidString }
        self.tuning = tuning; self.mode = mode
        reading = TunerReading(feedback: .waiting, detectedPitch: nil, frequency: nil, targetString: nil,
                               targetPitch: nil, targetFrequency: nil, cents: nil, indicatorCents: nil, clarity: nil)
        reset()
    }

    public mutating func configure(tuning: TuningProfile, mode: TunerMode) throws {
        if case let .manual(string) = mode, !(1...6).contains(string) { throw MusicError.invalidString }
        guard self.tuning != tuning || self.mode != mode else { return }
        self.tuning = tuning; self.mode = mode; reset()
    }

    public mutating func reset(feedback: TunerFeedback = .waiting) {
        automaticString = nil; lastTime = nil; clearQualification()
        reading = makeReading(feedback: feedback, target: manualTarget)
    }

    /// Time is the analyzer's stream time. Repeated UI snapshots cannot advance the 300 ms qualification.
    /// interrupted covers an intervening non-reliable quality span or a skipped evidence prefix.
    public mutating func update(frequency: Double?, clarity: Double?, quality: SignalQuality,
                                streamTime: Double, interrupted: Bool = false) {
        guard streamTime.isFinite, streamTime >= 0 else { reset(feedback: .invalid); return }
        if let lastTime, streamTime == lastTime, !interrupted { return }
        if interrupted || lastTime.map({ streamTime < $0 || streamTime - $0 > 0.15 }) == true { clearQualification() }
        lastTime = streamTime
        guard quality == .reliable, let frequency, frequency.isFinite, frequency > 0,
              let clarity, clarity.isFinite, (0.9...1).contains(clarity),
              let detected = try? Pitch.nearest(to: frequency, referenceA4: tuning.referenceA4) else {
            clearQualification()
            reading = makeReading(feedback: Self.feedback(for: quality), target: manualTarget)
            return
        }
        let target: TunedString?
        var needsConfirmation = false
        switch mode {
        case .manual: target = manualTarget
        case .automatic:
            let sorted = tuning.strings.sorted { distance(frequency, $0) < distance(frequency, $1) }
            var candidate = sorted[0]
            if let held = tuning.strings.first(where: { $0.number == automaticString }),
               distance(frequency, held) <= 150, distance(frequency, held) - distance(frequency, candidate) < 30 { candidate = held }
            if distance(frequency, candidate) > 150 {
                clearQualification(); automaticString = nil
                reading = makeReading(feedback: .chooseString, frequency: frequency, detected: detected, clarity: clarity)
                return
            }
            if automaticString != candidate.number { clearQualification(); automaticString = candidate.number }
            target = candidate
            needsConfirmation = distance(frequency, sorted[1]) - distance(frequency, sorted[0]) < 20 || harmonicAmbiguity(candidate)
        }
        guard let target, let targetHz = try? target.openPitch.frequency(referenceA4: tuning.referenceA4),
              let cents = try? target.openPitch.cents(from: frequency, referenceA4: tuning.referenceA4) else {
            reset(feedback: .invalid); return
        }
        guard MonophonicCapability.frequencyRange.contains(targetHz) else {
            clearQualification()
            reading = makeReading(feedback: .unsupportedTarget, target: target, frequency: frequency, detected: detected, clarity: clarity)
            return
        }
        if needsConfirmation {
            clearQualification()
            reading = makeReading(feedback: .chooseString, target: target, frequency: frequency, detected: detected, clarity: clarity)
            return
        }
        recentCents.append(cents)
        if recentCents.count > 5 { recentCents.removeFirst() }
        let indicator = recentCents.sorted()[recentCents.count / 2]
        let feedback: TunerFeedback
        // Temporal hysteresis: qualify for 300 ms, but revoke immediately outside the true ±5-cent band.
        if abs(cents) <= 5 + 1e-7 {
            if stableSince == nil { stableSince = streamTime }
            feedback = streamTime - stableSince! >= 0.3 - 1e-9 ? .inTune : .centering
        } else {
            stableSince = nil
            feedback = cents < 0 ? .flat : .sharp
        }
        reading = makeReading(feedback: feedback, target: target, frequency: frequency, detected: detected,
                              clarity: clarity, cents: cents, indicator: indicator)
    }

    private var manualTarget: TunedString? {
        guard case let .manual(string) = mode else { return nil }
        return tuning.strings.first { $0.number == string }
    }
    private mutating func clearQualification() { stableSince = nil; recentCents.removeAll(keepingCapacity: true) }
    private func distance(_ frequency: Double, _ string: TunedString) -> Double {
        abs((try? string.openPitch.cents(from: frequency, referenceA4: tuning.referenceA4)) ?? .infinity)
    }
    private func harmonicAmbiguity(_ candidate: TunedString) -> Bool {
        guard let target = try? candidate.openPitch.frequency(referenceA4: tuning.referenceA4) else { return true }
        for string in tuning.strings where string.number != candidate.number {
            guard let other = try? string.openPitch.frequency(referenceA4: tuning.referenceA4) else { return true }
            for harmonic in 1...6 where abs(1200 * log2(target / (other * Double(harmonic)))) <= 15 { return true }
        }
        return false
    }
    private func makeReading(feedback: TunerFeedback, target: TunedString? = nil, frequency: Double? = nil,
                             detected: Pitch? = nil, clarity: Double? = nil, cents: Double? = nil, indicator: Double? = nil) -> TunerReading {
        let targetHz = target.flatMap { try? $0.openPitch.frequency(referenceA4: tuning.referenceA4) }
        let state = targetHz.map { !MonophonicCapability.frequencyRange.contains($0) } == true ? TunerFeedback.unsupportedTarget : feedback
        return TunerReading(feedback: state, detectedPitch: detected, frequency: frequency, targetString: target?.number,
                            targetPitch: target?.openPitch, targetFrequency: targetHz, cents: cents, indicatorCents: indicator, clarity: clarity)
    }
    private static func feedback(for quality: SignalQuality) -> TunerFeedback {
        switch quality {
        case .warmingUp: .waiting
        case .silence: .silence
        case .quiet: .quiet
        case .unstable, .ambiguous, .reliable: .unstable
        case .clipping: .clipping
        case .outOfRange: .outOfRange
        case .invalid: .invalid
        }
    }
}
