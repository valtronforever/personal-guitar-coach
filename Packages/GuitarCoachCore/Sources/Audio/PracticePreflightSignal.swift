import Foundation
import Domain

public enum PracticePreflightSignal {
    /// Evidence must span time in the analyzed stream; repeatedly displaying one frame cannot qualify.
    public static func isReady(_ capture: CaptureSnapshot?) -> Bool {
        guard let capture, capture.hostTimeValid, MonophonicCapability.sampleRates.contains(capture.sampleRate), capture.droppedPackets == 0, capture.discontinuities == 0,
              capture.invalidSamples == 0, capture.peak < 0.995,
              let analysis = capture.analysis, analysis.invalidSamples == 0, let latest = analysis.latest, latest.quality == .reliable,
              let pitch = latest.pitch, pitch.frequency.isFinite, pitch.frequency > 0, pitch.clarity.isFinite, (0.9...1).contains(pitch.clarity),
              latest.time.hostSeconds?.isFinite == true, latest.time.sampleRate == capture.sampleRate,
              latest.time.frame >= 0, UInt64(latest.time.frame) <= capture.totalFrames,
              Double(capture.totalFrames - UInt64(latest.time.frame)) / capture.sampleRate <= 0.05,
              let span = analysis.qualitySpans.last, span.quality == .reliable,
              span.start.sampleRate == capture.sampleRate, span.end.sampleRate == capture.sampleRate,
              span.start.frame >= 0, span.end.frame >= span.start.frame, span.end.frame >= latest.time.frame, span.end.streamSeconds - span.start.streamSeconds >= 0.2 else { return false }
        return true
    }
}
