import Foundation
import Testing
@testable import Domain

struct PitchVibratoTests {
    @Test func capabilityUsesActualPulseAndRequiresFourCompleteCycles() throws {
        for meter in TimeSignature.allCases {
            let pulse = meter.pulseTicks
            let v = try PitchVibrato(extentCents: 30, startTick: pulse, endTick: pulse * 5, periodTicks: pulse)
            #expect(VibratoCapability.supports(vibrato: v, durationTicks: pulse * 6, bpm: 60, frequency: 196, pulseTicks: pulse))
            #expect(!VibratoCapability.supports(vibrato: v, durationTicks: pulse * 6, bpm: 59, frequency: 196, pulseTicks: pulse))
            let fast = try PitchVibrato(extentCents: 100, startTick: pulse, endTick: pulse * 3, periodTicks: pulse / 2)
            #expect(VibratoCapability.supports(vibrato: fast, durationTicks: pulse * 4, bpm: 90, frequency: 880, pulseTicks: pulse))
            #expect(!VibratoCapability.supports(vibrato: fast, durationTicks: pulse * 4, bpm: 91, frequency: 880, pulseTicks: pulse))
            #expect(!VibratoCapability.supports(vibrato: fast, durationTicks: pulse * 3, bpm: 60, frequency: 880, pulseTicks: pulse))
            let short = try PitchVibrato(extentCents: 50, startTick: pulse, endTick: pulse * 4, periodTicks: pulse)
            #expect(!VibratoCapability.supports(vibrato: short, durationTicks: pulse * 5, bpm: 60, frequency: 220, pulseTicks: pulse))
            for frequency in [195.0, 881, Double.nan, Double.infinity] {
                #expect(!VibratoCapability.supportsFrequencies(v, frequency: frequency))
            }
            for bpm in [0.0, -1, Double.nan, Double.infinity] {
                #expect(!VibratoCapability.supports(vibrato: v, durationTicks: pulse * 6, bpm: bpm, frequency: 220, pulseTicks: pulse))
            }
        }
    }
    @Test func eventKeepsOneFrettedAttackAndValidatesIncompatibleTechniques() throws {
        let vibrato = try PitchVibrato(extentCents: 80, startTick: 960, endTick: 2880, periodTicks: 480)
        let position = try FretPosition(string: 3, fret: 7)
        let note = try MusicalEvent(id: "v", startTick: 0, durationTicks: 3840, kind: .note, positions: [position], vibrato: vibrato)
        #expect(note.techniquePositions == [position])
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: JSONEncoder().encode(note)) == note)
        let plain = try MusicalEvent(id: "plain", startTick: 0, durationTicks: 960, kind: .note, positions: [position])
        #expect(!String(decoding: try JSONEncoder().encode(plain), as: UTF8.self).contains("vibrato"))
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "v", startTick: 0, durationTicks: 3840, kind: .rest, vibrato: vibrato) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "v", startTick: 0, durationTicks: 3840, kind: .note, positions: [FretPosition(string: 1, fret: 0)], vibrato: vibrato) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "v", startTick: 0, durationTicks: 3840, kind: .note, positions: [position], assessSustain: true, vibrato: vibrato) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "v", startTick: 0, durationTicks: 3840, kind: .note, positions: [position], palmMuted: true, vibrato: vibrato) }
        let transition = try PitchTransition(kind: .hammerOn, semitones: 2, startTick: 960)
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "v", startTick: 0, durationTicks: 3840, kind: .note, positions: [position], pitchTransition: transition, vibrato: vibrato) }
        #expect(throws: MusicError.invalidTime) { try MusicalEvent(id: "v", startTick: 0, durationTicks: 2880, kind: .note, positions: [position], vibrato: vibrato) }
    }
    @Test func authoredOscillationHasExactExtremaAndCompleteReturnCycles() throws {
        let vibrato = try PitchVibrato(extentCents: 80, startTick: 960, endTick: 2880, periodTicks: 480)
        #expect(vibrato.cycles == 4)
        for tick in [-100.0, 0, 960, 1440, 1920, 2400, 2880, 4000] { #expect(abs(vibrato.cents(at: tick)) < 1e-10) }
        for tick in [1200.0, 1680, 2160, 2640] { #expect(abs(vibrato.cents(at: tick) - 80) < 1e-10) }
        try vibrato.validate(durationTicks: 3840)
        #expect(throws: MusicError.invalidEvent) { try VibratoReference(vibrato: vibrato, waveform: VibratoWaveform(extentCents: 50)) }
        #expect(throws: MusicError.invalidTime) { try vibrato.validate(durationTicks: 2880) }
        #expect(try JSONDecoder().decode(PitchVibrato.self, from: JSONEncoder().encode(vibrato)) == vibrato)
        #expect(throws: MusicError.invalidEvent) { try PitchVibrato(extentCents: 0, startTick: 960, endTick: 2880, periodTicks: 480) }
        #expect(throws: MusicError.invalidEvent) { try PitchVibrato(extentCents: 201, startTick: 960, endTick: 2880, periodTicks: 480) }
        #expect(throws: MusicError.invalidEvent) { try PitchVibrato(extentCents: 50, startTick: 0, endTick: 1920, periodTicks: 480) }
        #expect(throws: MusicError.invalidEvent) { try PitchVibrato(extentCents: 50, startTick: 960, endTick: 2880, periodTicks: 0) }
        #expect(throws: MusicError.invalidEvent) { try PitchVibrato(extentCents: 50, startTick: 960, endTick: 1440, periodTicks: 480) }
        #expect(throws: MusicError.invalidEvent) { try PitchVibrato(extentCents: 50, startTick: 960, endTick: 2800, periodTicks: 480) }
        #expect(throws: MusicError.invalidEvent) { try PitchVibrato(extentCents: 50, startTick: Int64.max, endTick: Int64.min, periodTicks: 1) }
    }
    @Test func preparedPhaseMatchesIndependentIntegrationAndRemainsContinuousAtTableAndCycleEdges() throws {
        for extent in [1, 50, 100, 200] {
            let vibrato = try PitchVibrato(extentCents: extent, startTick: 960, endTick: 2880, periodTicks: 480)
            let reference = try VibratoReference(vibrato: vibrato)
            for upper in [700.0, 1097.3, 1919.9, 2600.0, 2880, 3600] {
                let count = 100_000, step = upper / Double(count)
                let numerical = (0..<count).reduce(0.0) { sum, index in
                    let tick = (Double(index) + 0.5) * step
                    let cents = tick <= 960 || tick >= 2880 ? 0 : Double(extent) * (1 - cos(2 * .pi * (tick - 960) / 480)) / 2
                    return sum + pow(2, cents / 1200) * step
                }
                #expect(abs(reference.integratedMultiplier(to: upper, durationTicks: 3840) - numerical) < 1e-6)
            }
            for tick in [960.0, 1100.0, 1440.0, 2880.0] {
                let delta = 0.001
                let derivative = (reference.integratedMultiplier(to: tick + delta, durationTicks: 3840)
                    - reference.integratedMultiplier(to: tick - delta, durationTicks: 3840)) / (2 * delta)
                let cents = tick == 1100 ? Double(extent) * (1 - cos(2 * .pi * 140 / 480)) / 2 : 0
                #expect(abs(derivative - pow(2, cents / 1200)) < 1e-7)
            }
            #expect(reference.integratedMultiplier(to: -1, durationTicks: 3840) == 0)
        }
    }
}
