import Foundation
import Domain

/// Bounded aggregation of worker-produced observations; this object never consumes PCM.
public struct PracticeEvidenceCollector: Sendable {
    public let configuration: PracticeConfiguration
    public let analysisVersion: String
    public private(set) var attacks: [PracticeAttack] = []
    public private(set) var clipping: [PracticeClippingInterval] = []
    public private(set) var uncertainSignal: [PracticeUncertainSpan] = []
    public private(set) var latestNormalizedTime: Double?
    public private(set) var sustainFrames: [SustainFrame] = []
    public private(set) var contourFrames: [SustainFrame] = []
    private let collectsContour: Bool
    private var lastContourFrame: UInt64
    private let collectsSustain: Bool
    private var lastSustainFrame: UInt64
    private var lastEvent: UInt64
    private var lastSpan: UInt64
    private var clippingID: UInt64?
    private var uncertainID: UInt64?

    public init(configuration: PracticeConfiguration, baseline: AudioAnalysisSnapshot) {
        self.configuration = configuration; analysisVersion = baseline.algorithmVersion
        lastEvent = baseline.totalEvents; lastSpan = baseline.totalQualitySpans
        collectsSustain = configuration.selectedEvents.contains(where: \.assessSustain)
        lastSustainFrame = baseline.sustainTrace?.totalFrames ?? 0
        collectsContour = configuration.selectedEvents.contains { $0.bend != nil || $0.pitchTransition != nil || $0.vibrato != nil || $0.legatoChain != nil }
        lastContourFrame = baseline.pitchContour?.totalFrames ?? 0
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
                guard clipping.count + uncertainSignal.count < 4096 else { throw PracticeError.unsupportedSize }
                clipping.append(interval); clippingID = span.id
            }
        }
        for span in analysis.qualitySpans where span.id >= lastSpan {
            guard let reason = PracticeUncertainSpan.Reason(rawValue: span.quality.rawValue) else { continue }
            guard let rawStart = span.start.hostSeconds, let rawEnd = span.end.hostSeconds else { throw AudioBackendError.invalidFormat }
            let start = try route.observedTime(inputHostSeconds: rawStart), end = try route.observedTime(inputHostSeconds: rawEnd)
            guard start - offset < window.upperBound, end - offset >= window.lowerBound else { continue }
            let interval = try PracticeClippingInterval(start: max(start, window.lowerBound + offset), end: min(end, window.upperBound + offset))
            let value = PracticeUncertainSpan(interval: interval, reason: reason)
            if uncertainID == span.id, !uncertainSignal.isEmpty { uncertainSignal[uncertainSignal.count - 1] = value }
            else {
                guard clipping.count + uncertainSignal.count < 4096 else { throw PracticeError.unsupportedSize }
                uncertainSignal.append(value); uncertainID = span.id
            }
        }
        lastEvent = analysis.totalEvents; lastSpan = analysis.totalQualitySpans
        if collectsSustain {
            guard let trace = analysis.sustainTrace, trace.version == SustainTrace.currentVersion,
                  trace.totalFrames >= lastSustainFrame else { throw AudioBackendError.dataLoss }
            let frames = trace.frames.filter { $0.id > lastSustainFrame }
            guard trace.totalFrames - lastSustainFrame == UInt64(frames.count) else { throw AudioBackendError.dataLoss }
            for frame in frames {
                guard let host = frame.time.hostSeconds else { throw AudioBackendError.invalidFormat }
                let time = try route.observedTime(inputHostSeconds: host)
                guard time - offset >= window.lowerBound,
                      time - offset < window.upperBound + PracticeConfiguration.resolutionAllowanceSeconds else { continue }
                guard sustainFrames.count < SustainTrace.maximumFrames else { throw PracticeError.unsupportedSize }
                if let previous = sustainFrames.last {
                    guard previous.id < UInt64.max, frame.id == previous.id + 1,
                          (0.018...0.022).contains(time - previous.normalizedTime) else { throw AudioBackendError.dataLoss }
                }
                sustainFrames.append(try SustainFrame(id: frame.id, normalizedTime: time, state: frame.state, frequency: frame.frequency))
            }
            lastSustainFrame = trace.totalFrames
        }
        if collectsContour {
            guard let trace = analysis.pitchContour, trace.version == PitchContourTrace.currentVersion,
                  trace.totalFrames >= lastContourFrame else { throw AudioBackendError.dataLoss }
            let frames = trace.frames.filter { $0.id > lastContourFrame }
            guard trace.totalFrames - lastContourFrame == UInt64(frames.count) else { throw AudioBackendError.dataLoss }
            for frame in frames {
                guard let host = frame.time.hostSeconds else { throw AudioBackendError.invalidFormat }
                let time = try route.observedTime(inputHostSeconds: host)
                guard time - offset >= window.lowerBound,
                      time - offset < window.upperBound + PracticeConfiguration.resolutionAllowanceSeconds else { continue }
                guard contourFrames.count < PitchContourTrace.maximumFrames else { throw PracticeError.unsupportedSize }
                if let previous = contourFrames.last {
                    guard previous.id < UInt64.max, frame.id == previous.id + 1,
                          (0.018...0.022).contains(time - previous.normalizedTime) else { throw AudioBackendError.dataLoss }
                }
                contourFrames.append(try SustainFrame(id: frame.id, normalizedTime: time, state: frame.state, frequency: frame.frequency))
            }
            lastContourFrame = trace.totalFrames
        }
    }

    public func pitchContourTrace() throws -> PitchContourTrace? {
        collectsContour ? try PitchContourTrace(frames: contourFrames) : nil
    }

    public func sustainTrace() throws -> SustainTrace? {
        collectsSustain ? try SustainTrace(frames: sustainFrames) : nil
    }

    public func hasResolvedTail(renderEpochSeconds: Double) throws -> Bool {
        guard let latestNormalizedTime else { return false }
        let offset = configuration.calibration?.residualOffsetSeconds ?? 0
        return latestNormalizedTime - offset >= (try configuration.expectedEnd(renderEpochSeconds: renderEpochSeconds))
            + PracticeConfiguration.edgeGuardSeconds + PracticeConfiguration.resolutionAllowanceSeconds
    }
}
