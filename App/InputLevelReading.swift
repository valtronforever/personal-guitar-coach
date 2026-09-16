import Foundation
import Audio

/// Presentation guidance for gain adjustment, not a pitch/preflight acceptance gate.
struct InputLevelReading {
    enum State: String { case inactive, unavailable, silent, weak, good, high, clipping }
    static let floorDB = -60.0
    static let recommendedDB = -30.0
    static let highDB = -6.0
    // Same full-scale guard as calibration/preflight and the monophonic analyzer.
    static let clippingAmplitude: Float = 0.995

    let state: State
    let peakDB: Double?
    let rmsDB: Double?
    var fraction: Double { Self.fraction(for: peakDB ?? Self.floorDB) }
    var statusKey: String { "audio.meter.state." + state.rawValue }
    var hintKey: String { "audio.meter.hint." + state.rawValue }

    init(snapshot: CaptureSnapshot?, active: Bool) {
        guard active else { state = .inactive; peakDB = nil; rmsDB = nil; return }
        guard let snapshot, snapshot.totalFrames > 0, snapshot.invalidSamples == 0,
              snapshot.peak.isFinite, snapshot.peak >= 0, snapshot.rms.isFinite, snapshot.rms >= 0 else {
            state = .unavailable; peakDB = nil; rmsDB = nil; return
        }
        peakDB = snapshot.peak > 0 ? 20 * log10(Double(snapshot.peak)) : nil
        rmsDB = snapshot.rms > 0 ? 20 * log10(Double(snapshot.rms)) : nil
        if snapshot.peak >= Self.clippingAmplitude { state = .clipping }
        else if snapshot.peak >= Float(pow(10, Self.highDB / 20)) { state = .high }
        else if snapshot.peak >= Float(pow(10, Self.recommendedDB / 20)) { state = .good }
        else if snapshot.peak >= 0.001 { state = .weak }
        else { state = .silent }
    }

    static func fraction(for decibels: Double) -> Double {
        guard decibels.isFinite else { return 0 }
        return min(1, max(0, (decibels - floorDB) / -floorDB))
    }
}
