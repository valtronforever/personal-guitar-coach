import SwiftUI
import Audio
import Domain

struct PreviewControls: View {
    @Bindable var model: PreviewModel
    @Environment(AudioSessionStore.self) private var audio
    @Environment(LocalDataStore.self) private var data
    @Environment(AppSettings.self) private var settings
    @State private var showsOptions = false
    @State private var showsAudio = false
    @State private var seekValue = 0.0
    private var unavailable: Bool {
        audio.state?.purpose != nil && audio.state?.transportRequestID != model.requestID ||
        audio.state?.isClicking == true || audio.state?.isStartingClick == true
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(model.resumeTick == nil ? "playback.play" : "playback.resume") {
                    Task { await model.start(tuning: data.preferences.instrument.tuning, audio: audio) }
                }.disabled(model.requestID != nil || model.isBusy || unavailable || audio.selectedOutput == nil || !audio.canEdit)
                    .accessibilityIdentifier("playback.play")
                Button("playback.pause") { Task { await model.stop(audio: audio, pause: true) } }
                    .disabled(model.requestID == nil || model.isBusy).accessibilityIdentifier("playback.pause")
                Button("playback.stop") { Task { await model.stop(audio: audio) } }
                    .disabled(model.requestID == nil && model.resumeTick == nil).accessibilityIdentifier("playback.stop")
                if let beat = model.countInBeat { Text("playback.countInBeat \(beat)").monospacedDigit() }
                Spacer()
                Button("playback.options", systemImage: "slider.horizontal.3") { showsOptions.toggle() }.labelStyle(.iconOnly).help(Text("playback.options")).accessibilityIdentifier("playback.options")
                    .popover(isPresented: $showsOptions, arrowEdge: .trailing) { options.environment(\.locale, settings.locale) }
                Button("audio.title", systemImage: "waveform") { showsAudio = true }.labelStyle(.iconOnly).help(Text("audio.title"))
            }
            if unavailable { Text("playback.audioInUse").foregroundStyle(.secondary) }
            else if audio.selectedOutput == nil { Text("playback.chooseOutput").foregroundStyle(.secondary) }
            if let key = model.errorKey { Label(LocalizedStringKey(key), systemImage: "exclamationmark.triangle") }
            if let error = audio.error { AudioErrorView(error: error) }
            if case let .interrupted(error) = audio.state?.phase { AudioErrorView(error: error) }
        }.font(.callout).padding(.horizontal, 16).padding(.vertical, 8)
            .sheet(isPresented: $showsAudio) { AudioProbeView().environment(\.locale, settings.locale) }
            .onChange(of: model.firstBar) { _, value in if model.lastBar < value { model.lastBar = value }; seekValue = Double(model.range.lowerBound) }
            .onChange(of: model.lastBar) { _, _ in seekValue = Double(model.range.lowerBound) }
    }
    private var options: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("playback.optionsExplanation").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Stepper(value: $model.bpm, in: 40...200, step: 1) { Text("playback.tempo \(Int(model.bpm))") }
                            .accessibilityIdentifier("playback.tempo")
                        Text(verbatim: model.exercise?.timeSignature.rawValue ?? "4/4")
                        Picker("playback.countIn", selection: $model.countInBars) {
                            Text("playback.countInNone").tag(0)
                            Text("playback.countInOne").tag(1)
                            Text("playback.countInTwo").tag(2)
                        }.frame(maxWidth: 220)
                    }
                    HStack {
                        Picker("playback.firstBar", selection: $model.firstBar) {
                            ForEach(1...model.barCount, id: \.self) { Text($0, format: .number).tag($0) }
                        }
                        Picker("playback.lastBar", selection: $model.lastBar) {
                            ForEach(model.firstBar...max(model.firstBar, model.barCount), id: \.self) { Text($0, format: .number).tag($0) }
                        }
                        Toggle("playback.loop", isOn: $model.loops)
                    }
                    HStack {
                        Toggle("playback.click", isOn: $model.clickEnabled)
                        Toggle("playback.accent", isOn: $model.accent)
                    }
                    HStack {
                        Slider(value: $model.clickVolume, in: 0...1) { Text("playback.clickVolume") }
                        Slider(value: $model.toneVolume, in: 0...1) { Text("playback.toneVolume") }
                    }
                    Slider(value: $seekValue, in: Double(model.range.lowerBound)...Double(max(model.range.lowerBound, model.range.upperBound - 1)), step: 240) { Text("playback.seek") }
                        onEditingChanged: { editing in if !editing { Task { await model.seek(Int64(seekValue), audio: audio) } } }
                        .accessibilityIdentifier("playback.seek")
                    Text("playback.seekExplanation").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.disabled(model.requestID != nil || model.isBusy)
        }.frame(width: 600, height: 350).padding(16)
    }

}
