import SwiftUI
import Domain

struct CalibrationView: View {
    @Environment(AudioSessionStore.self) private var audio
    @Environment(CalibrationStore.self) private var store
    @Environment(LocalDataStore.self) private var data
    @Environment(\.dismiss) private var dismiss
    @State private var model = CalibrationModel()
    @State private var string = 3
    private var instrument: InstrumentProfile { data.preferences.instrument }
    private var route: CalibrationRoute? { audio.state?.calibrationRoute }
    private var profile: CalibrationProfile? { store.profile(for: route) }
    private var canStart: Bool {
        audio.canEdit && route != nil && store.loaded && !store.busy && !model.running &&
        audio.state?.purpose == nil && audio.state?.isClicking != true && audio.state?.isStartingClick != true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("calibration.title").font(.title.bold())
            Form {
                Section {
                    Text("sync.explanation")
                    Text("sync.bluetooth").font(.callout).foregroundStyle(.secondary)
                    routePickers.disabled(!audio.canEdit || model.running || store.busy)
                    Text("sync.headphones").font(.caption)
                }
                Section("sync.prepare") {
                    Picker("sync.string", selection: $string) {
                        ForEach(instrument.tuning.strings, id: \.number) { target in
                            Text("sync.stringNote \(target.number) \(target.openPitch.name())").tag(target.number)
                        }
                    }.disabled(model.running || store.busy).accessibilityIdentifier("sync.string")
                    Text("sync.instructions")
                    Text("sync.source").font(.caption)
                    Text(LocalizedStringKey(instrument.source.titleKey)).font(.caption)
                    InputLevelMeter(snapshot: audio.state?.meters, active: model.running && audio.state?.phase == .running)
                    if model.running {
                        Text("sync.pass \(model.passNumber)").font(.headline)
                        Text(LocalizedStringKey("sync.stage." + model.stage.rawValue))
                            .accessibilityIdentifier("sync.stage")
                        if model.stage != .signal {
                            ProgressView(value: min(model.elapsedSeconds, 20), total: 20) { Text("sync.progress") }
                        }
                        Button("common.cancel") { model.cancel(audio: audio) }
                    } else {
                        if model.stage == .between { Text("sync.between") }
                        Button(model.stage == .between ? "sync.secondPass" : "sync.start") {
                            model.start(audio: audio, store: store, instrument: instrument, string: string)
                        }.disabled(!canStart).accessibilityIdentifier("calibration.start")
                        if audio.state?.purpose != nil || audio.state?.isClicking == true {
                            Text("sync.audioInUse").font(.caption)
                        }
                    }
                }
                if let key = model.messageKey { Text(LocalizedStringKey(key)).accessibilityIdentifier("calibration.result") }
                if let error = model.audioError { AudioErrorView(error: error) }
                if let report = model.diagnostics {
                    Section("sync.diagnostics.title") {
                        Text("sync.pass \(report.passNumber)").font(.headline)
                        LabeledContent("sync.diagnostics.phase") { Text(LocalizedStringKey("sync.diagnostics.phase." + report.phase.rawValue)) }
                        if !model.running { Text("sync.diagnostics.stopped").font(.caption).foregroundStyle(.secondary) }
                        LabeledContent("sync.diagnostics.target") { Text(report.targetFrequency, format: .number.precision(.fractionLength(1))) }
                        if let hz = report.lastFrequency {
                            LabeledContent("sync.diagnostics.detected") { Text(hz, format: .number.precision(.fractionLength(1))) }
                        }
                        if let peak = report.peakDB {
                            LabeledContent("sync.diagnostics.peak") { Text(peak, format: .number.precision(.fractionLength(1))) }
                        }
                        if let count = report.measuredAttacks {
                            Text("sync.diagnostics.attacks \(count) \(report.matchingAttacks) \(report.wrongAttacks) \(report.uncertainAttacks)")
                        }
                        if let timing = report.timing {
                            if let value = timing.maximumOffset { milliseconds("sync.diagnostics.maximumOffset", value) }
                            if let value = timing.spread { milliseconds("sync.diagnostics.spread", value) }
                            if let value = timing.drift { milliseconds("sync.diagnostics.drift", value) }
                        }
                        if let value = report.clockDrift { milliseconds("sync.diagnostics.clock", value) }
                        if let value = report.betweenPassDifference { milliseconds("sync.diagnostics.agreement", value) }
                    }.accessibilityIdentifier("sync.diagnostics")
                }
                if let candidate = model.candidate {
                    Section("sync.result") {
                        measurements(candidate)
                        Text("sync.resultExplanation")
                        Text(candidate.uncertaintySeconds + 0.03 <= 0.1 ? "sync.eligible" : "sync.uncertain")
                        Button("sync.apply") { Task { await model.apply(audio: audio, store: store, instrument: instrument) } }
                            .disabled(store.busy || model.running || model.messageKey == "calibration.saved")
                            .accessibilityIdentifier("sync.apply")
                    }
                }
                if let profile {
                    Section("calibration.profile") {
                        Text(LocalizedStringKey("calibration.method." + profile.method.rawValue))
                        measurements(profile)
                        if profile.method == .personal && store.usableProfile(audio: audio, instrument: instrument) == nil {
                            Text("sync.recheck").foregroundStyle(.secondary)
                        }
                        Button("calibration.forget") { Task { await store.forget(profile) } }
                            .disabled(model.running || store.busy)
                    }
                }
                if let key = store.errorKey {
                    Text(LocalizedStringKey(key)).foregroundStyle(.red)
                    if !store.loaded { Button("common.retry") { Task { await store.load() } } }
                }
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("common.done") { model.cancel(audio: audio); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 700, height: 720)
        .task { await store.load(); await audio.dismissSetup(); await audio.refresh() }
        .onChange(of: audio.state?.routeRevision) { _, _ in model.cancel(audio: audio) }
        .onChange(of: audio.synchronizationSession) { _, _ in model.cancel(audio: audio) }
        .onChange(of: instrument) { _, _ in model.cancel(audio: audio) }
        .onChange(of: string) { _, _ in model.cancel(audio: audio) }
        .onDisappear { model.cancel(audio: audio) }
    }
    private var routePickers: some View {
        Group {
            Picker("audio.input", selection: Binding(get: { audio.selection.inputUID ?? "" }, set: { uid in Task { await audio.select(inputUID: uid) } })) {
                Text("audio.chooseInput").tag("")
                if let uid = audio.selection.inputUID, audio.selectedInput == nil { Text("audio.savedDeviceMissing").tag(uid) }
                ForEach(audio.inputs) { Text(verbatim: $0.name).tag($0.uid) }
            }.accessibilityIdentifier("sync.input")
            Picker("audio.channel", selection: Binding(get: { audio.selection.inputChannel }, set: { value in Task { await audio.select(inputChannel: value) } })) {
                ForEach(1...max(audio.selection.inputChannel, audio.selectedInput?.inputChannels ?? 1), id: \.self) { Text($0, format: .number).tag($0) }
            }
            Picker("audio.output", selection: Binding(get: { audio.selection.outputUID ?? "" }, set: { uid in Task { await audio.select(outputUID: uid) } })) {
                Text("audio.chooseOutput").tag("")
                if let uid = audio.selection.outputUID, audio.selectedOutput == nil { Text("audio.savedDeviceMissing").tag(uid) }
                ForEach(audio.outputs) { Text(verbatim: $0.name).tag($0.uid) }
            }.accessibilityIdentifier("sync.output")
            Picker("audio.outputChannel", selection: Binding(get: { audio.selection.outputChannel }, set: { value in Task { await audio.select(outputChannel: value) } })) {
                ForEach(1...max(audio.selection.outputChannel, audio.selectedOutput?.outputChannels ?? 1), id: \.self) { Text($0, format: .number).tag($0) }
            }
        }
    }
    private func milliseconds(_ key: String, _ seconds: Double) -> some View {
        LabeledContent { Text(seconds * 1000, format: .number.precision(.fractionLength(1))) }
            label: { Text(LocalizedStringKey(key)) }
    }
    private func measurements(_ profile: CalibrationProfile) -> some View {
        Group {
            LabeledContent("calibration.offset") { Text(profile.residualOffsetSeconds * 1000, format: .number.precision(.fractionLength(1))) }
            LabeledContent("sync.repeatability") { Text(profile.uncertaintySeconds * 1000, format: .number.precision(.fractionLength(1))) }
        }
    }
}
