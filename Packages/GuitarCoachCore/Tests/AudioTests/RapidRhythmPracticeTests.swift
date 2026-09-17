import Foundation
import Testing
import Domain
import Learning
import AudioTestSupport
@testable import Audio

struct RapidRhythmPracticeTests {
    @Test(arguments: [44100.0, 48000.0]) func repeatedAttacksRetainIndependentOnsets(rate: Double) throws {
        for midi in [45, 57, 69] {
            for spacing in [0.125, 0.15, 0.2] {
                for onset in [0.2013, 0.2179, 0.2321] {
                let frequency = try Pitch(midi: midi).frequency()
                let notes = (0..<12).map { SyntheticNote(onset: onset + Double($0) * spacing, duration: spacing, frequency: frequency, amplitude: $0.isMultiple(of: 3) ? 0.18 : 0.25) }
                let pcm = SyntheticAudio.render(rate: rate, duration: 0.7 + 12 * spacing, notes: notes)
                let analyzer = try MonophonicAnalyzer(sampleRate: rate)
                pcm.withUnsafeBufferPointer { input in
                    for offset in stride(from: 0, to: input.count, by: 769) {
                        analyzer.process(.init(rebasing: input[offset..<min(input.count, offset + 769)]), startHostSeconds: 100 + Double(offset) / rate)
                    }
                }
                analyzer.finish()
                let snapshot = analyzer.snapshot()
                #expect(snapshot.events.count == notes.count, "\(rate), MIDI \(midi), \(spacing): \(snapshot.events.count)")
                for (event, note) in zip(snapshot.events, notes) {
                    #expect(abs(event.onset.streamSeconds - note.onset) <= 0.02)
                    let frames = snapshot.pitchContour!.frames.filter { $0.time.streamSeconds >= event.onset.streamSeconds && $0.time.streamSeconds < event.onset.streamSeconds + spacing }
                    #expect(frames.filter { $0.state == .pitched }.count >= 2, "\(rate), MIDI \(midi), \(spacing): \(frames.map(\.state))")
                }
                }
            }
        }
    }
    private func run(rate: Double = 48000, mode: String = "correct", midi: Int = 60, spacing: Double = 0.15,
                     calibrated: Bool = true, traceEnabled: Bool = true) throws -> AssessedPractice {
        let position = try FretPosition(string: midi < 55 ? 5 : 3, fret: midi - (midi < 55 ? 45 : 55))
        var events = try (0..<16).map { try MusicalEvent(id: "note-\($0)", startTick: Int64($0) * 240, durationTicks: 240, kind: .note, positions: [position]) }
        events.append(try MusicalEvent(id: "rest", startTick: 3840, durationTicks: 3840, kind: .rest))
        let exercise = try Exercise(id: "rapid", events: events, defaultBPM: 100, maximumBPM: 100, assessmentMode: .rhythmOnly)
        let endpoint = try CalibrationEndpoint(uid: "synthetic-rapid", channel: 1, sampleRate: rate, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: MonophonicAnalyzer.algorithmVersion)
        let calibration = try CalibrationProfile(route: route, method: .measured, residualOffsetSeconds: 0, uncertaintySeconds: 0.01,
            evidence: CalibrationEvidence(algorithmVersion: "generated", matchedPulses: 12, missedPulses: 0, extraPulses: 0,
                durationSeconds: 25, residualP95Seconds: 0, driftSeconds: 0))
        let config = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 15 / spacing, route: route, calibration: calibrated ? calibration : nil)
        let analyzer = try MonophonicAnalyzer(sampleRate: rate)
        var collector = PracticeEvidenceCollector(configuration: config, baseline: analyzer.snapshot())
        let start = 0.2179 + config.countInSeconds
        var onsets = (0..<16).filter { mode != "missing" || $0 != 6 }.map { start + Double($0) * spacing + (mode == "uneven" && $0.isMultiple(of: 2) ? 0.04 : 0) }
        if mode == "extra" { onsets.append(start + 17 * spacing) }
        if mode == "count-in" { onsets.insert(start - spacing * 4, at: 0) }
        let hz = try Pitch(midi: midi + (mode == "different-pitch" ? 2 : 0)).frequency()
        var pcm: [Float] = [], phase = 1.31, random: UInt64 = 313
        for frame in 0..<Int((start + 32 * spacing + 0.6) * rate) {
            let time = Double(frame) / rate
            phase += 2 * .pi * hz / rate
            random = random &* 6364136223846793005 &+ 1
            let onsetIndex = onsets.lastIndex { $0 <= time }
            let age = onsetIndex.map { time - onsets[$0] } ?? -1
            let length = mode == "missing" ? spacing * 0.85 : spacing
            let envelope = age >= 0 && age < length ? min(1, age / 0.003, (length - age) / 0.015) : 0
            let amplitude = (onsetIndex ?? 0).isMultiple(of: 3) ? 0.18 : 0.25
            var sample = amplitude * envelope * (sin(phase) + 0.3 * sin(2 * phase) + 0.15 * sin(3 * phase))
            if mode == "noise" { sample = envelope * (Double(random >> 32) / Double(UInt32.max) * 2 - 1) * 0.25 }
            if mode == "clipped" { sample = max(-1, min(1, sample * 12)) }
            if mode == "silence" { sample = 0 }
            pcm.append(Float(sample))
        }
        for frame in stride(from: 0, to: pcm.count, by: 769) {
            pcm.withUnsafeBufferPointer { analyzer.process(.init(rebasing: $0[frame..<min(frame + 769, $0.count)]), startHostSeconds: 100 + Double(frame) / rate) }
            try collector.consume(analyzer.snapshot(), renderEpochSeconds: 100.2179)
        }
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 20),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100.2179, maximumClockDriftSeconds: 0,
            attacks: collector.attacks, clipping: collector.clipping, uncertainSignal: collector.uncertainSignal,
            pitchContour: traceEnabled ? collector.pitchContourTrace() : nil, analysisVersion: collector.analysisVersion)
        return try AssessmentEngine.evaluate(evidence)
    }

    @Test(arguments: [44100.0, 48000.0]) func rapidRhythmUsesActualWorkerAndNeverInventsPitch(rate: Double) throws {
        for midi in [45, 55, 60, 69] {
            let result = try run(rate: rate, midi: midi)
            #expect(result.validity == .valid, "MIDI \(midi): \(result.validity) uncertain \(result.uncertainCount)")
            #expect(result.matchedCount == 16 && result.extras.isEmpty)
            #expect((result.timingScore ?? -1) > 75)
            #expect(result.pitchScore == nil && result.notes.allSatisfy { $0.centsError == nil })
            for note in result.notes {
                if let error = note.timingErrorSeconds { #expect(abs(error) <= 0.02, "onset \(error)") }
            }
            #expect(result.parameters == .rhythmOnly)
            #expect(result.evidence.configuration.capabilityVersion == MonophonicCapability.rhythmVersion)
            #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(result)) == result)
        }
    }
    @Test func defectsAndUnavailableEvidenceRemainDistinct() throws {
        let good = try run()
        for mode in ["missing", "extra", "uneven", "silence", "noise", "clipped", "count-in", "different-pitch"] {
            let result = try run(mode: mode)
            #expect(result.pitchScore == nil && result.notes.allSatisfy { $0.centsError == nil })
            if ["noise", "clipped"].contains(mode) {
                #expect(result.validity == .insufficientSignal && result.overallScore == nil, "\(mode)")
            } else {
                #expect(result.validity == .valid, "\(mode): \(result.validity), uncertain \(result.uncertainCount)")
                if mode == "missing" { #expect(result.missedCount == 1 && (result.overallScore ?? 100) < (good.overallScore ?? 0)) }
                if mode == "extra" { #expect(result.extras.count == 1 && result.extras[0].restID == "rest" && (result.overallScore ?? 100) < (good.overallScore ?? 0)) }
                if mode == "uneven" { #expect((result.timingScore ?? 100) < (good.timingScore ?? 0)) }
                if mode == "silence" { #expect(result.matchedCount == 0 && result.overallScore == 0) }
                if mode == "count-in" { #expect(result.matchedCount == 16 && result.extras.isEmpty) }
                if mode == "different-pitch" { #expect(result.timingScore != nil) }
            }
        }
        let uncalibrated = try run(calibrated: false)
        #expect(uncalibrated.validity == .uncalibrated && uncalibrated.pitchScore == nil && uncalibrated.timingScore == nil && uncalibrated.overallScore == nil)
        let absent = try run(traceEnabled: false)
        #expect(absent.validity == .insufficientSignal && absent.overallScore == nil)
    }

}
