import SwiftUI
import AVFoundation
import Audio

@MainActor @Observable
final class AudioProbeModel {
    var devices: [AudioDeviceDescriptor] = []
    var inputUID = ""
    var outputUID = ""
    var channel = 1
    var isRunning = false
    var isClicking = false
    var isStarting = false
    var isStartingClick = false
    var snapshot: CaptureSnapshot?
    var error: AudioBackendError?
    private let capture = AudioCaptureBackend()
    private let click = ClickOutput()
    private var generation = 0
    private var cleanup: Task<Void, Never>?

    var inputs: [AudioDeviceDescriptor] { devices.filter { $0.inputChannels > 0 } }
    var outputs: [AudioDeviceDescriptor] { devices.filter { $0.outputChannels > 0 } }
    var selectedInput: AudioDeviceDescriptor? { inputs.first { $0.uid == inputUID } }

    func refresh() async {
        do {
            devices = try await Task.detached { try AudioDeviceService().devices() }.value
            if !inputs.contains(where: { $0.uid == inputUID }) {
                inputUID = inputs.first(where: { $0.inputChannels > 0 && $0.outputChannels > 0 && $0.isUSB })?.uid
                    ?? inputs.first?.uid ?? ""
            }
            if !outputs.contains(where: { $0.uid == outputUID }) {
                outputUID = outputs.first(where: { $0.uid == inputUID })?.uid ?? outputs.first?.uid ?? ""
            }
        } catch { self.error = (error as? AudioBackendError) ?? .unavailableDevice }
    }

    func start() async {
        guard !isStarting else { return }
        isStarting = true
        generation += 1
        let attempt = generation
        defer { isStarting = false }
        error = nil
        await cleanup?.value
        guard attempt == generation else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        let allowed: Bool
        if status == .notDetermined { allowed = await requestPermission() }
        else { allowed = status == .authorized }
        guard attempt == generation else { return }
        guard allowed else { error = .permissionDenied; return }
        do {
            let currentDevices = try await Task.detached { try AudioDeviceService().devices() }.value
            guard let device = currentDevices.first(where: { $0.uid == inputUID }) else {
                throw AudioBackendError.unavailableDevice
            }
            try await capture.start(device: device, channel: channel)
            guard generation == attempt else { await capture.stop(); return }
            snapshot = nil
            isRunning = true
        } catch { self.error = (error as? AudioBackendError) ?? .unavailableDevice }
    }

    private func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func updateMetrics() async {
        let attempt = generation
        let next = await capture.snapshot()
        if generation == attempt && isRunning { snapshot = next }
    }

    func toggleClick() async {
        guard !isStartingClick else { return }
        if isClicking { await click.stop(); isClicking = false; return }
        isStartingClick = true
        let attempt = generation
        defer { isStartingClick = false }
        do {
            await cleanup?.value
            guard generation == attempt else { return }
            let currentDevices = try await Task.detached { try AudioDeviceService().devices() }.value
            guard let device = currentDevices.first(where: { $0.uid == outputUID }) else {
                throw AudioBackendError.unavailableDevice
            }
            try await click.start(device: device)
            guard generation == attempt else { await click.stop(); return }
            isClicking = true
        } catch { self.error = (error as? AudioBackendError) ?? .unavailableDevice }
    }

    func stop() {
        generation += 1
        let previous = cleanup
        cleanup = Task { [capture, click] in
            await previous?.value
            await capture.stop()
            await click.stop()
        }
        isRunning = false
        isClicking = false
    }
}

struct AudioProbeView: View {
    @State private var model = AudioProbeModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("audio.title").font(.title.bold())
            Text("audio.introduction").foregroundStyle(.secondary)
            Form {
                Picker("audio.input", selection: $model.inputUID) {
                    ForEach(model.inputs) { Text($0.name).tag($0.uid) }
                }
                .disabled(model.isStarting || model.isRunning)
                Picker("audio.channel", selection: $model.channel) {
                    ForEach(1...max(1, model.selectedInput?.inputChannels ?? 1), id: \.self) {
                        Text($0, format: .number).tag($0)
                    }
                }
                .disabled(model.isStarting || model.isRunning)
                Picker("audio.output", selection: $model.outputUID) {
                    ForEach(model.outputs) { Text($0.name).tag($0.uid) }
                }
                .disabled(model.isClicking)
                if let input = model.selectedInput {
                    LabeledContent("audio.format") {
                        Text("audio.formatValue \(Int(input.sampleRate)) \(Int(input.bufferFrames))").monospacedDigit()
                    }
                }
            }
            if model.inputs.isEmpty { Text("audio.noDevices").foregroundStyle(.secondary) }
            if model.isStarting { ProgressView("audio.waitingInput").controlSize(.small) }
            if model.isStartingClick { ProgressView("audio.waitingOutput").controlSize(.small) }
            if let snapshot = model.snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(min(snapshot.peak, 1))) { Text("audio.level") }
                    Text(snapshot.peak >= 0.99 ? "audio.clipping" : snapshot.peak < 0.001 ? "audio.noSignal" : "audio.signalPresent")
                    LabeledContent("audio.frames", value: snapshot.totalFrames.formatted())
                    LabeledContent("audio.drops", value: snapshot.droppedPackets.formatted())
                    LabeledContent("audio.timestamps") {
                        Text(snapshot.hostTimeValid ? "audio.valid" : "audio.unavailable")
                    }
                }
                .accessibilityIdentifier("audio.metrics")
            }
            if let error = model.error {
                AudioErrorView(error: error)
            }
            HStack {
                Button(model.isRunning ? "audio.stop" : "audio.start") {
                    if model.isRunning { model.stop() } else { Task { await model.start() } }
                }
                .disabled(model.inputs.isEmpty || model.isStarting)
                .accessibilityIdentifier("audio.capture")
                Button(model.isClicking ? "audio.stopClick" : "audio.startClick") { Task { await model.toggleClick() } }
                    .disabled(model.outputs.isEmpty || model.isStartingClick)
                Spacer()
                Button("audio.refresh") { model.stop(); Task { await model.refresh() } }
                Button("common.done") { model.stop(); dismiss() }.keyboardShortcut(.defaultAction)
            }
            Text("audio.clickExplanation").font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 600)
        .task { await model.refresh() }
        .onChange(of: model.inputUID) { _, _ in model.channel = 1 }
        .onDisappear { model.stop() }
        .task(id: model.isRunning) {
            guard model.isRunning else { return }
            while !Task.isCancelled && model.isRunning {
                await model.updateMetrics()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}

struct AudioErrorView: View {
    let error: AudioBackendError
    var body: some View {
        VStack(alignment: .leading) {
            Label(key, systemImage: "exclamationmark.triangle")
            if case let .system(code) = error { Text(verbatim: "OSStatus: \(code)").font(.caption) }
        }
        .foregroundStyle(.red)
    }
    private var key: LocalizedStringKey {
        switch error {
        case .system: "audio.error.system"
        case .unavailableDevice: "audio.error.device"
        case .invalidChannel: "audio.error.channel"
        case .invalidFormat: "audio.error.format"
        case .permissionDenied: "audio.error.permission"
        case .allocationFailed: "audio.error.memory"
        }
    }
}
