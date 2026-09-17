import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Domain
import Learning
import Audio

struct SelfPracticeRecordingView: View {
    let context: SelfPracticeRecordingContext
    @State private var model = SelfPracticeRecordingModel()
    @State private var bpm: Double
    @State private var showsAudio = false
    @State private var choosingDestination = false
    @State private var playbackFailed = false
    @Environment(AudioSessionStore.self) private var audio
    @Environment(CalibrationStore.self) private var calibration
    @Environment(LocalDataStore.self) private var localData
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    init(context: SelfPracticeRecordingContext) {
        self.context = context; _bpm = State(initialValue: context.exercise.defaultBPM)
    }
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }
    private var text: LessonText { context.snapshot.text(for: language) }
    private var seconds: Double { Double(context.exercise.durationTicks) * context.exercise.timeSignature.secondsPerTick(bpm: bpm) }
    private var canRecord: Bool { (try? context.transport(bpm: bpm)) != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("selfRecording.title").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("selfRecording.close") { model.cancel(); dismiss() }.keyboardShortcut(.cancelAction).disabled(model.saving || choosingDestination)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(verbatim: text.activities[context.snapshot.activity.id]?.title ?? text.title).font(.headline)
                    Text("selfRecording.help").fixedSize(horizontal: false, vertical: true)
                    LabeledContent("selfRecording.instrument") {
                        Text("selfRecording.instrumentValue \(context.snapshot.instrument.tuning.name) \(context.snapshot.instrument.fretCount)")
                    }
                    HStack {
                        Stepper(value: $bpm, in: context.exercise.minimumBPM...context.exercise.maximumBPM, step: 1) {
                            HStack { Text("selfRecording.tempo \(Int(bpm))"); Text(LocalizedStringKey(context.exercise.timeSignature.tempoUnitKey)) }
                        }.disabled(model.isBusy || model.saving || choosingDestination).accessibilityIdentifier("selfRecording.tempo")
                        Spacer()
                        Text("selfRecording.duration \(Int(ceil(seconds)))")
                    }
                    if !canRecord { Text("selfRecording.tooLong").foregroundStyle(.secondary) }
                    Button("selfRecording.audioSetup") { showsAudio = true }.disabled(model.isBusy || model.saving)
                    if let state = model.snapshot, model.isBusy {
                        InputLevelMeter(snapshot: state.meters, active: state.phase == .running)
                    }
                    if let timeline = try? TimelineModel(exercise: context.exercise, instrument: context.snapshot.instrument.tuning) {
                        PracticeTablatureView(model: timeline, selectedIDs: [], firstBar: 1, lastBar: Int(timeline.barCount),
                            displayTick: model.displayTick, attemptID: context.id, playing: model.isBusy, onSelect: { _, _ in })
                            .frame(minHeight: 220, idealHeight: 260, maxHeight: 340)
                    }
                    Text(LocalizedStringKey("selfRecording.phase." + model.phase.rawValue)).accessibilityIdentifier("selfRecording.phase")
                    if let error = model.backendError { AudioErrorView(error: error) }
                    if let key = model.errorKey { Text(LocalizedStringKey(key)).foregroundStyle(.secondary) }
                    if playbackFailed { Text("selfRecording.openFailed").foregroundStyle(.secondary) }
                    if let take = model.take {
                        Label(LocalizedStringKey(take.metadata.completed ? "selfRecording.complete" : "selfRecording.early"), systemImage: "waveform")
                        Text("selfRecording.recordedTempo \(Int(take.metadata.bpm))")
                        Text("selfRecording.channels").font(.callout)
                        Text("selfRecording.temporary").font(.caption).foregroundStyle(.secondary)
                        if let url = model.savedURL { Text(verbatim: url.lastPathComponent).textSelection(.enabled) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                if !model.isBusy {
                    Button(LocalizedStringKey(model.take == nil ? "selfRecording.start" : "selfRecording.again")) {
                        playbackFailed = false
                        model.start(context: context, bpm: bpm, coordinator: audio.coordinator,
                            outputAlignment: calibration.outputProfile(for: audio.state?.outputEndpoint))
                    }.disabled(model.saving || choosingDestination || !canRecord).accessibilityIdentifier("selfRecording.start")
                } else {
                    Button("selfRecording.stop") { model.stopAndReview() }
                        .disabled(model.phase != .recording && model.phase != .draining)
                        .accessibilityIdentifier("selfRecording.stop")
                    Button("selfRecording.cancel") { model.cancel() }
                }
                Spacer()
                if model.take != nil {
                    Button("selfRecording.save") { save() }.disabled(model.isBusy || model.saving || choosingDestination).accessibilityIdentifier("selfRecording.save")
                    if let url = model.savedURL {
                        Button("selfRecording.openSaved") { playbackFailed = !NSWorkspace.shared.open(url) }.disabled(model.saving)
                    }
                }
                if model.saving { ProgressView().controlSize(.small).accessibilityLabel(Text("selfRecording.saving")) }
            }
        }.padding(20).frame(minWidth: 740, idealWidth: 800, minHeight: 600, idealHeight: 720)
            .interactiveDismissDisabled(model.isBusy || model.saving)
            .sheet(isPresented: $showsAudio) { AudioProbeView().environment(\.locale, settings.locale) }
            .onChange(of: localData.preferences.instrument) { _, _ in model.cancel(); dismiss() }
            .onChange(of: model.savedURL) { _, _ in playbackFailed = false }
            .onDisappear { model.cancel() }
    }
    private func save() {
        guard !choosingDestination else { return }; choosingDestination = true
        let panel = NSSavePanel(); panel.allowedContentTypes = [.wav]; panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Guitar-practice-\(model.take?.metadata.id.uuidString ?? context.id.uuidString).wav"
        panel.begin { response in
            choosingDestination = false
            guard response == .OK, let url = panel.url else { return }
            Task { await model.save(to: url) }
        }
    }
}
