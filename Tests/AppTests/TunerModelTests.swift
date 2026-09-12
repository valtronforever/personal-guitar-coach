import Foundation
import Testing
import Domain
@testable import Audio
@testable import PersonalGuitarCoach

@MainActor struct TunerModelTests {
    @Test(arguments: [44100.0, 48000.0]) func dropALowStringAcceptsDetuningWithoutChangingTheGradingLimit(sampleRate: Double) throws {
        for cents in [-75.0, -25, 0, 25, 75] {
            let frequency = 55 * pow(2, cents / 1200)
            let analyzer = try MonophonicAnalyzer(sampleRate: sampleRate)
            let model = TunerModel(); model.configure(tuning: .dropA, mode: .manual(string: 6))
            let frames = Int(sampleRate / 20), now = ContinuousClock.now
            for block in 0..<24 {
                let pcm = (0..<frames).map { Float(0.2 * sin(2 * .pi * frequency * Double(block * frames + $0) / sampleRate)) }
                pcm.withUnsafeBufferPointer { analyzer.process($0) }
                model.consume(analyzer.snapshot(), now: now)
            }
            #expect(model.reading.feedback == (cents < 0 ? .flat : cents > 0 ? .sharp : .inTune))
            #expect(abs(try #require(model.reading.cents) - cents) < 1)
            #expect(model.reading.targetFrequency == 55)
            #expect(!Exercise.monophonicMIDITarget.contains(33))
            #expect(analyzer.snapshot().algorithmVersion == "mono-mpm-flux-3")
        }
        let analyzer = try MonophonicAnalyzer(sampleRate: sampleRate)
        let low = (0..<Int(sampleRate)).map { Float(0.2 * sin(2 * .pi * 50 * Double($0) / sampleRate)) }
        low.withUnsafeBufferPointer { analyzer.process($0) }
        #expect(analyzer.snapshot().latest?.quality == .outOfRange)
    }
    private func snapshot(_ frame: Int64, spans: [SignalQualitySpan] = [], total: UInt64 = 0) -> AudioAnalysisSnapshot {
        AudioAnalysisSnapshot(algorithmVersion: "test", latest: PitchObservation(time: time(frame), quality: .reliable,
            pitch: DetectedPitch(frequency: 110, clarity: 0.99), rms: 0.1, peak: 0.2, noiseFloor: 0.001, periodEvidence: nil),
            events: [], totalEvents: 0, invalidSamples: 0, qualitySpans: spans, totalQualitySpans: total)
    }
    private func time(_ frame: Int64) -> AnalysisTimestamp { AnalysisTimestamp(frame: frame, sampleRate: 48000, hostSeconds: nil) }
    private func qualify(_ model: TunerModel, now: ContinuousClock.Instant) {
        model.configure(tuning: .standard, mode: .manual(string: 5))
        for index in 0...7 { model.consume(snapshot(Int64(index * 2400)), now: now) }
        #expect(model.reading.feedback == .inTune)
    }

    @Test func repeatedSnapshotExpiresAndNewEvidenceMustQualifyAgain() {
        let model = TunerModel(), now = ContinuousClock.now
        qualify(model, now: now)
        model.consume(snapshot(16800), now: now.advanced(by: .milliseconds(201)))
        #expect(model.isStale && model.reading.feedback == .waiting && model.reading.frequency == nil)
        model.consume(snapshot(19200), now: now.advanced(by: .milliseconds(210)))
        #expect(!model.isStale && model.reading.feedback == .centering)
        model.consume(nil, now: now.advanced(by: .milliseconds(411)))
        #expect(model.isStale)
    }

    @Test func shortBadSpanBetweenUIFramesAndLostSpanHistoryResetGreen() {
        let now = ContinuousClock.now
        for missingHistory in [false, true] {
            let model = TunerModel(); qualify(model, now: now)
            let spans = [SignalQualitySpan(id: missingHistory ? 5 : 1, quality: missingHistory ? .reliable : .clipping,
                                          start: time(17000), end: time(17500))]
            model.consume(snapshot(19200, spans: spans, total: spans[0].id), now: now)
            #expect(model.reading.feedback == .centering)
        }
    }

    @Test func profileChangesAndRestartedStreamDiscardThePreviousNote() {
        let model = TunerModel(), now = ContinuousClock.now
        qualify(model, now: now)
        model.configure(tuning: .dropD, mode: .manual(string: 6))
        #expect(model.reading.targetPitch?.midi == 38 && model.reading.frequency == nil)
        qualify(model, now: now)
        model.consume(snapshot(0), now: now)
        #expect(model.reading.feedback == .centering)
        model.stopReading()
        #expect(model.reading.frequency == nil && !model.isStale)
    }

    @Test(arguments: [TuningProfile.cStandard, .bStandard, .dropC, .dropBFlat, .dropA], [44100.0, 48000.0]) func lowPresetOpenStringsReachManualAndAutomaticTunerThroughPCM(tuning: TuningProfile, sampleRate: Double) throws {
        for string in tuning.strings {
            for mode in [TunerMode.automatic, .manual(string: string.number)] {
                let analyzer = try MonophonicAnalyzer(sampleRate: sampleRate)
                let model = TunerModel(); model.configure(tuning: tuning, mode: mode)
                let frequency = try string.openPitch.frequency(), now = ContinuousClock.now
                let frames = Int(sampleRate / 20)
                for block in 0..<24 {
                    let pcm = (0..<frames).map { Float(0.2 * sin(2 * .pi * frequency * Double(block * frames + $0) / sampleRate)) }
                    pcm.withUnsafeBufferPointer { analyzer.process($0) }
                    model.consume(analyzer.snapshot(), now: now)
                }
                // Uniform profiles: strings 1/2 coincide with lower-string harmonics.
                // Drop profiles: strings 1/4 do. Never infer the physical string from those pitches.
                let ambiguousStrings = [TuningProfile.cStandard, .bStandard].contains(tuning) ? [1, 2] : [1, 4]
                let expected: TunerFeedback = mode == .automatic && ambiguousStrings.contains(string.number) ? .chooseString : .inTune
                #expect(model.reading.feedback == expected)
                #expect(model.reading.detectedPitch == string.openPitch && model.reading.targetString == string.number)
            }
        }
    }
    @Test func realAnalyzerSineThenSilenceFeedsTheSameDisplayModel() throws {
        let analyzer = try MonophonicAnalyzer(sampleRate: 48000)
        let model = TunerModel(); model.configure(tuning: .standard, mode: .manual(string: 5))
        let now = ContinuousClock.now
        for block in 0..<20 {
            let pcm = (0..<2400).map { Float(0.2 * sin(2 * .pi * 110 * Double(block * 2400 + $0) / 48000)) }
            pcm.withUnsafeBufferPointer { analyzer.process($0) }
            model.consume(analyzer.snapshot(), now: now)
        }
        #expect(model.reading.feedback == .inTune && model.reading.detectedPitch?.midi == 45)
        let silence = [Float](repeating: 0, count: 24000)
        silence.withUnsafeBufferPointer { analyzer.process($0) }
        model.consume(analyzer.snapshot(), now: now)
        #expect(model.reading.feedback == .silence && model.reading.frequency == nil)
    }
}
