import Foundation
import Audio
import Domain

struct CalibrationFailure: Error, Equatable {
    enum Reason: String {
        case noSignal, weakSignal, unstableSignal, wrongPitch, clipping, dataLoss, clockUnavailable, clockDrift
        case uncertainNotes, wrongNotes, timestamps, count, timingWindow, spread, drift, disagreement, unknown
    }
    let reason: Reason
    var messageKey: String { "sync.failure." + reason.rawValue }
}

/// Ephemeral, bounded measurements retained after capture stops; contains no audio or saved calibration.
struct CalibrationDiagnostics {
    let passNumber: Int
    let targetFrequency: Double
    var phase = CalibrationModel.Stage.signal
    var maximumPeak: Float = 0
    var lastFrequency: Double?
    var measuredAttacks: Int?
    var matchingAttacks = 0
    var wrongAttacks = 0
    var uncertainAttacks = 0
    var timing: PersonalSyncPassAnalysis?
    var clockDrift: Double?
    var betweenPassDifference: Double?
    var peakDB: Double? { maximumPeak > 0 ? 20 * log10(Double(maximumPeak)) : nil }

    mutating func observe(_ capture: CaptureSnapshot?) {
        guard let capture else { return }
        if capture.peak.isFinite { maximumPeak = max(maximumPeak, capture.peak) }
        if let pitch = capture.analysis?.latest?.pitch, pitch.frequency.isFinite, pitch.frequency > 0 {
            lastFrequency = pitch.frequency
        }
    }
    var signalFailure: CalibrationFailure {
        if maximumPeak < 0.001 { return .init(reason: .noSignal) }
        if let lastFrequency, abs(1200 * log2(lastFrequency / targetFrequency)) > 50 { return .init(reason: .wrongPitch) }
        if maximumPeak < Float(pow(10, -30.0 / 20)) { return .init(reason: .weakSignal) }
        return .init(reason: .unstableSignal)
    }
    mutating func analyze(events: [DetectedNoteEvent], expected: [Double], route: CalibrationRoute) throws -> [Double] {
        guard expected.count == 16 else { throw CalibrationFailure(reason: .timestamps) }
        var observed: [Double] = []
        measuredAttacks = 0; matchingAttacks = 0; wrongAttacks = 0; uncertainAttacks = 0
        for event in events {
            guard let host = event.onset.hostSeconds, host.isFinite, host >= 0 else { throw CalibrationFailure(reason: .timestamps) }
            let time = try route.observedTime(inputHostSeconds: host)
            observed.append(time)
            guard time >= expected[0] - 0.45, time <= expected[15] + 0.45 else { continue }
            measuredAttacks! += 1
            guard event.quality == .reliable, let pitch = event.pitch, pitch.clarity.isFinite, pitch.clarity >= 0.9,
                  pitch.frequency.isFinite, pitch.frequency > 0 else { uncertainAttacks += 1; continue }
            if abs(1200 * log2(pitch.frequency / targetFrequency)) <= 50 { matchingAttacks += 1 }
            else { wrongAttacks += 1 }
        }
        return observed
    }
    var noteFailure: CalibrationFailure? {
        if wrongAttacks > 0 { return .init(reason: .wrongNotes) }
        if uncertainAttacks > 0 { return .init(reason: .uncertainNotes) }
        return nil
    }
}
