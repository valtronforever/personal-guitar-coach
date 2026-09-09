import SwiftUI
import Audio

/// All setup sheets and future tuner/practice screens use the composition root's one coordinator.
struct AudioProbeView: View {
    @Environment(AudioSessionStore.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var gainDraft = 0.0
    @State private var editingGain = false
    private var active: Bool { model.state?.phase == .running || model.state?.phase.isStarting == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("audio.title").font(.title.bold())
            Text("audio.introduction").foregroundStyle(.secondary)
            Form {
                Section {
                    Picker("audio.input", selection: Binding(get: { model.selection.inputUID ?? "" }, set: { uid in Task { await model.select(inputUID: uid) } })) {
                        Text("audio.chooseInput").tag("")
                        if let uid = model.selection.inputUID, model.selectedInput == nil { Text("audio.savedDeviceMissing").tag(uid) }
                        ForEach(model.inputs) { Text(verbatim: $0.name).tag($0.uid) }
                    }.accessibilityIdentifier("audio.input")
                    Picker("audio.channel", selection: Binding(get: { model.selection.inputChannel }, set: { value in Task { await model.select(inputChannel: value) } })) {
                        ForEach(1...max(model.selection.inputChannel, model.selectedInput?.inputChannels ?? 1), id: \.self) { Text($0, format: .number).tag($0) }
                    }.accessibilityIdentifier("audio.channel")
                    Picker("audio.output", selection: Binding(get: { model.selection.outputUID ?? "" }, set: { uid in Task { await model.select(outputUID: uid) } })) {
                        Text("audio.chooseOutput").tag("")
                        if let uid = model.selection.outputUID, model.selectedOutput == nil { Text("audio.savedDeviceMissing").tag(uid) }
                        ForEach(model.outputs) { Text(verbatim: $0.name).tag($0.uid) }
                    }.accessibilityIdentifier("audio.output")
                    Picker("audio.outputChannel", selection: Binding(get: { model.selection.outputChannel }, set: { value in Task { await model.select(outputChannel: value) } })) {
                        ForEach(1...max(model.selection.outputChannel, model.selectedOutput?.outputChannels ?? 1), id: \.self) { Text($0, format: .number).tag($0) }
                    }.accessibilityIdentifier("audio.outputChannel")
                }.disabled(!model.canEdit)
                Section {
                    if let input = model.selectedInput {
                        LabeledContent("audio.format") {
                            Text("audio.formatValue \(Int(input.sampleRate.isFinite ? input.sampleRate : 0)) \(Int(input.bufferFrames))").monospacedDigit()
                        }
                        if let capability = model.state?.capabilities {
                            Picker("audio.sampleRate", selection: Binding(get: { input.sampleRate }, set: { value in Task { await model.setRate(value) } })) {
                                ForEach(rateChoices(current: input.sampleRate, ranges: capability.sampleRates), id: \.self) { Text($0, format: .number).tag($0) }
                            }.disabled(!model.canEdit || !capability.canSetSampleRate).accessibilityIdentifier("audio.sampleRate")
                            Picker("audio.bufferSize", selection: Binding(get: { input.bufferFrames }, set: { value in Task { await model.setBuffer(value) } })) {
                                ForEach(bufferChoices(current: input.bufferFrames, range: capability.bufferRange), id: \.self) { Text($0, format: .number).tag($0) }
                            }.disabled(!model.canEdit || !capability.canSetBufferFrames).accessibilityIdentifier("audio.bufferSize")
                            Text("audio.formatShared").font(.caption).foregroundStyle(.secondary)
                            if let gain = capability.inputGain {
                                Slider(value: $gainDraft, in: 0...1) { Text(gain.element == 0 ? "audio.masterInputGain" : "audio.inputGain") } onEditingChanged: { editing in
                                    editingGain = editing
                                }.disabled(!model.canEdit || !gain.isSettable).accessibilityIdentifier("audio.gain")
                                Button("audio.applyInputLevel") { Task { await model.setGain(Float(gainDraft), element: gain.element) } }
                                    .disabled(!model.canEdit || !gain.isSettable || abs(gainDraft - Double(gain.value)) < 0.001)
                            } else { Text("audio.hardwareGain").foregroundStyle(.secondary) }
                        }
                    }
                    Text("audio.routeGuidance").font(.callout)
                    Text("audio.monitoringOff").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    if model.state?.phase.isStarting == true { ProgressView("audio.waitingInput") }
                    if model.state?.isStartingClick == true { ProgressView("audio.waitingOutput") }
                    if let snapshot = model.state?.meters {
                        ProgressView(value: Double(min(snapshot.peak, 1))) { Text("audio.level") }
                        Text(snapshot.peak >= 0.99 ? "audio.clipping" : snapshot.peak < 0.001 ? "audio.noSignal" : "audio.signalPresent")
                        LabeledContent("audio.rmsDB") {
                            if snapshot.rms > 0 { Text(20 * log10(Double(snapshot.rms)), format: .number.precision(.fractionLength(1))) }
                            else { Text("audio.noSignal") }
                        }
                        LabeledContent("audio.frames", value: snapshot.totalFrames.formatted())
                        LabeledContent("audio.drops", value: snapshot.droppedPackets.formatted())
                        LabeledContent("audio.discontinuities", value: snapshot.discontinuities.formatted())
                        LabeledContent("audio.timestamps") { Text(snapshot.hostTimeValid ? "audio.valid" : "audio.unavailable") }
                        if model.state?.phase != .running { Text("audio.lastSnapshot").font(.caption).foregroundStyle(.secondary) }
                    }
                    if let error = model.error { AudioErrorView(error: error) }
                    if let phase = model.state?.phase {
                        switch phase {
                        case .failed(let error), .interrupted(let error):
                            if error != model.error { AudioErrorView(error: error) }
                        default: EmptyView()
                        }
                    }
                    if let error = model.storageError {
                        Label(LocalizedStringKey(error), systemImage: "exclamationmark.triangle")
                        if model.loadFailed { Button("common.retry") { Task { await model.load() } } }
                    }
                    if model.inputs.isEmpty { Text("audio.noDevices").foregroundStyle(.secondary) }
                }
            }.formStyle(.grouped)
            HStack {
                Button(active ? "audio.stop" : "audio.start") {
                    Task { if active { await model.stop() } else { await model.start() } }
                }.disabled(model.isBusy || (!active && (model.selectedInput == nil || !model.canEdit)))
                    .accessibilityIdentifier("audio.capture")
                Button(model.state?.isClicking == true ? "audio.stopClick" : "audio.startClick") { Task { await model.toggleClick() } }
                    .disabled(model.isBusy || model.selectedOutput == nil || model.state?.isStartingClick == true || model.state?.phase.isStarting == true)
                Spacer()
                Button("audio.refresh") { Task { await model.refresh() } }
                Button("common.done") { Task { await model.dismissSetup(); dismiss() } }.keyboardShortcut(.defaultAction)
            }
            Text("audio.clickExplanation").font(.caption).foregroundStyle(.secondary)
        }
        .padding(20).frame(width: 680, height: 650)
        .task { model.activate(); await model.load(); await model.refresh() }
        .onDisappear { Task { await model.dismissSetup() } }
        .onChange(of: model.state?.capabilities?.inputGain?.value, initial: true) { _, value in
            if !editingGain { gainDraft = Double(value ?? 0) }
        }
    }
    private func rateChoices(current: Double, ranges: [ClosedRange<Double>]) -> [Double] {
        Array(Set([current] + [44_100.0, 48_000.0].filter { value in ranges.contains { $0.contains(value) } })).filter { $0.isFinite && $0 > 0 }.sorted()
    }
    private func bufferChoices(current: UInt32, range: ClosedRange<UInt32>?) -> [UInt32] {
        Array(Set([current] + [64, 128, 256, 512, 1024, 2048, 4096, 8192].filter { range?.contains($0) == true })).sorted()
    }
}

struct AudioErrorView: View {
    let error: AudioBackendError
    var body: some View {
        VStack(alignment: .leading) {
            Label(LocalizedStringKey(key), systemImage: "exclamationmark.triangle")
            if case let .system(code) = error { Text(verbatim: "OSStatus: \(code)").font(.caption) }
        }.foregroundStyle(.red)
    }
    private var key: String {
        switch error {
        case .system: "audio.error.system"
        case .unavailableDevice: "audio.error.device"
        case .invalidChannel: "audio.error.channel"
        case .invalidFormat: "audio.error.format"
        case .permissionDenied: "audio.error.permission"
        case .allocationFailed: "audio.error.memory"
        case .busyDevice: "audio.error.busy"
        case .unsupportedControl: "audio.error.control"
        case .routeChanged: "audio.error.routeChanged"
        case .dataLoss: "audio.error.dataLoss"
        case .streamStalled: "audio.error.stalled"
        case .suspended: "audio.error.suspended"
        case .inUse: "audio.error.inUse"
        case .cancelled: "audio.error.cancelled"
        }
    }
}
