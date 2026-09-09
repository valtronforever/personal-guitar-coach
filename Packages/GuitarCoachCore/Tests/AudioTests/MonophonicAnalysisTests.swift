import Testing
import Foundation
import Domain
import AudioTestSupport
@testable import Audio

@Suite struct MonophonicAnalysisTests {
    private func run(rate: Double = 48000, notes: [SyntheticNote], duration: Double = 1, noise: Double = 0.0001,
                     chunk: Int = 512, clip: Bool = false) throws -> (AudioAnalysisSnapshot, [PitchObservation]) {
        let signal = SyntheticAudio.render(rate: rate, duration: duration, notes: notes, noise: noise, clip: clip)
        let analyzer = try MonophonicAnalyzer(sampleRate: rate)
        var observations: [PitchObservation] = []
        signal.withUnsafeBufferPointer { input in
            for offset in stride(from: 0, to: input.count, by: chunk) {
                analyzer.process(.init(rebasing: input[offset..<min(input.count, offset + chunk)]),
                                 startHostSeconds: 123 + Double(offset) / rate) { observations.append($0) }
            }
        }
        analyzer.finish()
        return (analyzer.snapshot(), observations)
    }

    @Test func pitchGridAndDominantSecondHarmonic() throws {
        for rate in [44100.0, 48000] {
            for midi in [36, 38, 40, 45, 50, 55, 59, 64, 76, 88] {
                let hz = try Pitch(midi: midi).frequency()
                for harmonics in [[1.0], [1, 0.4, 0.2], [0.25, 1, 0.1]] {
                    let signal = SyntheticAudio.render(rate: rate, duration: 0.5,
                        notes: [.init(onset: 0, duration: 0.5, frequency: hz, harmonics: harmonics)], noise: 0)
                    for method in PitchMethod.allCases {
                        let detector = try PitchDetector(sampleRate: rate, method: method)
                        let estimate = signal.withUnsafeBufferPointer { detector.estimate(.init(rebasing: $0[8000..<12096])) }
                        let value = try #require(estimate)
                        #expect(abs(1200 * log2(value.frequency / hz)) < 10, "\(method) \(rate) \(midi) \(harmonics)")
                    }
                }
            }
        }
    }

    @Test func sustainedNoteHasOneAttackAndSeparateSettlingTime() throws {
        let (result, observations) = try run(notes: [.init(duration: 1.5, frequency: 82.4069)], duration: 2)
        #expect(result.events.count == 1)
        let event = try #require(result.events.first)
        #expect(event.quality == .reliable)
        #expect(abs(event.onset.streamSeconds - 0.1) <= 0.03)
        #expect(event.resolvedAt.streamSeconds - event.onset.streamSeconds > 0.08)
        #expect(event.resolvedAt.streamSeconds - event.onset.streamSeconds < 0.3)
        #expect(event.onset.hostSeconds == 123 + event.onset.streamSeconds)
        #expect(observations.last?.quality == .silence)
        #expect(observations.last?.pitch == nil)
    }

    @Test func repeatedAttacksDoNotRequirePitchChanges() throws {
        for rate in [44100.0, 48000] {
            let notes = [0.1, 0.5, 0.9].map { SyntheticNote(onset: $0, duration: 0.3, frequency: 220) }
            let (result, _) = try run(rate: rate, notes: notes, duration: 1.4)
            #expect(result.events.count == 3)
            for (event, note) in zip(result.events, notes) {
                #expect(abs(event.onset.streamSeconds - note.onset) <= 0.03)
                #expect(event.quality == .reliable)
            }
        }
    }

    @Test func arbitraryPacketBoundariesDoNotChangeEvidence() throws {
        let notes = [SyntheticNote(frequency: 146.83)]
        let a = try run(notes: notes, chunk: 1).0
        let b = try run(notes: notes, chunk: 8192).0
        #expect(a == b)
    }

    @Test func onsetTimestampsRemainAccurateBetweenHopBoundaries() throws {
        for rate in [44100.0, 48000] {
            for start in [0.1013, 0.1179, 0.1321] {
                let (snapshot, _) = try run(rate: rate, notes: [.init(onset: start, frequency: 65.4064)])
                let event = try #require(snapshot.events.first)
                #expect(snapshot.events.count == 1)
                #expect(abs(event.onset.streamSeconds - start) <= 0.03)
                #expect(event.quality == .reliable)
            }
        }
    }

    @Test func invalidClippedQuietAndPolyphonicSignalsAreNotReliable() throws {
        #expect(try run(notes: [], noise: 0).0.latest?.quality == .silence)
        #expect(try run(notes: [], noise: 0.1).1.allSatisfy { $0.quality != .reliable })
        let clipped = try run(notes: [.init(duration: 1, frequency: 220, amplitude: 5)], clip: true)
        #expect(clipped.0.latest?.quality == .clipping)
        let poly = try run(notes: [.init(duration: 1, frequency: 130.8128), .init(duration: 1, frequency: 195.9977)])
        #expect(poly.1.filter { $0.time.streamSeconds > 0.3 }.allSatisfy { $0.quality != .reliable })
        let analyzer = try MonophonicAnalyzer(sampleRate: 48000)
        let invalid = [Float](repeating: .nan, count: 4800)
        invalid.withUnsafeBufferPointer { analyzer.process($0) }
        #expect(analyzer.snapshot().latest?.quality == .invalid)
        #expect(analyzer.snapshot().invalidSamples == 4800)
    }

    @Test func briefClippingSurvivesASlowConsumerAndLargeFiniteSamplesRemainBounded() throws {
        let analyzer = try MonophonicAnalyzer(sampleRate: 48000)
        var input = [Float](repeating: 0, count: 48000)
        for i in 5000..<5010 { input[i] = .greatestFiniteMagnitude }
        input.withUnsafeBufferPointer { analyzer.process($0) }
        let result = analyzer.snapshot()
        #expect(result.latest?.quality == .silence)
        #expect(result.qualitySpans.contains { $0.quality == .clipping })
        #expect(result.latest?.rms.isFinite == true)
        #expect(result.qualitySpans.count <= MonophonicAnalyzer.qualitySpanCapacity)
    }

    @Test func unsupportedFormatFailsAndDetectedPitchUsesExplicitReference() throws {
        #expect(throws: AudioBackendError.invalidFormat) { try MonophonicAnalyzer(sampleRate: 96000) }
        let (snapshot, _) = try run(notes: [.init(frequency: 450)])
        let pitch = try #require(snapshot.events.first?.pitch)
        #expect(try pitch.nearestPitch(referenceA4: 450).midi == 69)
        #expect(try abs(pitch.cents(referenceA4: 450)) < 5)
        #expect(try pitch.cents(referenceA4: 440) > 30)
    }
}
