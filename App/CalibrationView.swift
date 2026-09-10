import SwiftUI
import Domain

struct CalibrationView: View {
    @Environment(AudioSessionStore.self) private var audio
    @Environment(CalibrationStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var model = CalibrationModel()
    @State private var cableReady = false
    @State private var longRun = false
    @State private var manualMS = 0.0
    private var route: CalibrationRoute? { audio.state?.calibrationRoute }
    private var profile: CalibrationProfile? { store.profile(for: route) }
    private var canSave: Bool { route != nil && store.loaded && !store.busy && !model.running }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("calibration.title").font(.title.bold())
            Form {
                Section {
                    Text("calibration.explanation")
                    if let route {
                        endpoint(route.input, title: "audio.input", name: audio.selectedInput?.name ?? route.input.uid)
                        endpoint(route.output, title: "audio.output", name: audio.selectedOutput?.name ?? route.output.uid)
                        Text("calibration.hardwareExplanation").font(.caption).foregroundStyle(.secondary)
                        if route.usesSeparateDevices { Text("calibration.separateDevices").font(.callout) }
                    } else { Text("calibration.chooseRoute") }
                }
                Section("calibration.profile") {
                    Text(LocalizedStringKey("calibration.method." + (profile?.method.rawValue ?? "none")))
                    if let profile {
                        LabeledContent("calibration.offset") { Text(profile.residualOffsetSeconds * 1000, format: .number.precision(.fractionLength(1))) }
                        LabeledContent("calibration.uncertainty") { Text(profile.uncertaintySeconds * 1000, format: .number.precision(.fractionLength(1))) }
                        if let evidence = profile.evidence {
                            LabeledContent("calibration.pulses", value: evidence.matchedPulses.formatted())
                            LabeledContent("calibration.duration") { Text(evidence.durationSeconds, format: .number.precision(.fractionLength(1))) }
                        }
                        Text(profile.method == .measured ? "calibration.measuredGate" : "calibration.pitchOnly").font(.callout)
                        Button("calibration.forget") { Task { await store.forget(profile) } }.disabled(!canSave)
                    } else { Text("calibration.pitchOnly").font(.callout) }
                }
                Section("calibration.loopback") {
                    Text("calibration.instructions").font(.callout)
                    Toggle("calibration.cableReady", isOn: $cableReady).disabled(model.running)
                    Toggle("calibration.longRun", isOn: $longRun).disabled(model.running)
                    Button("calibration.start") { model.start(audio: audio, store: store, long: longRun) }
                        .disabled(!canSave || !cableReady || audio.state?.purpose != nil || audio.state?.isClicking == true)
                        .accessibilityIdentifier("calibration.start")
                    if model.running {
                        ProgressView(value: model.elapsedSeconds, total: longRun ? 900 : 26) { Text("calibration.measuring") }
                        Button("common.cancel") { model.cancel(audio: audio) }
                    }
                }
                Section("calibration.manual") {
                    Text("calibration.manualExplanation").font(.callout)
                    TextField("calibration.offset", value: $manualMS, format: .number.precision(.fractionLength(1)))
                        .disabled(!canSave).accessibilityIdentifier("calibration.manualOffset")
                    HStack {
                        Button("calibration.saveManual") { saveUnmeasured(.manual) }
                            .disabled(!canSave || !manualMS.isFinite || !(-1000...1000).contains(manualMS))
                        Button("calibration.saveEstimated") { saveUnmeasured(.estimated) }.disabled(!canSave)
                    }
                }
                if let key = model.messageKey { Text(LocalizedStringKey(key)).accessibilityIdentifier("calibration.result") }
                if let key = store.errorKey {
                    Text(LocalizedStringKey(key)).foregroundStyle(.red)
                    if !store.loaded { Button("common.retry") { Task { await store.load() } } }
                }
            }.formStyle(.grouped)
            HStack { Spacer(); Button("common.done") { model.cancel(audio: audio); dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(20).frame(width: 660, height: 620)
        .task { await store.load(); await audio.refresh() }
        .onChange(of: route) { _, _ in cableReady = false }
        .onDisappear { model.cancel(audio: audio) }
    }

    private func saveUnmeasured(_ method: CalibrationMethod) {
        guard let route, let value = try? CalibrationProfile(route: route, method: method,
            residualOffsetSeconds: method == .manual ? manualMS / 1000 : 0, uncertaintySeconds: 1) else { return }
        Task { await store.save(value) }
    }
    private func endpoint(_ endpoint: CalibrationEndpoint, title: String, name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(LocalizedStringKey(title), value: name)
            Text("calibration.endpoint \(endpoint.channel) \(Int(endpoint.sampleRate)) \(Int(endpoint.bufferFrames))").font(.caption)
            HStack {
                Text("calibration.hardware")
                if let latency = endpoint.hardwareLatencySeconds { Text(latency * 1000, format: .number.precision(.fractionLength(2))) }
                else { Text("audio.unavailable") }
                Spacer()
                Text("calibration.safety")
                if let safety = endpoint.safetyOffsetFrames { Text(Int(safety), format: .number) }
                else { Text("audio.unavailable") }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
}
