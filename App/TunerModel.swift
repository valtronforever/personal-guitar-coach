import SwiftUI
import Domain
import Audio

@MainActor @Observable
final class TunerModel {
    private var tracker = try! TunerTracker() // Validated immutable Standard/automatic defaults.
    private var lastFrame: Int64?
    private var lastSpanID: UInt64?
    private var lastFreshAt: ContinuousClock.Instant?
    private(set) var isStale = false
    var reading: TunerReading { tracker.reading }
    var mode: TunerMode { tracker.mode }

    func configure(tuning: TuningProfile, mode: TunerMode? = nil) {
        guard tracker.tuning != tuning || mode.map({ $0 != tracker.mode }) == true else { return }
        do { try tracker.configure(tuning: tuning, mode: mode ?? tracker.mode) }
        catch { tracker.reset(feedback: .invalid) }
        lastFrame = nil; lastSpanID = nil; lastFreshAt = nil; isStale = false
    }

    func stopReading() {
        tracker.reset(); lastFrame = nil; lastSpanID = nil; lastFreshAt = nil; isStale = false
    }

    func consume(_ analysis: AudioAnalysisSnapshot?, now: ContinuousClock.Instant = .now) {
        guard let analysis, let observation = analysis.latest else { expire(now: now); return }
        let frame = observation.time.frame
        if let lastFrame, frame < lastFrame { stopReading() }
        guard frame != lastFrame else { expire(now: now); return }
        let previousFrame = lastFrame ?? 0
        let missedPrefix = lastSpanID.flatMap { previous in analysis.qualitySpans.first.map { $0.id > previous + 1 } } ?? false
        let wasInterrupted = missedPrefix || analysis.qualitySpans.contains {
            $0.end.frame > previousFrame && $0.start.frame < frame && $0.quality != .reliable
        }
        tracker.update(frequency: observation.pitch?.frequency, clarity: observation.pitch?.clarity,
                       quality: observation.quality, streamTime: observation.time.streamSeconds, interrupted: wasInterrupted)
        lastFrame = frame; lastSpanID = analysis.totalQualitySpans; lastFreshAt = now; isStale = false
    }

    func expire(now: ContinuousClock.Instant = .now) {
        guard let lastFreshAt, lastFreshAt.duration(to: now) > .milliseconds(200), !isStale else { return }
        tracker.reset(); isStale = true
    }
}
