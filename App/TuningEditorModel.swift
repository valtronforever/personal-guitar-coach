import SwiftUI
import Domain

@MainActor @Observable
final class TuningEditorModel: Identifiable {
    let id = UUID()
    let original: TuningProfile
    let editingExisting: Bool
    var name: String
    var referenceText: String
    var notes: [Int: String]
    var expectedRevision: Int? { editingExisting ? original.revision : nil }
    var reference: Double? { Double(referenceText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) }

    init(tuning: TuningProfile, editingExisting: Bool) {
        self.original = tuning; self.editingExisting = editingExisting
        self.name = editingExisting ? tuning.name : ""
        self.referenceText = String(tuning.referenceA4)
        self.notes = Dictionary(uniqueKeysWithValues: tuning.strings.map { ($0.number, $0.openPitch.name(spelling: tuning.preferredSpelling)) })
    }

    var validationKey: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "tuning.error.name" }
        guard let reference, reference.isFinite, (400...480).contains(reference) else { return "tuning.error.reference" }
        guard Set(notes.keys) == Set(1...6), notes.values.allSatisfy({ (try? Pitch.parse($0).midi).map { $0 <= 103 } ?? false }) else {
            return "tuning.error.notes"
        }
        return nil
    }

    func profile() throws -> TuningProfile {
        guard validationKey == nil, let reference else { throw MusicError.invalidTuning }
        let strings = try (1...6).map { try TunedString(number: $0, openPitch: Pitch.parse(notes[$0] ?? "")) }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if editingExisting { return try original.revised(name: name, strings: strings, referenceA4: reference) }
        return try TuningProfile(id: "custom-\(id.uuidString.lowercased())", name: name, strings: strings, referenceA4: reference)
    }

    func frequency(string: Int) -> Double? {
        guard let reference, let text = notes[string] else { return nil }
        return try? Pitch.parse(text).frequency(referenceA4: reference)
    }
}
