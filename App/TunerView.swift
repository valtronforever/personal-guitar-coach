import SwiftUI
import Domain
import Audio

struct TunerView: View {
    @Environment(AudioSessionStore.self) private var audio
    @Environment(LocalDataStore.self) private var data
    @Environment(AppSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @State private var model = TunerModel()
    @State private var showsAudio = false
    private var tuning: TuningProfile { data.preferences.instrument.tuning }
    private var ownsCapture: Bool { audio.state?.purpose == .tuner }
    private var running: Bool { ownsCapture && audio.state?.phase == .running }
    private var busyElsewhere: Bool {
        (audio.state?.purpose != nil && !ownsCapture) || audio.state?.isClicking == true || audio.state?.isStartingClick == true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Picker("tuning.profile", selection: Binding(get: { tuning.id }, set: { id in Task { await data.selectTuning(id: id) } })) {
                        ForEach(data.preferences.availableTunings) { profile in TuningName(profile: profile).tag(profile.id) }
                    }.disabled(!data.canEditPreferences).accessibilityIdentifier("tuner.profile")
                    SettingsLink { Text("tuner.editTuning") }
                }
                HStack {
                    LabeledContent("tuning.reference") { Text(tuning.referenceA4, format: .number.precision(.fractionLength(1))) }
                    Spacer()
                    Button("tuner.automatic") { model.configure(tuning: tuning, mode: .automatic) }
                        .buttonStyle(.bordered).tint(model.mode == .automatic ? .accentColor : .secondary)
                        .accessibilityValue(Text(model.mode == .automatic ? "tuner.selected" : "tuner.unselected"))
                        .accessibilityIdentifier("tuner.automatic")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(tuning.strings.reversed()) { string in
                        let selected = model.mode == .manual(string: string.number)
                        Button { model.configure(tuning: tuning, mode: .manual(string: string.number)) } label: {
                            VStack(spacing: 5) {
                                Text("tuning.stringNumber \(string.number)").font(.caption)
                                Text(verbatim: string.openPitch.name(spelling: tuning.preferredSpelling)).font(.title3.monospaced().bold())
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.caption)
                            }.frame(maxWidth: .infinity).padding(.vertical, 7).contentShape(Rectangle())
                        }.buttonStyle(.bordered).tint(selected ? .accentColor : .secondary)
                            .accessibilityValue(Text(selected ? "tuner.selected" : "tuner.unselected"))
                            .accessibilityHint(Text("tuner.manualHint"))
                            .accessibilityIdentifier("tuner.string.\(string.number)")
                    }
                }
                TunerReadingView(reading: model.reading, spelling: tuning.preferredSpelling)
                if model.isStale { Label("tuner.stale", systemImage: "clock").foregroundStyle(.secondary) }
                if model.reading.feedback == .chooseString { Text("tuner.confirmString").font(.callout).foregroundStyle(.secondary) }
                Text("tuner.singleString").font(.callout).foregroundStyle(.secondary)
                Divider()
                HStack {
                    Label { Text(verbatim: audio.selectedInput?.name ?? settings.localized("audio.chooseInput")) } icon: { Image(systemName: "waveform") }
                    if audio.selectedInput != nil { Text("tuner.channel \(audio.selection.inputChannel)").foregroundStyle(.secondary) }
                    Spacer()
                    Button("audio.title") { showsAudio = true }.accessibilityIdentifier("tuner.audioSetup")
                }
                if busyElsewhere {
                    Label("tuner.audioInUse", systemImage: "exclamationmark.triangle")
                    if audio.state?.purpose == .practice {
                        Button("navigation.practice") { navigation.destination = .practice }
                    }
                }
                if let error = audio.error { AudioErrorView(error: error) }
                if let phase = audio.state?.phase {
                    switch phase {
                    case let .failed(error), let .interrupted(error):
                        if error != audio.error { AudioErrorView(error: error) }
                    default: EmptyView()
                    }
                }
                if let error = audio.storageError { Label(LocalizedStringKey(error), systemImage: "exclamationmark.triangle") }
                if data.preferencesIssue != nil { Label("tuner.profileUnavailable", systemImage: "exclamationmark.triangle") }

            }.padding(CoachLayout.padding).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
                HStack {
                    Button(ownsCapture ? "tuner.stop" : "tuner.start") {
                        Task {
                            model.stopReading()
                            if ownsCapture { await audio.stop(purpose: .tuner) }
                            else { await audio.start(purpose: .tuner) }
                        }
                    }.buttonStyle(.borderedProminent)
                        .disabled(!ownsCapture && (busyElsewhere || !audio.canEdit || audio.selectedInput == nil || !data.hasLoaded || data.preferencesIssue != nil))
                        .accessibilityIdentifier("tuner.capture")
                    if ownsCapture && audio.state?.phase.isStarting == true { ProgressView().controlSize(.small).accessibilityLabel("common.loading") }
                    Text(running ? "tuner.listening" : "tuner.startExplanation").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, CoachLayout.padding).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading).background(.bar)
        }
        .sheet(isPresented: $showsAudio) { AudioProbeView().environment(\.locale, settings.locale) }
        .task {
            audio.activate()
            while !Task.isCancelled {
                model.configure(tuning: tuning)
                if running { model.consume(audio.state?.meters?.analysis) }
                else { model.stopReading() }
                do { try await Task.sleep(for: .milliseconds(50)) } catch { break }
            }
        }
        .onChange(of: tuning, initial: true) { _, value in model.configure(tuning: value) }
        .onDisappear { model.stopReading(); Task { await audio.stop(purpose: .tuner) } }
    }
}

struct TunerReadingView: View {
    let reading: TunerReading
    var spelling: PitchSpelling = .sharps
    private var feedbackKey: String { "tuner.feedback.\(reading.feedback.rawValue)" }
    private var color: Color { reading.feedback == .inTune ? .green : [.flat, .sharp, .clipping].contains(reading.feedback) ? .orange : .primary }
    private var symbol: String {
        switch reading.feedback {
        case .inTune: "checkmark.circle.fill"
        case .flat: "arrow.up.circle"
        case .sharp: "arrow.down.circle"
        case .clipping, .invalid, .unsupportedTarget: "exclamationmark.triangle"
        case .chooseString: "hand.point.up.left"
        default: "tuningfork"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 32) {
                VStack(spacing: 2) {
                    Text("tuner.detected").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: reading.detectedPitch?.name(spelling: spelling) ?? "—").font(.system(size: 48, weight: .semibold, design: .rounded))
                        .accessibilityElement(children: .ignore).accessibilityLabel(Text(verbatim: reading.detectedPitch?.name(spelling: spelling) ?? "—"))
                        .accessibilityIdentifier("tuner.detectedNote")
                    if let frequency = reading.frequency { Text(frequency, format: .number.precision(.fractionLength(2))).monospacedDigit() }
                    Text("tuner.hertz").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
                VStack(spacing: 3) {
                    Text("tuner.target").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: reading.targetPitch?.name(spelling: spelling) ?? "—").font(.title.bold()).accessibilityElement(children: .ignore).accessibilityLabel(Text(verbatim: reading.targetPitch?.name(spelling: spelling) ?? "—")).accessibilityIdentifier("tuner.targetNote")
                    if let string = reading.targetString { Text("tuning.stringNumber \(string)").font(.callout) }
                    if let frequency = reading.targetFrequency { Text(frequency, format: .number.precision(.fractionLength(2))).monospacedDigit() }
                }.frame(maxWidth: .infinity)
            }
            TunerCentsMeter(cents: reading.indicatorCents).frame(height: 45).accessibilityHidden(true)
            HStack {
                LabeledContent("tuner.deviation") {
                    if let cents = reading.cents { Text(cents, format: .number.sign(strategy: .always()).precision(.fractionLength(1))).monospacedDigit() }
                    else { Text(verbatim: "—") }
                }
                Spacer()
                if let clarity = reading.clarity {
                    LabeledContent("tuner.clarity") { Text(clarity, format: .percent.precision(.fractionLength(0))) }.help(Text("tuner.clarityHelp"))
                }
            }.font(.callout)
            Label(LocalizedStringKey(feedbackKey), systemImage: symbol).font(.title3.weight(.semibold)).foregroundStyle(color)
                .accessibilityElement(children: .ignore).accessibilityLabel(Text(LocalizedStringKey(feedbackKey)))
                .accessibilityIdentifier("tuner.feedback")
        }.accessibilityElement(children: .contain).padding(18).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TunerCentsMeter: View {
    let cents: Double?
    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                let inset: CGFloat = 8, width = max(0, size.width - inset * 2), y = size.height / 2
                context.fill(Path(CGRect(x: inset + width * 0.45, y: 0, width: width * 0.1, height: size.height)), with: .color(.green.opacity(0.2)))
                var line = Path(); line.move(to: CGPoint(x: inset, y: y)); line.addLine(to: CGPoint(x: inset + width, y: y))
                for fraction in [0.0, 0.45, 0.5, 0.55, 1] {
                    let x = inset + width * fraction
                    line.move(to: CGPoint(x: x, y: y - 6)); line.addLine(to: CGPoint(x: x, y: y + 6))
                }
                context.stroke(line, with: .foreground, lineWidth: 1)
                if let cents, cents.isFinite {
                    let x = inset + width * CGFloat((max(-50, min(50, cents)) + 50) / 100)
                    context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)), with: .foreground)
                }
            }
            HStack { Text(verbatim: "−50"); Spacer(); Text(verbatim: "0"); Spacer(); Text(verbatim: "+50") }.font(.caption.monospaced())
        }
    }
}
