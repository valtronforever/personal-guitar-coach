import SwiftUI
import Domain

struct TuningSettingsView: View {
    @Environment(LocalDataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var editor: TuningEditorModel?
    @State private var selectedPosition: FretPosition?

    var body: some View {
        let tuning = store.preferences.instrument.tuning
        Section("tuning.title") {
            Picker("tuning.profile", selection: Binding(get: { tuning.id }, set: { id in Task { await store.selectTuning(id: id) } })) {
                ForEach(store.preferences.availableTunings) { profile in TuningName(profile: profile).tag(profile.id) }
            }.accessibilityIdentifier("tuning.profile")
            HStack {
                Button("tuning.customize") { editor = TuningEditorModel(tuning: tuning, editingExisting: false) }
                    .accessibilityIdentifier("tuning.customize")
                if store.preferences.customTunings.contains(where: { $0.id == tuning.id }) {
                    Button("tuning.edit") { editor = TuningEditorModel(tuning: tuning, editingExisting: true) }
                        .accessibilityIdentifier("tuning.edit")
                }
            }
            Picker("tuning.orientation", selection: Binding(get: { store.preferences.instrument.orientation }, set: { value in
                Task { await store.changeOrientation(value) }
            })) {
                Text("tuning.rightHanded").tag(FretboardOrientation.rightHanded)
                Text("tuning.leftHanded").tag(FretboardOrientation.leftHanded)
            }.accessibilityIdentifier("tuning.orientation")
            LabeledContent("tuning.reference") { Text(tuning.referenceA4, format: .number.precision(.fractionLength(1))) }
            Text("tuning.lessonAdaptation").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("tuning.physicalExplanation").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .disabled(!store.canEditPreferences)
        Section("tuning.openStrings") {
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 8) {
                GridRow { Text("tuning.string"); Text("tuning.note"); Text("tuning.frequency") }.font(.caption).foregroundStyle(.secondary)
                ForEach(tuning.strings.reversed()) { string in
                    GridRow {
                        Text("tuning.stringNumber \(string.number)")
                        Text(verbatim: string.openPitch.name(spelling: tuning.preferredSpelling)).monospaced()
                        if let frequency = try? string.openPitch.frequency(referenceA4: tuning.referenceA4) {
                            Text(frequency, format: .number.precision(.fractionLength(2))).monospacedDigit()
                        }
                    }.accessibilityElement(children: .combine)
                }
            }
            Text("tuning.instrumentSize").font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("fretboard.preview") {
                FretboardView(model: FretboardModel(tuning: tuning, orientation: store.preferences.instrument.orientation,
                    positions: (1...6).compactMap { try? FretPosition(string: $0, fret: 0) }), selected: $selectedPosition)
                    .padding(.vertical, 8)
            }
            if tuning.strings.contains(where: { !Exercise.monophonicMIDITarget.contains($0.openPitch.midi) }) {
                Label("tuning.outOfRange", systemImage: "exclamationmark.triangle")
            }
        }
        .sheet(item: $editor) { TuningEditorView(model: $0).environment(\.locale, settings.locale) }
    }
}

struct TuningName: View {
    let profile: TuningProfile
    private var titleKey: String { "tuning.preset.\(profile.id)" }
    var body: some View {
        if TuningProfile.presets.contains(where: { $0.id == profile.id }) {
            Text(LocalizedStringKey(titleKey))
        } else { Text(verbatim: profile.name) }
    }
}

struct TuningEditorView: View {
    @Bindable var model: TuningEditorModel
    @Environment(LocalDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var saveError = false

    var body: some View {
        VStack(alignment: .leading, spacing: CoachLayout.spacing) {
            Text(LocalizedStringKey(model.editingExisting ? "tuning.edit" : "tuning.customize")).font(.title2.bold())
            LabeledContent("tuning.name") {
                TextField("tuning.name", text: $model.name).accessibilityIdentifier("tuning.name")
            }
            LabeledContent("tuning.reference") {
                TextField("tuning.reference", text: $model.referenceText).accessibilityIdentifier("tuning.reference")
            }
            Text("tuning.editorExplanation").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { Text("tuning.string"); Text("tuning.note"); Text("tuning.frequency") }.font(.caption)
                ForEach(Array((1...6).reversed()), id: \.self) { string in
                    GridRow {
                        Text("tuning.stringNumber \(string)")
                        TextField("tuning.note", text: Binding(get: { model.notes[string] ?? "" }, set: { model.notes[string] = $0 }))
                            .frame(width: 110).accessibilityLabel(Text("tuning.noteForString \(string)"))
                            .accessibilityIdentifier("tuning.string.\(string)")
                        if let frequency = model.frequency(string: string) {
                            Text(frequency, format: .number.precision(.fractionLength(2))).monospacedDigit()
                        } else { Text(verbatim: "—") }
                    }
                }
            }
            if let key = model.validationKey { Label(LocalizedStringKey(key), systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            if saveError {
                StorageNotices()
                if store.operationError == nil { Label("tuning.error.profile", systemImage: "exclamationmark.triangle") }
            }
            Text("tuning.physicalExplanation").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("common.cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction).disabled(store.isSaving)
                Spacer()
                if store.isSaving { ProgressView() }
                Button("common.save") {
                    Task {
                        do {
                            let profile = try model.profile()
                            if await store.saveTuning(profile, expectedRevision: model.expectedRevision) { dismiss() }
                            else { saveError = true }
                        } catch { saveError = true }
                    }
                }.keyboardShortcut(.defaultAction).disabled(model.validationKey != nil || !store.canEditPreferences)
                    .accessibilityIdentifier("tuning.save")
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(CoachLayout.padding)
        .frame(width: 560)
        .interactiveDismissDisabled(store.isSaving)
    }
}

/// Shared by lesson preflight and practice setup once an exercise is selected.
struct TuningRequirementView: View {
    let exercise: Exercise
    let instrument: TuningProfile
    var body: some View {
        if let required = exercise.requiredTuning, !required.hasSamePitches(as: instrument) {
            VStack(alignment: .leading, spacing: 8) {
                Label("tuning.mismatch", systemImage: "exclamationmark.triangle")
                TuningName(profile: required).font(.headline)
                Text(verbatim: required.strings.reversed().map { $0.openPitch.name(spelling: required.preferredSpelling) }.joined(separator: " · "))
            }.accessibilityElement(children: .combine)
        }
    }
}
