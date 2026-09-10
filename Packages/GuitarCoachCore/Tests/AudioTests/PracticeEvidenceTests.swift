import Foundation
import Testing
import Domain
@testable import Audio

struct PracticeEvidenceTests {
    private func configuration() throws -> PracticeConfiguration {
        let endpoint = try CalibrationEndpoint(uid: "test", channel: 1, sampleRate: 48000, bufferFrames: 512,
            deviceLatencyFrames: 480, streamLatencyFrames: 0)
        return try PracticeConfiguration(exercise: Exercise(id: "test", events: [
            MusicalEvent(id: "first", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)]),
            MusicalEvent(id: "last", startTick: 2880, durationTicks: 960, kind: .note, positions: [FretPosition(string: 1, fret: 0)])]),
            instrument: InstrumentProfile(), bpm: 60, route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test"))
    }
    private func time(_ host: Double) -> AnalysisTimestamp {
        AnalysisTimestamp(frame: Int64((host - 100) * 48000), sampleRate: 48000, hostSeconds: host)
    }
    private func event(_ id: UInt64, _ host: Double) -> DetectedNoteEvent {
        DetectedNoteEvent(id: id, onset: time(host), resolvedAt: time(host + 0.25), quality: .reliable,
            pitch: DetectedPitch(frequency: 82.4, clarity: 0.99))
    }
    private func snapshot(events: [DetectedNoteEvent] = [], total: UInt64? = nil, latest: Double = 100,
                          spans: [SignalQualitySpan] = [], spanTotal: UInt64? = nil) -> AudioAnalysisSnapshot {
        AudioAnalysisSnapshot(algorithmVersion: MonophonicAnalyzer.algorithmVersion,
            latest: PitchObservation(time: time(latest), quality: .silence, pitch: nil, rms: 0, peak: 0, noiseFloor: 0, periodEvidence: nil),
            events: events, totalEvents: total ?? UInt64(events.count), invalidSamples: 0,
            qualitySpans: spans, totalQualitySpans: spanTotal ?? UInt64(spans.count))
    }
    @Test func countInAndPostGuardAreExcludedButLastResolvedAttackRemains() throws {
        var collector = PracticeEvidenceCollector(configuration: try configuration(), baseline: snapshot())
        let value = snapshot(events: [event(1, 101), event(2, 104.02), event(3, 108.05), event(4, 108.2)], latest: 108.3)
        try collector.consume(value, renderEpochSeconds: 100)
        #expect(collector.attacks.map(\.id) == [2, 3])
        #expect(abs(collector.attacks[0].normalizedOnset - 104.01) < 1e-8)
        #expect(try !collector.hasResolvedTail(renderEpochSeconds: 100))
        try collector.consume(snapshot(events: value.events, latest: 108.5), renderEpochSeconds: 100)
        #expect(try collector.hasResolvedTail(renderEpochSeconds: 100))
        #expect(collector.attacks.count == 2)
        #expect(throws: AudioBackendError.dataLoss) {
            try collector.consume(snapshot(events: [event(6, 108.6)], total: 6, latest: 108.7), renderEpochSeconds: 100)
        }
    }
    @Test func observationLimitInterruptsInsteadOfGrowingWithoutBound() throws {
        var collector = PracticeEvidenceCollector(configuration: try configuration(), baseline: snapshot())
        for batch in 0..<20 {
            let notes = (1...100).map { index -> DetectedNoteEvent in
                let id = UInt64(batch * 100 + index)
                return event(id, 104.02 + Double(id) * 0.001)
            }
            try collector.consume(snapshot(events: notes, total: UInt64((batch + 1) * 100), latest: 107), renderEpochSeconds: 100)
        }
        let excess = (2001...2100).map { event(UInt64($0), 104.02 + Double($0) * 0.001) }
        #expect(throws: PracticeError.unsupportedSize) {
            try collector.consume(snapshot(events: excess, total: 2100, latest: 107), renderEpochSeconds: 100)
        }
        #expect(collector.attacks.count == PracticeConfiguration.maximumObservations)
    }
    @Test func growingClippingSpanUpdatesItsTailWithoutDuplicatingTheInterval() throws {
        var collector = PracticeEvidenceCollector(configuration: try configuration(), baseline: snapshot())
        let first = SignalQualitySpan(id: 1, quality: .clipping, start: time(103.7), end: time(104.1))
        try collector.consume(snapshot(latest: 104.1, spans: [first]), renderEpochSeconds: 100)
        let extended = SignalQualitySpan(id: 1, quality: .clipping, start: time(103.7), end: time(105))
        try collector.consume(snapshot(latest: 105, spans: [extended]), renderEpochSeconds: 100)
        #expect(collector.clipping.count == 1)
        #expect(abs(collector.clipping[0].start - 103.91) < 1e-8)
        #expect(abs(collector.clipping[0].end - 104.99) < 1e-8)
    }
    @Test func nonSilentUncertaintyGrowsButSilenceDoesNotBecomeBadSignal() throws {
        var collector = PracticeEvidenceCollector(configuration: try configuration(), baseline: snapshot())
        let first = SignalQualitySpan(id: 1, quality: .ambiguous, start: time(104), end: time(104.2))
        try collector.consume(snapshot(latest: 104.2, spans: [first]), renderEpochSeconds: 100)
        let extended = SignalQualitySpan(id: 1, quality: .ambiguous, start: time(104), end: time(104.6))
        let silent = SignalQualitySpan(id: 2, quality: .silence, start: time(104.6), end: time(105))
        try collector.consume(snapshot(latest: 105, spans: [extended, silent]), renderEpochSeconds: 100)
        #expect(collector.uncertainSignal.count == 1 && collector.clipping.isEmpty)
        #expect(collector.uncertainSignal[0].reason == .ambiguous)
        #expect(abs(collector.uncertainSignal[0].interval.end - 104.59) < 1e-8)
    }

    @Test func CombinedClippingAndUncertainIntervalsStopAtOneSharedBound() throws {
        var collector = PracticeEvidenceCollector(configuration: try configuration(), baseline: snapshot())
        func batch(_ lower: Int, _ upper: Int) -> AudioAnalysisSnapshot {
            var spans: [SignalQualitySpan] = []
            for index in lower...upper {
                let quality: SignalQuality = index % 2 == 0 ? .clipping : .ambiguous
                let start = time(104 + Double(index) * 0.0005)
                let end = time(104 + Double(index + 1) * 0.0005)
                spans.append(SignalQualitySpan(id: UInt64(index), quality: quality, start: start, end: end))
            }
            return snapshot(latest: 107, spans: spans, spanTotal: UInt64(upper))
        }
        for index in 0..<20 {
            try collector.consume(batch(index * 200 + 1, (index + 1) * 200), renderEpochSeconds: 100)
        }
        #expect(throws: PracticeError.unsupportedSize) {
            try collector.consume(batch(4001, 4200), renderEpochSeconds: 100)
        }
        // The collector visits clipping before uncertainty within a publication.
        // Both categories share the cap; overflow need not divide it equally.
        #expect(collector.clipping.count + collector.uncertainSignal.count == 4096)
        #expect(collector.clipping.count >= 2000 && collector.uncertainSignal.count >= 2000)
    }

}
