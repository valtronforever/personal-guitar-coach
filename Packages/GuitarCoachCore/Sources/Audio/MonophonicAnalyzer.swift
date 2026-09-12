import Domain
import Foundation

public enum SignalQuality: String, Codable, Sendable {
    case warmingUp, silence, quiet, unstable, reliable, clipping, ambiguous, outOfRange, invalid
}

public struct DetectedPitch: Equatable, Codable, Sendable {
    public let frequency: Double
    public let clarity: Double
    public init(frequency: Double, clarity: Double) { self.frequency = frequency; self.clarity = clarity }
    public func nearestPitch(referenceA4: Double = 440) throws -> Pitch { try .nearest(to: frequency, referenceA4: referenceA4) }
    public func cents(referenceA4: Double = 440) throws -> Double {
        try nearestPitch(referenceA4: referenceA4).cents(from: frequency, referenceA4: referenceA4)
    }
}

public struct AnalysisTimestamp: Equatable, Codable, Sendable {
    /// Relative to this analyzer/capture generation, never a device-global sample counter.
    public let frame: Int64
    public let sampleRate: Double
    /// First input packet host timestamp plus stream-frame offset. Hardware latency is not subtracted here.
    public let hostSeconds: Double?
    public init(frame: Int64, sampleRate: Double, hostSeconds: Double?) {
        self.frame = frame; self.sampleRate = sampleRate; self.hostSeconds = hostSeconds
    }
    public var streamSeconds: Double { Double(frame) / sampleRate }
}

public struct PitchObservation: Equatable, Codable, Sendable {
    public let time: AnalysisTimestamp
    public let quality: SignalQuality
    public let pitch: DetectedPitch?
    public let rms: Double
    public let peak: Double
    public let noiseFloor: Double
    public let periodEvidence: PeriodEstimate?
    public init(time: AnalysisTimestamp, quality: SignalQuality, pitch: DetectedPitch?, rms: Double, peak: Double,
                noiseFloor: Double, periodEvidence: PeriodEstimate?) {
        self.time = time; self.quality = quality; self.pitch = pitch; self.rms = rms; self.peak = peak
        self.noiseFloor = noiseFloor; self.periodEvidence = periodEvidence
    }
}

public struct DetectedNoteEvent: Equatable, Codable, Sendable, Identifiable {
    public let id: UInt64
    public let onset: AnalysisTimestamp
    public let resolvedAt: AnalysisTimestamp
    public let quality: SignalQuality
    public let pitch: DetectedPitch?
    public init(id: UInt64, onset: AnalysisTimestamp, resolvedAt: AnalysisTimestamp, quality: SignalQuality, pitch: DetectedPitch?) {
        self.id = id; self.onset = onset; self.resolvedAt = resolvedAt; self.quality = quality; self.pitch = pitch
    }
}

public struct SignalQualitySpan: Equatable, Codable, Sendable, Identifiable {
    public let id: UInt64
    public let quality: SignalQuality
    public let start: AnalysisTimestamp
    public let end: AnalysisTimestamp
    public init(id: UInt64, quality: SignalQuality, start: AnalysisTimestamp, end: AnalysisTimestamp) {
        self.id = id; self.quality = quality; self.start = start; self.end = end
    }
}

public struct AudioAnalysisSnapshot: Equatable, Sendable {
    public let algorithmVersion: String
    public let latest: PitchObservation?
    /// Rolling bounded history; consumers compare event IDs and must reject a skipped prefix.
    public let events: [DetectedNoteEvent]
    public let totalEvents: UInt64
    public let invalidSamples: UInt64
    public let qualitySpans: [SignalQualitySpan]
    public let totalQualitySpans: UInt64
    /// Immutable worker DTO construction also supports offline fixtures without a capture runtime.
    public init(algorithmVersion: String, latest: PitchObservation?, events: [DetectedNoteEvent], totalEvents: UInt64,
                invalidSamples: UInt64, qualitySpans: [SignalQualitySpan], totalQualitySpans: UInt64) {
        self.algorithmVersion = algorithmVersion; self.latest = latest; self.events = events; self.totalEvents = totalEvents
        self.invalidSamples = invalidSamples; self.qualitySpans = qualitySpans; self.totalQualitySpans = totalQualitySpans
    }
}

/// Single-worker streaming analyzer. The audio callback only fills the existing bounded PCM ring.
/// All storage is bounded independently of session length; no raw PCM leaves this object.
public final class MonophonicAnalyzer {
    public static let algorithmVersion = "mono-mpm-flux-3"
    public static let eventCapacity = 128
    public static let qualitySpanCapacity = 256
    public let sampleRate: Double
    public let hopFrames: Int
    private let detector: PitchDetector
    private let onsetDetector: OnsetDetector
    private var ring = [Float](repeating: 0, count: PitchDetector.windowFrames)
    private var rawRing = [Float](repeating: 0, count: PitchDetector.windowFrames)
    private var frame = [Float](repeating: 0, count: PitchDetector.windowFrames)
    private var head = 0
    private var hopCount = 0
    private var processed: Int64 = 0
    private var originHostSeconds: Double?
    private var pendingOnset: Int64?
    private var eventPitchCandidates: [DetectedPitch] = []
    private var previousFrequency: Double?
    private var stableFrames = 0
    private var noiseFloor = 0.0003
    private var invalidSamples: UInt64 = 0
    private var latest: PitchObservation?
    private var events: [DetectedNoteEvent] = []
    private var totalEvents: UInt64 = 0
    private var qualitySpans: [SignalQualitySpan] = []
    private var totalQualitySpans: UInt64 = 0
    private var hopSquares = 0.0
    private let highPassCoefficient: Double
    private var previousInput = 0.0, firstHighPass = 0.0, secondHighPass = 0.0

    public init(sampleRate: Double, method: PitchMethod = .mpm) throws {
        self.sampleRate = sampleRate
        detector = try PitchDetector(sampleRate: sampleRate, method: method)
        onsetDetector = try OnsetDetector(sampleRate: sampleRate)
        hopFrames = Int(sampleRate / 100)
        highPassCoefficient = exp(-2 * .pi * 30 / sampleRate)
        eventPitchCandidates.reserveCapacity(5)
        events.reserveCapacity(Self.eventCapacity)
        qualitySpans.reserveCapacity(Self.qualitySpanCapacity)
    }

    /// The optional host time belongs to the first sample of this chunk, not its delivery time.
    public func process(_ samples: UnsafeBufferPointer<Float>, startHostSeconds: Double? = nil,
                        observe: ((PitchObservation) -> Void)? = nil) {
        if originHostSeconds == nil, let startHostSeconds, startHostSeconds.isFinite {
            originHostSeconds = startHostSeconds - Double(processed) / sampleRate
        }
        for sample in samples {
            let value: Float
            if sample.isFinite { value = sample } else { value = 0; invalidSamples += 1 }
            rawRing[head] = value
            let bounded = Double(max(-1, min(1, value)))
            let first = highPassCoefficient * (firstHighPass + bounded - previousInput)
            secondHighPass = highPassCoefficient * (secondHighPass + first - firstHighPass)
            previousInput = bounded; firstHighPass = first
            ring[head] = Float(secondHighPass); head = (head + 1) % ring.count
            processed += 1; hopCount += 1; hopSquares += secondHighPass * secondHighPass
            if hopCount == hopFrames {
                analyze(hopRMS: (hopSquares / Double(hopFrames)).squareRoot())
                if let latest { observe?(latest) }
                hopCount = 0; hopSquares = 0
            }
        }
    }

    public func snapshot() -> AudioAnalysisSnapshot {
        AudioAnalysisSnapshot(algorithmVersion: "mono-\(detector.method.rawValue)-flux-3", latest: latest, events: events,
                              totalEvents: totalEvents, invalidSamples: invalidSamples,
                              qualitySpans: qualitySpans, totalQualitySpans: totalQualitySpans)
    }

    /// Offline/session finalization preserves an attack that never yielded a stable estimate.
    public func finish() {
        if let onset = pendingOnset { emit(onset: onset, quality: latest?.quality == .reliable ? .unstable : latest?.quality ?? .unstable, pitch: nil) }
    }

    private func timestamp(_ frame: Int64) -> AnalysisTimestamp {
        AnalysisTimestamp(frame: frame, sampleRate: sampleRate,
                          hostSeconds: originHostSeconds.map { $0 + Double(frame) / sampleRate })
    }

    private func analyze(hopRMS: Double) {
        var squares = 0.0, peak = 0.0
        for i in frame.indices {
            let value = ring[(head + i) % ring.count]
            frame[i] = value; squares += Double(value) * Double(value); peak = max(peak, Double(abs(rawRing[(head + i) % ring.count])))
        }
        let rms = (squares / Double(frame.count)).squareRoot()
        if let onset = onsetDetector.process(frame: frame, endFrame: processed, hop: hopFrames, rms: hopRMS, noiseFloor: noiseFloor) {
            if let previous = pendingOnset { emit(onset: previous, quality: .unstable, pitch: nil) }
            pendingOnset = onset; eventPitchCandidates.removeAll(keepingCapacity: true); stableFrames = 0; previousFrequency = nil
        }
        var quality: SignalQuality = .unstable
        var pitch: DetectedPitch?
        var evidence: PeriodEstimate?
        var trackedPeriod = false
        if invalidSamples > 0 { quality = .invalid }
        else if peak >= 0.995 { quality = .clipping }
        else if hopRMS < 0.001 && rms < 0.001 { quality = .silence }
        else if processed < frame.count { quality = .warmingUp }
        else if rms < max(0.0015, noiseFloor * 3) { quality = .quiet }
        else if let estimate = frame.withUnsafeBufferPointer({ detector.estimate($0) }) {
            evidence = estimate
            if estimate.octaveAmbiguous || estimate.fundamentalFraction < 0.001 { quality = .ambiguous }
            // Observe one semitone below the lowest target so A1 can be tuned from flat.
            // This does not expand the target/assessment capability or snap measured pitch.
            else if !(MonophonicCapability.frequencyRange.lowerBound / pow(2, 1.0 / 12)...MonophonicCapability.frequencyRange.upperBound).contains(estimate.frequency) { quality = .outOfRange }
            else if estimate.clarity < 0.9 { quality = .unstable }
            else {
                trackedPeriod = true
                let settled = previousFrequency.map { abs(1200 * log2(estimate.frequency / $0)) <= 15 } ?? false
                stableFrames = settled ? stableFrames + 1 : 1
                previousFrequency = estimate.frequency
                if stableFrames >= 3, pendingOnset == nil || processed - Int64(frame.count) >= pendingOnset! {
                    quality = .reliable; pitch = DetectedPitch(frequency: estimate.frequency, clarity: estimate.clarity)
                }
            }
        }
        if !trackedPeriod { stableFrames = 0; previousFrequency = nil }
        // Learn the quiet background only. Loud noise cannot raise a gate until it hides a guitar.
        if rms < 0.003 { noiseFloor = max(0.0001, min(0.001, noiseFloor * 0.98 + rms * 0.02)) }
        latest = PitchObservation(time: timestamp(processed), quality: quality, pitch: pitch, rms: rms, peak: peak, noiseFloor: noiseFloor,
                                  periodEvidence: evidence)
        if let last = qualitySpans.last, last.quality == quality {
            qualitySpans[qualitySpans.count - 1] = SignalQualitySpan(id: last.id, quality: quality, start: last.start, end: timestamp(processed))
        } else {
            totalQualitySpans += 1
            if qualitySpans.count == Self.qualitySpanCapacity { qualitySpans.removeFirst() }
            qualitySpans.append(SignalQualitySpan(id: totalQualitySpans, quality: quality,
                start: timestamp(processed - Int64(hopFrames)), end: timestamp(processed)))
        }
        if let onset = pendingOnset {
            // Confirm five post-onset, stable pitch frames and use their median. A
            // single early periodic window can still contain a transient octave/glide.
            if quality == .reliable, stableFrames >= 5, processed - Int64(frame.count) >= onset, let pitch {
                if let previous = eventPitchCandidates.last, abs(1200 * log2(pitch.frequency / previous.frequency)) > 15 {
                    eventPitchCandidates.removeAll(keepingCapacity: true)
                }
                eventPitchCandidates.append(pitch)
                if eventPitchCandidates.count == 5 {
                    let frequency = eventPitchCandidates.map(\.frequency).sorted()[2]
                    let clarity = eventPitchCandidates.map(\.clarity).min() ?? 0
                    emit(onset: onset, quality: .reliable, pitch: DetectedPitch(frequency: frequency, clarity: clarity))
                }
            } else { eventPitchCandidates.removeAll(keepingCapacity: true) }
            if pendingOnset != nil && Double(processed - onset) / sampleRate >= 0.3 {
                emit(onset: onset, quality: quality == .reliable ? .unstable : quality, pitch: nil)
            }
        }
    }

    private func emit(onset: Int64, quality: SignalQuality, pitch: DetectedPitch?) {
        totalEvents += 1
        if events.count == Self.eventCapacity { events.removeFirst() }
        events.append(DetectedNoteEvent(id: totalEvents, onset: timestamp(onset), resolvedAt: timestamp(processed), quality: quality, pitch: pitch))
        pendingOnset = nil; eventPitchCandidates.removeAll(keepingCapacity: true)
    }
}
