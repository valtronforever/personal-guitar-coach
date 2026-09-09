import Foundation
import Testing
import Domain
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct TuningSettingsTests {
    @Test func customEditorValidatesNamesNotesAndReference() throws {
        let editor = TuningEditorModel(tuning: .standard, editingExisting: false)
        #expect(editor.validationKey == "tuning.error.name")
        editor.name = "My tuning"
        editor.referenceText = "442,5"
        editor.notes[6] = "D2"
        let custom = try editor.profile()
        #expect(custom.referenceA4 == 442.5)
        #expect(custom.strings.last?.openPitch.midi == 38)
        #expect(custom.id != TuningProfile.standard.id)
        #expect(custom.revision == 1)
        editor.referenceText = "nan"
        #expect(editor.validationKey == "tuning.error.reference")
        editor.referenceText = "440"
        editor.notes[1] = "G8"
        #expect(editor.validationKey == "tuning.error.notes")
        #expect(throws: MusicError.invalidTuning) { try editor.profile() }
    }

    @Test func revisionConflictAndPresetMutationAreRejected() throws {
        let custom = try TuningProfile(id: "test-custom", name: "Custom", strings: TuningProfile.standard.strings)
        let preferences = try InstrumentPreferences.defaults.savingCustomTuning(custom, expectedRevision: nil)
        let revised = try custom.revised(name: "Renamed", strings: custom.strings, referenceA4: 442)
        let updated = try preferences.savingCustomTuning(revised, expectedRevision: 1)
        #expect(updated.instrument.tuning.revision == 2)
        #expect(updated.customTunings == [revised])
        #expect(throws: StorageError.identifierConflict) { try updated.savingCustomTuning(revised, expectedRevision: 1) }
        #expect(throws: StorageError.invalidRecord) { try preferences.savingCustomTuning(.dropD, expectedRevision: nil) }
        #expect(throws: StorageError.invalidRecord) { try InstrumentPreferences(instrument: InstrumentProfile(tuning: custom)) }
    }

    @Test func sharedSnapshotChangeNotifiesBeforePublishingAndRestoresAfterRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalDataStore(repository: LocalRepository(root: root))
        await store.reload()
        var changes = 0
        store.instrumentWillChange = { next in
            changes += 1
            #expect(store.preferences.instrument != next)
        }
        let editor = TuningEditorModel(tuning: .dropD, editingExisting: false)
        editor.name = "Test tuning"; editor.referenceText = "442"
        let original = try editor.profile()
        #expect(await store.saveTuning(original, expectedRevision: nil))
        let edit = TuningEditorModel(tuning: original, editingExisting: true)
        edit.name = "Renamed"
        #expect(try await store.saveTuning(edit.profile(), expectedRevision: 1))
        await store.changeOrientation(.leftHanded)
        #expect(changes == 3)
        let restored = LocalDataStore(repository: LocalRepository(root: root)); await restored.reload()
        #expect(restored.preferences.instrument.tuning.id == original.id)
        #expect(restored.preferences.instrument.tuning.revision == 2)
        #expect(restored.preferences.instrument.orientation == .leftHanded)
        await restored.selectTuning(id: TuningProfile.standard.id)
        #expect(restored.preferences.instrument.tuning == .standard)
        #expect(restored.preferences.customTunings.count == 1)
        store.instrumentWillChange = nil
    }

    @Test func changingLanguageDoesNotChangeStoredTuningIdentity() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "coach-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { try? FileManager.default.removeItem(at: root); defaults.removePersistentDomain(forName: suite) }
        let store = LocalDataStore(repository: LocalRepository(root: root)); await store.reload()
        await store.selectTuning(id: TuningProfile.dropD.id)
        let settings = AppSettings(defaults: defaults)
        settings.language = .ukrainian
        #expect(store.preferences.instrument.tuning.id == "drop-d")
        #expect(store.preferences.instrument.tuning == .dropD)
    }
}
