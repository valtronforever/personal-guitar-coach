import SwiftUI
import Learning
import Domain
import Audio

struct PracticeEntryView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(LocalDataStore.self) private var data
    @Environment(LessonLibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings
    @Environment(AudioSessionStore.self) private var audio
    @Environment(AssessmentStore.self) private var assessment
    @Environment(PracticeModel.self) private var model
    @Environment(CalibrationStore.self) private var calibration
    @State private var showsAudio = false
    @State private var detailResult: AssessedPractice?
    @State private var pendingAudioSetup = false
    @State private var showsOptions = true
    @State private var visualMode = "fretboard"
    @State private var selectedPosition: FretPosition?
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }
    private var instrument: InstrumentProfile { model.phase.active ? model.machine.configuration?.instrument ?? data.preferences.instrument : data.preferences.instrument }
    private var tuning: TuningProfile { model.request?.archivedTuning ?? model.request?.exercise.requiredTuning ?? instrument.tuning }
    private var exceedsFretCount: Bool {
        guard !model.phase.active, let exercise = model.request?.exercise else { return false }
        return exercise.events.filter { model.selectedEventIDs.contains($0.id) }.flatMap(\.positions).contains { !instrument.contains($0) }
    }
    private var detectedPitch: Pitch? { model.latestFrequency.flatMap { try? Pitch.nearest(to: $0, referenceA4: tuning.referenceA4) } }

    var body: some View {
        if navigation.practiceAdaptationFailed {
            FeatureStateView(title: "navigation.practice", message: "lesson.adaptationUnavailable", symbol: "guitars") {
                SettingsLink { Text("settings.title") }
            }
        } else if let request = navigation.practiceRequest {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let title = ResultPresentation.lessonTitle(id: request.lessonID, version: request.lessonVersion, tuning: tuning, lessons: library.lessons, language: language, frets: request.frets) {
                        Text(verbatim: title).font(.title2.bold()).accessibilityIdentifier("practice.selectedExercise")
                    } else { Text("result.savedExercise").font(.title2.bold()).accessibilityIdentifier("practice.selectedExercise") }
                    DisclosureGroup("practice.options", isExpanded: $showsOptions) {
                        options(request.exercise).padding(.top, 10)
                    }
                    status
                    if exceedsFretCount { Label("practice.error.fretCount", systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
                    Picker("tab.visualMode", selection: $visualMode) {
                        Text("fretboard.title").tag("fretboard")
                        Text("tab.title").tag("tab")
                    }.pickerStyle(.segmented)
                    if visualMode == "fretboard" {
                        FretboardView(model: FretboardModel(tuning: tuning, orientation: instrument.orientation, frets: instrument.frets,
                            positions: model.expectedPositions), selected: $selectedPosition,
                            detectedPitch: detectedPitch, compact: true)
                    } else if let timeline = try? TimelineModel(exercise: request.exercise, instrument: tuning) {
                        TablatureView(model: timeline, selectedIDs: model.selectedEventIDs,
                            cursorTick: model.countInBeat == nil ? model.cursorTick : nil, instructionsKey: "practice.tabInstructions") { id, extending in
                                guard let event = request.exercise.events.first(where: { $0.id == id }) else { return }
                                let bar = Int(event.startTick / request.exercise.timeSignature.ticksPerBar) + 1
                                model.seekBar(bar, extending: extending)
                            }
                    }
                    Text("practice.expectedExplanation").font(.caption).foregroundStyle(.secondary)
                    if let result = assessment.latest, result.id == model.latestEvidence?.id {
                        AssessmentSummaryView(result: result)
                        Button("result.viewDetails") {
                            model.setRepeat(false); model.stop(); detailResult = result
                        }.accessibilityIdentifier("result.viewDetails")
                    } else if assessment.isSaving {
                        ProgressView("assessment.processing")
                    } else if let evidence = model.latestEvidence {
                        GroupBox("practice.attemptSummary") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStringKey("practice.phase." + evidence.phase.rawValue)).font(.headline)
                                Text("practice.capturedAttacks \(evidence.attacks.count)")
                                Text("practice.captureOnly").foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.accessibilityIdentifier("practice.attemptSummary")
                    }
                }.padding(CoachLayout.padding)
            }
            .safeAreaInset(edge: .bottom) { actions }
            .onChange(of: navigation.practiceRequest, initial: true) { _, value in model.configure(value) }
            .onChange(of: model.phase) { _, value in if value == .countIn || value == .running { showsOptions = false } }
            .sheet(isPresented: $showsAudio) { AudioProbeView().environment(\.locale, settings.locale) }
            .sheet(item: $detailResult, onDismiss: {
                if pendingAudioSetup { pendingAudioSetup = false; showsAudio = true }
            }) { result in
                VStack(spacing: 0) {
                    HStack { Spacer(); Button("common.close") { detailResult = nil } }.padding(12)
                    ResultDetailView(result: result, history: data.records.compactMap { $0.assessment?.payload },
                        onRetry: { request in detailResult = nil; navigation.openPractice(request) },
                        onAudioSetup: { pendingAudioSetup = true; detailResult = nil },
                        onTuner: { target in
                            guard data.canEditPreferences else { return false }
                            await data.restoreArchivedTuning(target)
                            guard data.operationError == nil, data.preferences.instrument.tuning.hasSamePitches(as: target) else { return false }
                            detailResult = nil; navigation.destination = .tuner; return true
                        })
                }.environment(\.locale, settings.locale)
            }
            .onDisappear { model.stop(.changedExercise) }
        } else {
            FeatureStateView(title: "practice.emptyTitle", message: "practice.empty", symbol: "play.circle") {
                Button("navigation.lessons") { navigation.destination = .lessons }
                assessmentNotices
            }
        }
    }

    private func options(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TuningRequirementView(exercise: exercise, instrument: data.preferences.instrument.tuning)
            if let archived = model.request?.archivedTuning {
                Text("result.archivedRetry").font(.callout)
                if !data.preferences.instrument.tuning.hasSamePitches(as: archived) {
                    Text("result.retryTuningMismatch").foregroundStyle(.secondary)
                    Button("result.restoreTuning") { Task { await data.restoreArchivedTuning(archived) } }
                        .disabled(!data.canEditPreferences || model.isBusy)
                }
            }
            HStack {
                TuningName(profile: tuning)
                Text(verbatim: tuning.strings.reversed().map { $0.openPitch.name(spelling: tuning.preferredSpelling) }.joined(separator: " · "))
            }
            Text("practice.stringOrder").font(.caption)
            Text("result.fretCount \(instrument.fretCount)")
            Toggle("practice.tunedConfirmation", isOn: Binding(get: { model.physicallyTuned }, set: { model.physicallyTuned = $0 }))
                .disabled(model.isBusy).accessibilityIdentifier("practice.tuned")
            HStack {
                Stepper("practice.selectedTempo \(Int(model.bpm))", value: Binding(get: { model.bpm }, set: { model.setTempo($0) }),
                    in: exercise.minimumBPM...exercise.maximumBPM, step: 1).accessibilityIdentifier("practice.tempo")
                Spacer()
                Stepper("practice.firstBarValue \(model.firstBar)", value: Binding(get: { model.firstBar }, set: { model.setBars(first: $0, last: model.lastBar) }), in: 1...model.barCount)
                Stepper("practice.lastBarValue \(model.lastBar)", value: Binding(get: { model.lastBar }, set: { model.setBars(first: model.firstBar, last: $0) }), in: model.firstBar...max(model.firstBar, model.barCount))
            }
            Toggle("practice.repeat", isOn: Binding(get: { model.repeatEnabled }, set: { model.setRepeat($0) }))
            Text("practice.repeatExplanation").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("playback.clickVolume")
                Slider(value: Binding(get: { model.clickVolume }, set: { model.setClickVolume($0) }), in: 0...1)
                    .disabled(model.isBusy).accessibilityLabel(Text("playback.clickVolume"))
                Button("audio.title") { showsAudio = true }
                Button("navigation.tuner") { model.stop(); navigation.destination = .tuner }
            }
            Text(LocalizedStringKey("calibration.method." + ((model.phase.active ? model.machine.configuration?.calibration : calibration.profile(for: audio.state?.calibrationRoute))?.method.rawValue ?? "none")))
            Text("practice.pitchOnlyExplanation").font(.callout).foregroundStyle(.secondary)
        }
    }
    private var assessmentNotices: some View {
        Group {
            if let error = assessment.errorKey { Text(LocalizedStringKey(error)).foregroundStyle(.red) }
            if assessment.needsRetry {
                Button("assessment.retrySave") { Task { if await assessment.retry() { await data.refreshHistory() } } }
            }
            if !assessment.warnings.isEmpty { Text("storage.historyProblem").foregroundStyle(.secondary) }
        }
    }
    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            assessmentNotices
            Text(LocalizedStringKey("practice.phase." + model.phase.rawValue)).font(.headline)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("practice.phase")
            if audio.state?.calibrationRoute == nil { Text("practice.error.route").foregroundStyle(.secondary) }
            if let reason = model.machine.reason { Text(LocalizedStringKey("practice.reason." + reason.rawValue)) }
            if let error = model.errorKey { Text(LocalizedStringKey(error)).foregroundStyle(.red) }
            if let error = model.backendError { AudioErrorView(error: error) }
            if model.phase == .preflight {
                Text("practice.pluckForCheck")
                ProgressView(value: Double(min(audio.state?.meters?.peak ?? 0, 1))) { Text("audio.level") }
            }
            if let beat = model.countInBeat, model.phase == .countIn { Text("practice.countInBeat \(beat)").font(.title.bold()).monospacedDigit() }
            if model.phase == .running {
                HStack {
                    Text("practice.observed")
                    if let frequency = model.latestFrequency, let pitch = detectedPitch {
                        Text(verbatim: pitch.name(spelling: tuning.preferredSpelling)).font(.headline)
                        Text(frequency, format: .number.precision(.fractionLength(1)))
                        Text("practice.hz")
                    } else { Text("practice.noStablePitch").foregroundStyle(.secondary) }
                }
            }
            if model.phase == .finalizing { ProgressView("practice.waitingTail") }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .contain)
    }
    private var actions: some View {
        HStack {
            Button(model.phase == .paused ? "practice.resume" : "practice.start") { model.start(instrument: data.preferences.instrument) }
                .disabled(exceedsFretCount || model.isBusy || assessment.pending != nil || assessment.isSaving || model.request == nil || audio.state?.calibrationRoute == nil).accessibilityIdentifier("practice.start")
            Button("playback.pause") { model.pause() }.disabled(!model.phase.active || model.phase == .finalizing)
                .accessibilityIdentifier("practice.pause")
            Button("playback.stop") { model.stop() }.disabled(!model.isBusy).accessibilityIdentifier("practice.stop")
            Spacer()
            if model.completedCount > 0 { Text("practice.completedAttempts \(model.completedCount)").font(.caption) }
            Button("practice.backToLesson") {
                model.stop(.changedExercise)
                if let request = navigation.practiceRequest { navigation.lessonPath = [request.lessonID] }
                navigation.destination = .lessons
            }
        }.padding(.horizontal, CoachLayout.padding).padding(.vertical, 12).background(.bar)
    }
}
