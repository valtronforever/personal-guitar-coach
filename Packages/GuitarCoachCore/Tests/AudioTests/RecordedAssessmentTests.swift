import Foundation
import AVFAudio
import Testing
import Domain
import Learning
@testable import Audio

struct RecordedAssessmentTests {
    private struct Corpus: Decodable {
        struct Clip: Decodable { let file: String; let sampleRate: Double; let nominalMIDI: Int; let referenceHz: Double; let onsetSeconds: Double? }
        let clips: [Clip]
    }
    @Test func publicAnnotatedAcousticNotesTraverseAnalyzerCollectorAndEvaluator() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tests/Fixtures/Audio")
        let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        #expect(corpus.clips.count == 34)
        #expect(corpus.clips.filter { $0.onsetSeconds != nil }.count == 32)
        var scored = 0, uncertainExtras = 0
        for clip in corpus.clips {
            guard let onsetSeconds = clip.onsetSeconds else { continue }
            if let filter = ProcessInfo.processInfo.environment["COACH_ASSESSMENT_CLIP"], !clip.file.contains(filter) { continue }
            let file = try AVAudioFile(forReading: root.appendingPathComponent(clip.file), commonFormat: .pcmFormatFloat32, interleaved: false)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let samples = Array(UnsafeBufferPointer(start: try #require(buffer.floatChannelData?[0]), count: Int(buffer.frameLength)))
            let rate = clip.sampleRate
            let endpoint = try CalibrationEndpoint(uid: "offline", channel: 1, sampleRate: rate, bufferFrames: 512,
                deviceLatencyFrames: 0, streamLatencyFrames: 0)
            let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "offline-public-corpus")
            let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0,
                uncertaintySeconds: 0.015, evidence: CalibrationEvidence(algorithmVersion: "synthetic-fixture-calibration",
                    matchedPulses: 12, missedPulses: 0, extraPulses: 0, durationSeconds: 25, residualP95Seconds: 0.005, driftSeconds: 0))
            let string = clip.nominalMIDI < 59 ? 6 : clip.nominalMIDI == 59 ? 2 : 1
            let open = string == 6 ? 40 : string == 2 ? 59 : 64
            let event = try MusicalEvent(id: "recorded-note", startTick: 0, durationTicks: 960, kind: .note,
                positions: [FretPosition(string: string, fret: clip.nominalMIDI - open)])
            let config = try PracticeConfiguration(exercise: Exercise(id: clip.file, events: [event]), instrument: InstrumentProfile(),
                bpm: 60, route: route, calibration: calibration)
            let analyzer = try MonophonicAnalyzer(sampleRate: rate)
            var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
            // Align the independently annotated onset with the expected first note. No detected-pitch alignment is used.
            let leading = Int(((config.countInSeconds - onsetSeconds) * rate).rounded())
            let signal = [Float](repeating: 0, count: leading) + samples + [Float](repeating: 0, count: Int(rate * 1.5))
            for start in stride(from: 0, to: signal.count, by: 512) {
                let end = min(signal.count, start + 512)
                signal.withUnsafeBufferPointer { ptr in
                    analyzer.process(UnsafeBufferPointer(rebasing: ptr[start..<end]), startHostSeconds: 100 + Double(start) / rate)
                }
                try collector.consume(analyzer.snapshot(), renderEpochSeconds: 100)
            }
            #expect(try collector.hasResolvedTail(renderEpochSeconds: 100))
            let input = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1),
                finishedAt: Date(timeIntervalSince1970: 10), phase: .completed, reason: nil, signalConfirmed: true,
                renderEpochSeconds: 100, maximumClockDriftSeconds: 0, attacks: collector.attacks, clipping: collector.clipping,
                uncertainSignal: collector.uncertainSignal, analysisVersion: collector.analysisVersion)
            if ProcessInfo.processInfo.environment["COACH_ASSESSMENT_CLIP"] != nil {
                for event in analyzer.snapshot().events {
                    print("CORPUS_EVENT \(clip.file) onset=\(event.onset.streamSeconds - config.countInSeconds) resolved=\(event.resolvedAt.streamSeconds - config.countInSeconds) quality=\(event.quality) pitch=\(event.pitch?.frequency ?? 0)")
                }
            }
            let result = try AssessmentEngine.evaluate(input), note = try #require(result.notes.first)
            // The corpus labels the first pluck, not every transient in the release tail.
            // Preserve extra/uncertain evidence rather than declaring every recording perfect.
            #expect(result.matchedCount == 1, "\(clip.file)")
            #expect(result.validity == .valid || result.validity == .insufficientSignal)
            #expect(result.matchedCount + result.extras.count == input.attacks.count)
            if result.validity == .valid { scored += 1 }
            uncertainExtras += result.uncertainExtraCount
            let cents = try #require(note.centsError), timing = try #require(note.timingErrorSeconds)
            let target = try Pitch(midi: clip.nominalMIDI).frequency(referenceA4: 440)
            let referenceCents = 1200 * log2(clip.referenceHz / target)
            #expect(abs(cents - referenceCents) <= 15, "\(clip.file): detected \(cents), reference \(referenceCents)")
            #expect(abs(timing) <= 0.04, "\(clip.file): timing \(timing)")
            print("ASSESSMENT_CORPUS \(clip.file) pitchCents=\(cents) referenceCents=\(referenceCents) timingMs=\(timing * 1000) overall=\(result.overallScore ?? -1) extras=\(result.extras.count) uncertainExtras=\(result.uncertainExtraCount)")
        }
        if ProcessInfo.processInfo.environment["COACH_ASSESSMENT_CLIP"] == nil {
            #expect(scored >= 18 && uncertainExtras <= 14)
            print("ASSESSMENT_CORPUS_SUMMARY scored=\(scored) uncertainExtras=\(uncertainExtras) annotated=32 excludedWithoutOnset=2")
        }
    }
}
