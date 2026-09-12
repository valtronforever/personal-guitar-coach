import Foundation
import Testing
import Domain
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct FretCountTests {
    @Test func persistedCountSurvivesEveryInstrumentEditAndLegacyDefaultsTo24() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalDataStore(repository: LocalRepository(root: root)); await store.reload()
        for count in GuitarFretCount.allCases {
            await store.changeFretCount(count)
            await store.selectTuning(id: TuningProfile.dropD.id)
            await store.changeOrientation(.leftHanded); await store.changeSource(.acousticPickup)
            let custom = try TuningProfile(id: UUID().uuidString, name: "Custom", strings: TuningProfile.cStandard.strings)
            #expect(await store.saveTuning(custom, expectedRevision: nil))
            await store.restoreArchivedTuning(.cStandard)
            let restored = LocalDataStore(repository: LocalRepository(root: root)); await restored.reload()
            #expect(restored.preferences.instrument.frets == count)
            #expect(restored.preferences.instrument.orientation == .leftHanded && restored.preferences.instrument.source == .acousticPickup)
        }
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(InstrumentProfile())) as? [String: Any])
        legacy.removeValue(forKey: "fretCount")
        let bytes = try JSONSerialization.data(withJSONObject: legacy)
        #expect(try JSONDecoder().decode(InstrumentProfile.self, from: bytes).fretCount == 24)
        for bad in [0, 18, 23, 25, 100] {
            legacy["fretCount"] = bad
            #expect(throws: DecodingError.self) { try JSONDecoder().decode(InstrumentProfile.self, from: JSONSerialization.data(withJSONObject: legacy)) }
        }
    }

    @Test func boardLimitsPositionsNavigationAndPitchInBothOrientations() throws {
        for count in GuitarFretCount.allCases {
            for orientation in [FretboardOrientation.rightHanded, .leftHanded] {
                let last = try FretPosition(string: 1, fret: count.rawValue)
                let board = try FretboardModel(tuning: .standard, orientation: orientation, frets: count, positions: [last, FretPosition(string: 2, fret: 24)])
                #expect(board.frets.count == count.rawValue + 1 && board.frets.max() == count.rawValue)
                #expect(board.positions(fret: count.rawValue + 1).isEmpty)
                #expect(board.neighbor(of: last, horizontal: orientation == .rightHanded ? 1 : -1) == last)
                #expect(board.expected.allSatisfy { $0.fret <= count.rawValue })
                #expect(board.pitch(at: last)?.midi == 64 + count.rawValue)
                if count != .twentyFour { #expect(try board.pitch(at: FretPosition(string: 1, fret: 24)) == nil) }
            }
        }
    }
}

extension FretCountTests {
    @Test func practiceRejectsUnreachableFretsButAllowsAReachableSelectedBar() throws {
        let exercise = try Exercise(id: "high-fret-test", events: [
            MusicalEvent(id: "low", startTick: 0, durationTicks: 3840, kind: .note, positions: [FretPosition(string: 1, fret: 0)]),
            MusicalEvent(id: "high", startTick: 3840, durationTicks: 3840, kind: .note, positions: [FretPosition(string: 1, fret: 24)])])
        let endpoint = try CalibrationEndpoint(uid: "fixture", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let original = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60, route: route)
        #expect(throws: MusicError.invalidFret) {
            try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(frets: .nineteen), bpm: 60, route: route)
        }
        let shorter = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(frets: .nineteen), bpm: 60, range: 0..<3840, route: route)
        #expect(shorter.selectedEvents.map(\.id) == ["low"])
        let restored = try JSONDecoder().decode(PracticeConfiguration.self, from: JSONEncoder().encode(original))
        #expect(restored.instrument.fretCount == 24 && restored.exercise == original.exercise)
    }

    @Test func versionTwoPreferencesMigrateWithoutRewritingOnRead() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var payload = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(InstrumentPreferences.defaults)) as? [String: Any])
        var instrument = try #require(payload["instrument"] as? [String: Any]); instrument.removeValue(forKey: "fretCount")
        payload["instrument"] = instrument
        let original = try JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "payload": payload])
        let path = root.appendingPathComponent("instrument.json"); try original.write(to: path)
        let repository = LocalRepository(root: root)
        guard case let .available(value, migrated) = await repository.loadPreferences() else { Issue.record("Migration failed"); return }
        #expect(migrated && value.instrument.fretCount == 24)
        #expect(try Data(contentsOf: path) == original)
        try await repository.savePreferences(value)
        let saved = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        #expect(saved["schemaVersion"] as? Int == 3)
    }
}
