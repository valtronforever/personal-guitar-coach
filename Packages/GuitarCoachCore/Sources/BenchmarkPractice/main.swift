import Foundation
import Darwin
import Domain
import Audio
import Learning
import Persistence

enum ValidationFailure: Error { case invariant(String), arguments }
func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ValidationFailure.invariant(message) }
}

struct SoakReport: Encodable {
    let mode = "accelerated-synthetic-events"
    let schemaVersion = 1
    let simulatedPracticeSeconds = 900
    let inputPCMProcessed = false
    let deviceCapturePerformed = false
    let physicalClockDriftMeasured = false
    let callbackUnderrunsMeasured = false
    let snapshots: Int
    let expectedNotes: Int
    let collectedAttacks: Int
    let collectedUncertainIntervals: Int
    let maximumRollingEvents: Int
    let maximumRollingQualitySpans: Int
    let firstOverallScore: Double
    let secondAttemptAttacks: Int
    let restoredRecords: Int
    let encodedFirstResultBytes: Int
    let collectorWallSeconds: Double
    let assessmentWallSeconds: Double
    let feedbackWallSeconds: Double
    let totalWallSeconds: Double
    let processCPUSeconds: Double
    let processPeakResidentBytes: Int64
    let memoryScope = "Darwin process high-water RSS, including Swift/runtime; not a leak or real-time hardware measurement"
}

@main struct BenchmarkPractice {
    static func timestamp(_ host: Double) -> AnalysisTimestamp {
        AnalysisTimestamp(frame: Int64(((host - 100) * 48000).rounded()), sampleRate: 48000, hostSeconds: host)
    }
    static func elapsed(_ start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("Usage: BenchmarkPractice output.json\nThis is accelerated synthetic event validation, not audio capture.\n".utf8))
            throw ValidationFailure.arguments
        }
        let begin = ContinuousClock.now
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("coach-soak-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var events: [MusicalEvent] = []
        for index in 0..<900 {
            events.append(try MusicalEvent(id: "n\(index)", startTick: Int64(index) * 960, durationTicks: 960,
                kind: .note, positions: [FretPosition(string: 6, fret: index % 5)]))
        }
        let exercise = try Exercise(id: "synthetic-soak", events: events)
        let endpoint = try CalibrationEndpoint(uid: "synthetic-soak", channel: 1, sampleRate: 48000, bufferFrames: 512,
            deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "synthetic-events-1")
        let profile = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0.05, uncertaintySeconds: 0.015,
            evidence: CalibrationEvidence(algorithmVersion: "synthetic-pulses", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 900, residualP95Seconds: 0.005, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60,
            route: route, calibration: profile, lesson: PracticeLessonReference(id: "synthetic-soak", version: 1))
        var recentEvents: [DetectedNoteEvent] = [], spans: [SignalQualitySpan] = []
        var eventCount: UInt64 = 0, spanCount: UInt64 = 0
        func snapshot(_ host: Double) -> AudioAnalysisSnapshot {
            AudioAnalysisSnapshot(algorithmVersion: "synthetic-events-1",
                latest: PitchObservation(time: timestamp(host), quality: spans.last?.quality ?? .silence, pitch: nil,
                    rms: 0, peak: 0, noiseFloor: 0, periodEvidence: nil),
                events: recentEvents, totalEvents: eventCount, invalidSamples: 0,
                qualitySpans: spans, totalQualitySpans: spanCount)
        }
        var collector = PracticeEvidenceCollector(configuration: config, baseline: snapshot(100))
        var maximumEvents = 0, maximumSpans = 0, snapshotCount = 0
        let collectStart = ContinuousClock.now
        // Fifty publications per virtual second, with rolling windows matching the production DTO bounds.
        for sample in 0...45230 {
            let host = 100 + Double(sample) / 50
            while eventCount < 900 && 104.05 + Double(eventCount) + 0.25 <= host {
                let index = Int(eventCount), onset = 104.05 + Double(index)
                let pitch = try TuningProfile.standard.frequency(at: events[index].positions[0])
                eventCount += 1
                recentEvents.append(DetectedNoteEvent(id: eventCount, onset: timestamp(onset), resolvedAt: timestamp(onset + 0.25),
                    quality: .reliable, pitch: DetectedPitch(frequency: pitch, clarity: 0.99)))
                if recentEvents.count > 128 { recentEvents.removeFirst() }
            }
            let within = host - 104.05
            let fraction = within - floor(within)
            let quality: SignalQuality
            if within < 0 || within >= 900 { quality = .silence }
            else if fraction < 0.1 { quality = .warmingUp }
            else if fraction < 0.6 { quality = .reliable }
            else { quality = .silence }
            if let last = spans.last, last.quality == quality {
                spans[spans.count - 1] = SignalQualitySpan(id: last.id, quality: quality, start: last.start, end: timestamp(host))
            } else {
                spanCount += 1
                spans.append(SignalQualitySpan(id: spanCount, quality: quality, start: timestamp(host), end: timestamp(host)))
                if spans.count > 256 { spans.removeFirst() }
            }
            maximumEvents = max(maximumEvents, recentEvents.count); maximumSpans = max(maximumSpans, spans.count)
            try collector.consume(snapshot(host), renderEpochSeconds: 100)
            snapshotCount += 1
        }
        let collectorSeconds = elapsed(collectStart)
        try require(collector.attacks.count == 900 && collector.clipping.isEmpty, "900 attacks without clipping")
        try require(collector.uncertainSignal.count == 900, "One bounded settling interval per note")
        try require(collector.hasResolvedTail(renderEpochSeconds: 100), "Final resolved tail")
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 0),
            finishedAt: Date(timeIntervalSince1970: 905), phase: .completed, reason: nil, signalConfirmed: true,
            renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: collector.attacks, clipping: collector.clipping,
            uncertainSignal: collector.uncertainSignal, analysisVersion: collector.analysisVersion)
        let assessStart = ContinuousClock.now
        let assessment = try AssessmentEngine.evaluate(evidence)
        let assessmentSeconds = elapsed(assessStart)
        try require(assessment.overallScore == 100 && assessment.validity == .valid, "Perfect compensated synthetic result")
        let feedbackStart = ContinuousClock.now
        let advice = FeedbackEngine.recommendations(for: assessment)
        let feedbackSeconds = elapsed(feedbackStart)
        try require(advice.count == 1 && advice[0].kind == .repeatFragment && advice[0].bpm == 60, "Neutral comparable repeat")

        // A new collector begins after the old IDs, even though its rolling baseline still contains old events.
        var next = PracticeEvidenceCollector(configuration: config, baseline: snapshot(1004.6))
        try next.consume(snapshot(1004.6), renderEpochSeconds: 1004.6)
        try require(next.attacks.isEmpty && next.uncertainSignal.isEmpty, "No cross-attempt evidence")
        eventCount += 1
        let newOnset = 1008.65
        recentEvents.append(DetectedNoteEvent(id: eventCount, onset: timestamp(newOnset), resolvedAt: timestamp(newOnset + 0.25),
            quality: .reliable, pitch: DetectedPitch(frequency: try TuningProfile.standard.frequency(at: events[0].positions[0]), clarity: 0.99)))
        recentEvents.removeFirst()
        try next.consume(snapshot(1009), renderEpochSeconds: 1004.6)
        try require(next.attacks.count == 1 && next.attacks[0].id == 901, "Fresh attempt captures only its new attack")
        let partial = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 905),
            finishedAt: Date(timeIntervalSince1970: 910), phase: .paused, reason: .paused, signalConfirmed: true,
            renderEpochSeconds: 1004.6, maximumClockDriftSeconds: 0, attacks: next.attacks, clipping: [], analysisVersion: next.analysisVersion)
        let second = try AssessmentEngine.evaluate(partial)
        try require(second.validity == .interrupted && second.overallScore == nil, "Partial attempt remains unscored")
        let repository = LocalRepository(root: directory)
        let firstRecord = try PracticeRecord(assessment: assessment), secondRecord = try PracticeRecord(assessment: second)
        try await repository.save(firstRecord); try await repository.save(secondRecord)
        let restored = try await LocalRepository(root: directory).history()
        try require(restored.issues.isEmpty && restored.records.count == 2 && restored.records.contains(firstRecord) && restored.records.contains(secondRecord), "Immutable history round trip")
        let encodedSize = try JSONEncoder().encode(assessment).count
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        let report = SoakReport(snapshots: snapshotCount, expectedNotes: 900, collectedAttacks: collector.attacks.count,
            collectedUncertainIntervals: collector.uncertainSignal.count, maximumRollingEvents: maximumEvents,
            maximumRollingQualitySpans: maximumSpans, firstOverallScore: assessment.overallScore ?? -1,
            secondAttemptAttacks: next.attacks.count, restoredRecords: restored.records.count, encodedFirstResultBytes: encodedSize,
            collectorWallSeconds: collectorSeconds, assessmentWallSeconds: assessmentSeconds, feedbackWallSeconds: feedbackSeconds,
            totalWallSeconds: elapsed(begin), processCPUSeconds: cpu, processPeakResidentBytes: Int64(usage.ru_maxrss))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
        print(String(decoding: data, as: UTF8.self))
    }
}
