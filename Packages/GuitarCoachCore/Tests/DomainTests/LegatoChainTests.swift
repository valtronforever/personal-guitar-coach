import Foundation
import Testing
@testable import Domain

struct LegatoChainTests {
    private func chain() throws -> LegatoChain {
        try LegatoChain(targets: [
            .init(kind: .hammerOn, semitones: 3, startTick: 960),
            .init(kind: .tap, semitones: 4, startTick: 1920),
            .init(kind: .pullOff, semitones: -4, startTick: 2880),
            .init(kind: .pullOff, semitones: -3, startTick: 3840)
        ])
    }
    @Test func cumulativePitchTargetsKeepOneStringAndRespectExactBoundaries() throws {
        let chain = try chain(), base = try FretPosition(string: 3, fret: 5)
        try chain.validate(durationTicks: 4800, position: base)
        #expect(chain.semitoneOffsets == [0,3,7,3,0])
        #expect(try chain.positions(from: base).map(\.fret) == [5,8,12,8,5])
        #expect(try chain.positions(from: base).allSatisfy { $0.string == 3 })
        for (tick, cents) in [(-1.0,0.0),(959.999,0),(960,300),(1920,700),(2880,300),(3840,0),(4800,0)] {
            #expect(chain.cents(at: tick) == cents)
        }
        #expect(throws: MusicError.invalidTime) { try chain.validate(durationTicks: 3840, position: base) }
        #expect(throws: MusicError.invalidFret) { try chain.validate(durationTicks: 4800, position: FretPosition(string: 3, fret: 20)) }
    }
    @Test func phaseIntegralMatchesIndependentPlateauAreasAndCachesAreNotPersisted() throws {
        let chain = try chain(), minorThird = pow(2, 3.0/12), fifth = pow(2, 7.0/12)
        let expected = 960 * (2 + 2 * minorThird + fifth)
        #expect(abs(chain.integratedMultiplier(to: 4800, durationTicks: 4800) - expected) < 1e-9)
        #expect(chain.integratedMultiplier(to: -100, durationTicks: 4800) == 0)
        #expect(chain.integratedMultiplier(to: 10000, durationTicks: 4800) == chain.integratedMultiplier(to: 4800, durationTicks: 4800))
        for tick in [960.0,1920,2880,3840] {
            let before = chain.integratedMultiplier(to: tick - 0.0001, durationTicks: 4800)
            let after = chain.integratedMultiplier(to: tick + 0.0001, durationTicks: 4800)
            #expect(after > before && after - before < 0.001)
        }
        let encoded = try JSONEncoder().encode(chain)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(object.keys) == ["targets"])
        let decoded = try JSONDecoder().decode(LegatoChain.self, from: encoded)
        #expect(decoded == chain && decoded.integratedMultiplier(to: 2400, durationTicks: 4800) == chain.integratedMultiplier(to: 2400, durationTicks: 4800))
    }
    @Test func invalidDirectionTimingCountAndFretExcursionsAreRejected() throws {
        for (kind, delta) in [(LegatoChain.Target.Kind.hammerOn,-1),(.pullOff,1),(.tap,-1),(.tap,13),(.hammerOn,0)] {
            #expect(throws: MusicError.invalidEvent) { try LegatoChain.Target(kind: kind, semitones: delta, startTick: 960) }
        }
        #expect(throws: MusicError.invalidEvent) { try LegatoChain(targets: []) }
        #expect(throws: MusicError.invalidEvent) { try LegatoChain(targets: [.init(kind: .hammerOn, semitones: 1, startTick: 960), .init(kind: .pullOff, semitones: -1, startTick: 960)]) }
        #expect(throws: MusicError.invalidEvent) { try LegatoChain(targets: (1...9).map { try .init(kind: .hammerOn, semitones: 1, startTick: Int64($0)*960) }) }
        #expect(throws: MusicError.invalidFret) { try LegatoChain(targets: (1...3).map { try .init(kind: .tap, semitones: 12, startTick: Int64($0)*960) }) }
        let below = try LegatoChain(targets: [.init(kind: .pullOff, semitones: -1, startTick: 960)])
        #expect(throws: MusicError.invalidFret) { try below.validate(durationTicks: 1920, position: FretPosition(string: 3, fret: 0)) }
        let invalid = Data(#"{"targets":[{"kind":"tap","semitones":-1,"startTick":960}]}"#.utf8)
        #expect(throws: MusicError.invalidEvent) { try JSONDecoder().decode(LegatoChain.self, from: invalid) }
    }
}

extension LegatoChainTests {
    @Test func eventExclusivityCapabilityBoundsAndOptionalEncodingAreStrict() throws {
        let chain = try LegatoChain(targets: [.init(kind: .hammerOn, semitones: 3, startTick: 384),
            .init(kind: .tap, semitones: 4, startTick: 768), .init(kind: .pullOff, semitones: -7, startTick: 1152)])
        let position = try FretPosition(string: 3, fret: 5)
        #expect(LegatoChainCapability.supports(chain: chain, durationTicks: 1536, bpm: 60, frequency: 261.6255653005986, pulseTicks: 960))
        #expect(!LegatoChainCapability.supports(chain: chain, durationTicks: 1535, bpm: 60, frequency: 261.6255653005986, pulseTicks: 960))
        #expect(!LegatoChainCapability.supports(chain: chain, durationTicks: 1536, bpm: 60.1, frequency: 261.6255653005986, pulseTicks: 960))
        #expect(!LegatoChainCapability.supportsFrequencies(chain, frequency: 195))
        #expect(!LegatoChainCapability.supportsFrequencies(chain, frequency: 740)) // raised fifth exceeds 1100 Hz
        #expect(!LegatoChainCapability.supports(chain: chain, durationTicks: 1536, bpm: .nan, frequency: 261.6, pulseTicks: 960))
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "chain", startTick: 0, durationTicks: 1920,
            kind: .note, positions: [position], assessSustain: true, legatoChain: chain) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "chain", startTick: 0, durationTicks: 1920,
            kind: .note, positions: [position], palmMuted: true, legatoChain: chain) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "chain", startTick: 0, durationTicks: 1920,
            kind: .note, positions: [position], pitchTransition: PitchTransition(kind: .hammerOn, semitones: 2, startTick: 960), legatoChain: chain) }
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "chain", startTick: 0, durationTicks: 1920,
            kind: .note, positions: [position, FretPosition(string: 2, fret: 5)], legatoChain: chain) }
        let ordinary = try MusicalEvent(id: "ordinary", startTick: 0, durationTicks: 960, kind: .note, positions: [position])
        let data = try JSONEncoder().encode(ordinary)
        #expect(!String(decoding: data, as: UTF8.self).contains("legatoChain"))
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: data) == ordinary)
        #expect(try PositioningPolicy(windowFrets: 12).windowFrets == 12)
        #expect(try PositioningPolicy(windowFrets: 13).windowFrets == 13) // Two-hand artificial octave region.
        #expect(throws: PositioningError.invalidPolicy) { try PositioningPolicy(windowFrets: 14) }
    }
}
