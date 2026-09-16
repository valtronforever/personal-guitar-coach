import SwiftUI
import Domain

struct CalibrationView: View {
    @Environment(AudioSessionStore.self) private var audio
    @Environment(CalibrationStore.self) private var store
    @Environment(LocalDataStore.self) private var data
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var manualOutputText = "0"
    @State private var manualInstrumentText = "0"
    @State private var manualOutputReference: ManualOutputReference = .additional
    private var string: Int { store.calibrationString }
    private var model: CalibrationModel { store.wizard }
    private var instrument: InstrumentProfile { data.preferences.instrument }
    private var route: CalibrationRoute? { audio.state?.calibrationRoute }
    private var profile: CalibrationProfile? { store.profile(for: route) }
    private var outputProfile: OutputAlignmentProfile? { store.outputProfile(for: audio.state?.outputEndpoint) }
    private var canEdit: Bool {
        audio.canEdit && store.loaded && !store.busy && !model.running && audio.state?.purpose == nil &&
        audio.state?.isClicking != true && audio.state?.isStartingClick != true
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("calibration.title").font(.title.bold())
            ScrollViewReader { proxy in
                Form {
                    Section {
                        Text("sync.independent.explanation")
                        routePickers.disabled(!canEdit)
                    }
                    Section("sync.setting.taps") {
                        milliseconds("sync.output.value", outputProfile?.seconds ?? 0)
                        if outputProfile?.isManual == true { Text("sync.manual.badge").font(.caption) }
                        Text("sync.output.explanation").font(.callout)
                        HStack {
                            Button("sync.output.measure") { model.start(audio: audio, store: store, instrument: instrument, string: string, source: .taps) }
                                .disabled(!canEdit || audio.state?.outputEndpoint == nil).accessibilityIdentifier("sync.output.start")
                            Button("sync.output.reset") { Task { await store.resetOutput(audio.state?.outputEndpoint) } }
                                .disabled(!canEdit || outputProfile == nil)
                        }
                        if let candidate = model.outputCandidate {
                            milliseconds("sync.output.measured", candidate.seconds)
                            Button("sync.output.apply") { Task { await model.applyOutput(audio: audio, store: store) } }
                                .disabled(!canEdit || outputProfile?.id == candidate.id).accessibilityIdentifier("sync.output.apply")
                        }
                        Divider()
                        Text("sync.manual.title").font(.headline)
                        Picker("sync.manual.outputReference", selection: $manualOutputReference) {
                            Text("sync.manual.additional").tag(ManualOutputReference.additional)
                            Text("sync.manual.total").tag(ManualOutputReference.total)
                        }.disabled(!canEdit)
                        HStack {
                            Text("sync.manual.value")
                            ManualDelayField(value: $manualOutputText, identifier: "sync.output.manualValue", enabled: canEdit)
                            Button("sync.manual.applyOutput") {
                                if let value = manualOutput { Task { await model.applyManualOutput(value, audio: audio, store: store) } }
                            }.disabled(!canEdit || manualOutput == nil).accessibilityIdentifier("sync.output.manualApply")
                        }
                        Text(manualOutputReference == .total ? "sync.manual.totalHelp" : "sync.manual.additionalHelp").font(.caption)
                        Text("sync.manual.range").font(.caption).foregroundStyle(.secondary)

                    }
                    Section("sync.setting.guitar") {
                        if let profile {
                            milliseconds("sync.instrument.value", profile.remainingInstrumentOffset)
                            if profile.method == .manualPersonal { Text("sync.manual.badge").font(.caption) }
                            if store.usableProfile(audio: audio, instrument: instrument) == nil { Text("sync.instrument.recheck").foregroundStyle(.secondary) }
                        } else { Text("sync.instrument.unset") }
                        Picker("sync.string", selection: Binding(get: { string }, set: { store.calibrationString = $0 })) {
                            ForEach(instrument.tuning.strings, id: \.number) { target in
                                Text("sync.stringNote \(target.number) \(target.openPitch.name())").tag(target.number)
                            }
                        }.disabled(!canEdit).accessibilityIdentifier("sync.string")
                        Text("sync.instrument.instructions")
                        Button("sync.instrument.measure") { model.start(audio: audio, store: store, instrument: instrument, string: string) }
                            .disabled(!canEdit || route == nil).accessibilityIdentifier("calibration.start")
                        if let candidate = model.candidate {
                            milliseconds("sync.instrument.measured", candidate.remainingInstrumentOffset)
                            milliseconds("sync.instrument.total", candidate.residualOffsetSeconds)
                            milliseconds("sync.repeatability", candidate.uncertaintySeconds)
                            Text(candidate.uncertaintySeconds + 0.03 <= 0.1 ? "sync.eligible" : "sync.uncertain")
                            Button("sync.apply") { Task { await model.apply(audio: audio, store: store, instrument: instrument) } }
                                .disabled(!canEdit || model.messageKey == "calibration.saved").accessibilityIdentifier("sync.apply")
                        }
                        Divider()
                        Text("sync.manual.title").font(.headline)
                        HStack {
                            Text("sync.manual.value")
                            ManualDelayField(value: $manualInstrumentText, identifier: "sync.instrument.manualValue", enabled: canEdit)
                            Button("sync.manual.applyInstrument") {
                                if let offset = LatencyEntryParser.seconds(manualInstrumentText) {
                                    Task { await model.applyManualInstrument(offset, audio: audio, store: store, instrument: instrument) }
                                }
                            }.disabled(!canEdit || !canApplyManualInstrument).accessibilityIdentifier("sync.instrument.manualApply")
                        }
                        Text("sync.manual.instrumentHelp").font(.caption)
                        Text("sync.manual.range").font(.caption).foregroundStyle(.secondary)
                        if let profile {
                            Button("calibration.forget") { Task { await store.forget(profile) } }.disabled(!canEdit)
                        }
                    }
                    if model.running {
                        Section {
                            Text(LocalizedStringKey("sync.setting." + model.source.rawValue)).font(.headline)
                            Text(LocalizedStringKey(model.source == .taps ? "sync.output.instructions" : "sync.stage." + model.stage.rawValue))
                                .accessibilityIdentifier("sync.stage")
                            if model.source == .taps {
                                SyncTapButton(title: tapTitle, enabled: model.canTap, onTap: model.tap, onInvalidTime: model.rejectTapTimestamp)
                                    .frame(height: 48)
                            } else { InputLevelMeter(snapshot: audio.state?.meters, active: audio.state?.phase == .running) }
                            Button("common.cancel") { model.cancel(audio: audio) }.keyboardShortcut(.cancelAction)
                        }.id("activeSync")
                    }
                    if let key = model.messageKey { Text(LocalizedStringKey(key)).accessibilityIdentifier("calibration.result") }
                    if let error = model.audioError { AudioErrorView(error: error) }
                    if !model.timelines.isEmpty {
                        Section("sync.timeline.title") {
                            Text("sync.timeline.retained").font(.caption)
                            ForEach(model.timelines) { run in SyncTimelineView(run: run) }
                        }.id("syncCharts")
                    }
                    if let report = model.diagnostics {
                        Section("sync.diagnostics.title") {
                            if report.targetFrequency > 0 {
                                LabeledContent("sync.diagnostics.target") { Text(report.targetFrequency, format: .number.precision(.fractionLength(1))) }
                                if let hz = report.lastFrequency { LabeledContent("sync.diagnostics.detected") { Text(hz, format: .number.precision(.fractionLength(1))) } }
                            }
                            if let peak = report.peakDB { LabeledContent("sync.diagnostics.peak") { Text(peak, format: .number.precision(.fractionLength(1))) } }
                            if let count = report.measuredAttacks {
                                if report.passNumber == 1 { Text("sync.output.count \(count)") }
                                else { Text("sync.diagnostics.attacks \(count) \(report.matchingAttacks) \(report.wrongAttacks) \(report.uncertainAttacks)") }
                            }
                            if let timing = report.timing {
                                if let value = timing.maximumOffset { milliseconds("sync.diagnostics.maximumOffset", value) }
                                if let value = timing.spread { milliseconds("sync.diagnostics.spread", value) }
                                if let value = timing.drift { milliseconds("sync.diagnostics.drift", value) }
                            }
                            if let value = report.clockDrift { milliseconds("sync.diagnostics.clock", value) }
                        }
                    }
                    if let key = store.errorKey { Text(LocalizedStringKey(key)).foregroundStyle(.red) }
                }.formStyle(.grouped)
                    .onChange(of: model.running) { _, running in
                        withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo(running ? "activeSync" : "syncCharts", anchor: .top) }
                    }
            }
            HStack { Spacer(); Button("common.done") { model.cancel(audio: audio); dismiss() } }
        }.padding(20).frame(width: 980, height: 820)
        .task {
            await store.load(); await audio.dismissSetup(); await audio.refresh()
            model.refreshContext(audio: audio, store: store, instrument: instrument, string: string)
            loadManualFields()
        }
        .onChange(of: audio.state?.routeRevision) { _, _ in model.invalidate(audio: audio); loadManualFields() }
        .onChange(of: audio.synchronizationSession) { _, _ in model.invalidate(audio: audio) }
        .onChange(of: instrument) { _, _ in model.invalidateInstrument(audio: audio) }
        .onChange(of: string) { _, _ in model.invalidateInstrument(audio: audio) }
        .onChange(of: store.outputProfiles) { _, _ in model.invalidateInstrument(audio: audio) }
        .onDisappear { model.cancel(audio: audio) }
    }
    private var manualOutput: OutputAlignmentProfile? {
        guard let output = audio.state?.outputEndpoint, let seconds = LatencyEntryParser.seconds(manualOutputText),
              let manual = try? ManualOutputAlignment(seconds: seconds, reference: manualOutputReference) else { return nil }
        return try? OutputAlignmentProfile(output: output, manual: manual)
    }
    private var canApplyManualInstrument: Bool {
        guard let route, let seconds = LatencyEntryParser.seconds(manualInstrumentText) else { return false }
        return (try? ManualInstrumentSyncEvidence(instrument: instrument, outputSetting: store.outputProfile(for: route.output), remainingOffset: seconds)) != nil
    }
    private func loadManualFields() {
        manualOutputReference = outputProfile?.manual?.reference ?? .additional
        manualOutputText = LatencyEntryParser.text(outputProfile?.manual?.seconds ?? outputProfile?.seconds ?? 0)
        manualInstrumentText = LatencyEntryParser.text(profile?.remainingInstrumentOffset ?? 0)
    }
    private var tapTitle: String {
        let code = locale.language.languageCode?.identifier == "uk" ? "uk" : "en"
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: "sync.tap.button", value: nil, table: nil)
    }
    private func milliseconds(_ key: String, _ seconds: Double) -> some View {
        LabeledContent { Text(seconds * 1000, format: .number.precision(.fractionLength(1))) }
            label: { Text(LocalizedStringKey(key)) }
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
}
