import Foundation
import Domain

/// Bounded aggregation of worker-produced observations; this object never consumes PCM.
public struct PracticeEvidenceCollector: Sendable {
    public let configuration: PracticeConfiguration
    public let analysisVersion: String
    public private(set) var attacks: [PracticeAttack] = []
    public private(set) var clipping: [PracticeClippingInterval] = []
    public private(set) var latestNormalizedTime: Double?
    private var lastEvent: UInt64
    private var lastSpan: UInt64
    private var clippingID: UInt64?

    public init(configuration: PracticeConfiguration, baseline: AudioAnalysisSnapshot) {
        self.configuration = configuration; analysisVersion = baseline.algorithmVersion
        lastEvent = baseline.totalEvents; lastSpan = baseline.totalQualitySpans
    }

    public mutating func consume(_ analysis: AudioAnalysisSnapshot, renderEpochSeconds: Double) throws {
        let route = configuration.route
        let window = try configuration.observationWindow(renderEpochSeconds: renderEpochSeconds)
        let offset = configuration.calibration?.residualOffsetSeconds ?? 0
        guard analysis.algorithmVersion == analysisVersion, analysis.invalidSamples == 0,
              analysis.totalEvents >= lastEvent, analysis.totalQualitySpans >= lastSpan else { throw AudioBackendError.dataLoss }
        let newEvents = analysis.events.filter { $0.id > lastEvent }
        let newSpans = analysis.qualitySpans.filter { $0.id > lastSpan }
        guard analysis.totalEvents - lastEvent == UInt64(newEvents.count),
              analysis.totalQualitySpans - lastSpan == UInt64(newSpans.count) else { throw AudioBackendError.dataLoss }
        if let latest = analysis.latest {
            guard let host = latest.time.hostSeconds else { throw AudioBackendError.invalidFormat }
            let time = try route.observedTime(inputHostSeconds: host)
            if let previous = latestNormalizedTime, time < previous { throw AudioBackendError.dataLoss }
            latestNormalizedTime = time
        }
        for event in newEvents {
            guard let host = event.onset.hostSeconds else { throw AudioBackendError.invalidFormat }
            let time = try route.observedTime(inputHostSeconds: host)
            guard window.contains(time - offset) else { continue }
            guard attacks.count < PracticeConfiguration.maximumObservations else { throw PracticeError.unsupportedSize }
            if let previous = attacks.last, time < previous.normalizedOnset { throw AudioBackendError.dataLoss }
            attacks.append(try PracticeAttack(id: event.id, normalizedOnset: time, frequency: event.pitch?.frequency,
                clarity: event.pitch?.clarity, reliable: event.quality == .reliable && event.pitch != nil))
        }
        // The current span's ID stays stable while its end grows. Update it instead of dropping its tail.
        for span in analysis.qualitySpans where span.id >= lastSpan && span.quality == .clipping {
            guard let rawStart = span.start.hostSeconds, let rawEnd = span.end.hostSeconds else { throw AudioBackendError.invalidFormat }
            let start = try route.observedTime(inputHostSeconds: rawStart), end = try route.observedTime(inputHostSeconds: rawEnd)
            guard start - offset < window.upperBound, end - offset >= window.lowerBound else { continue }
            let interval = try PracticeClippingInterval(start: max(start, window.lowerBound + offset), end: min(end, window.upperBound + offset))
            if clippingID == span.id, !clipping.isEmpty { clipping[clipping.count - 1] = interval }
            else {
                guard clipping.count < 4096 else { throw PracticeError.unsupportedSize }
                clipping.append(interval); clippingID = span.id
            }
        }
        lastEvent = analysis.totalEvents; lastSpan = analysis.totalQualitySpans
    }

    public func hasResolvedTail(renderEpochSeconds: Double) throws -> Bool {
        guard let latestNormalizedTime else { return false }
        let offset = configuration.calibration?.residualOffsetSeconds ?? 0
        return latestNormalizedTime - offset >= (try configuration.expectedEnd(renderEpochSeconds: renderEpochSeconds))
            + PracticeConfiguration.edgeGuardSeconds + PracticeConfiguration.resolutionAllowanceSeconds
    }
}
