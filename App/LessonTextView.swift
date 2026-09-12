import SwiftUI
import Learning
import Domain
import Persistence
import Audio

struct LessonTextView: View {
    private var lesson: LoadedLesson { selection.sourceLesson }
    private let restoresBookmark: Bool
    @State private var selection: LessonSelection
    @State private var preview = PreviewModel()
    @Environment(AudioSessionStore.self) private var audio
    @State private var visualMode = "fretboard"
    @Environment(AppSettings.self) private var settings
    @Environment(LocalDataStore.self) private var localData
    @Environment(ReadingProgressStore.self) private var reading
    @Environment(AppNavigation.self) private var navigation
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }

    init(lesson: LoadedLesson, bookmark: LessonBookmark?, tuning: TuningProfile = .standard, frets: GuitarFretCount = .twentyFour) {
        restoresBookmark = bookmark?.lessonVersion == lesson.manifest.version && bookmark?.stepID != nil
        _selection = State(initialValue: LessonSelection(lesson: lesson, bookmark: bookmark, tuning: tuning, frets: frets))
    }

    var body: some View {
        @Bindable var selection = selection
        let text = lesson.text(for: language)
        Group {
                VStack(spacing: 0) {
                    ReadingProgressNotice()
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: CoachLayout.padding) {
                                lessonContent
                            }
                            .frame(maxWidth: 740, alignment: .leading)
                            .padding(CoachLayout.padding)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .onChange(of: selection.stepID) { _, id in if let id { proxy.scrollTo(id, anchor: .top) } }
                        .onAppear { if restoresBookmark, let id = selection.stepID { proxy.scrollTo(id, anchor: .top) } }
                    }.frame(minHeight: 140)
                    Divider()
                    if selection.exercise != nil { PreviewControls(model: preview) }
                    Picker("tab.visualMode", selection: $visualMode) {
                        Text("fretboard.title").tag("fretboard")
                        Text("tab.title").tag("tablature")
                        Text("staff.title").tag("staff")
                    }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 8).accessibilityIdentifier("lesson.visualMode")
                    if visualMode == "fretboard" {
                        FretboardView(model: playbackFretboard ?? selection.fretboard(instrument: localData.preferences.instrument), selected: $selection.selectedPosition, compact: true).padding(12)
                    } else if let exercise = selection.exercise, let model = try? TimelineModel(exercise: exercise, instrument: localData.preferences.instrument.tuning) {
                        if visualMode == "staff" {
                            ScrollView(.vertical) {
                                StaffView(timeline: model, selectedIDs: selection.selectedIDs, cursorTick: preview.cursorTick) { id, extending in
                                    selection.selectEvent(id, exerciseID: exercise.id, extending: extending); saveBookmark()
                                }.padding(12)
                            }.frame(minHeight: 180, maxHeight: 360).accessibilityIdentifier("staff.panel")
                        } else {
                            TablatureView(model: model, selectedIDs: selection.selectedIDs, cursorTick: preview.cursorTick) { id, extending in
                                selection.selectEvent(id, exerciseID: exercise.id, extending: extending); saveBookmark()
                            }.padding(12)
                        }
                    } else {
                        Text("tab.noSequence").foregroundStyle(.secondary).padding()
                    }
                }
        }
        .onAppear { saveBookmark() }
        .onChange(of: localData.preferences.instrument) { _, instrument in
            selection.updateInstrument(instrument); saveBookmark()
        }
        .task(id: selection.previewContext) {
            await preview.configure(selection.exercise, contextID: selection.previewContextID, audio: audio)
        }
        .onChange(of: audio.state) { _, state in preview.update(state) }
        .onChange(of: localData.preferences.instrument) { _, _ in Task { await preview.stop(audio: audio) } }
        .onDisappear { Task { await preview.stop(audio: audio) } }
        .navigationTitle(text.title)
    }
    private var lessonContent: some View {
        let text = lesson.text(for: language)
        return VStack(alignment: .leading, spacing: CoachLayout.padding) {
        Text(verbatim: text.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader).accessibilityIdentifier("lesson.title")
        VStack(alignment: .leading, spacing: 8) {
            Text("content.goal").font(.headline)
            Text(verbatim: text.goal)
        }
        Text(verbatim: text.body).textSelection(.enabled)
        if selection.policy?.enabled == true { positionPicker }
        if let failure = selection.failure {
            Label(LocalizedStringKey("lesson.activity.error." + failure.rawValue), systemImage: "exclamationmark.triangle")
                .accessibilityIdentifier("lesson.activity.unavailable")
        }
        if let snapshot = selection.snapshot, let variant = snapshot.text(for: language).activities[snapshot.activity.id] {
            LessonVariantView(variant: variant, instrument: InstrumentProfile(tuning: snapshot.exercises.first?.requiredTuning ?? snapshot.instrument.tuning, frets: snapshot.instrument.frets),
                policy: selection.sourceLesson.manifest.adaptation?.policy)
        }
        lessonSteps
        Divider()
        Toggle("reading.markRead", isOn: Binding(get: {
            reading.progress.lessons[lesson.id]?.readVersion == lesson.manifest.version
        }, set: { reading.setRead($0, lessonID: lesson.id, version: lesson.manifest.version, stepID: selection.stepID, activityChoices: selection.activityChoices, activityConfirmations: selection.activityConfirmations) }))
            .disabled(!reading.canEdit).accessibilityIdentifier("lesson.markRead")
        Text("reading.explanation").font(.caption).foregroundStyle(.secondary)
        if selection.snapshot != nil, selection.policy?.enabled == true {
            Toggle("lesson.activity.selfConfirm", isOn: Binding(get: { selection.selfConfirmed }, set: {
                selection.setSelfConfirmed($0); saveBookmark()
            })).accessibilityIdentifier("lesson.activity.selfConfirm")
            Text("lesson.activity.selfConfirmHelp").font(.caption).foregroundStyle(.secondary)
        }
        ForEach(Array(selection.practiceEntries.enumerated()), id: \.element.id) { index, entry in
            if let snapshot = selection.snapshot,
               let request = PracticeRequest(lesson: lesson, snapshot: snapshot, entryID: entry.id,
                   selfConfirmation: selection.selfConfirmed ? selection.activityConfirmations[snapshot.activity.id] : nil) {
                TuningRequirementView(exercise: request.exercise, instrument: localData.preferences.instrument.tuning)
                Button { navigation.openPractice(request) } label: {
                    if selection.practiceEntries.count == 1 { Text("lesson.practice") }
                    else { Text("lesson.practiceNumber \(index + 1)") }
                }.accessibilityIdentifier("lesson.practice.\(entry.id)")
            }
        }
        }
    }
    private var lessonSteps: some View {
        let text = lesson.text(for: language)
        return VStack(alignment: .leading, spacing: CoachLayout.padding) {
        ForEach(Array(lesson.manifest.steps.enumerated()), id: \.element.id) { index, step in
            if let sourceCopy = text.steps[step.id] {
                let copy = selection.text(stepID: step.id, language: language)
                VStack(alignment: .leading, spacing: 8) {
                    Button { selection.selectStep(step.id); saveBookmark() } label: {
                        Label {
                            if let copy { Text(verbatim: copy.title).font(.title3.bold()) }
                            else if sourceCopy.title.contains("{{") { Text("lesson.activity.stepNumber \(index + 1)").font(.title3.bold()) }
                            else { Text(verbatim: sourceCopy.title).font(.title3.bold()) }
                        } icon: {
                            Image(systemName: selection.stepID == step.id ? "checkmark.circle.fill" : "circle")
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("lesson.step.\(step.id)")
                        .accessibilityValue(Text(LocalizedStringKey(selection.stepID == step.id ? "fretboard.selected" : "fretboard.unmarked")))
                    if let copy { Text(verbatim: copy.body).textSelection(.enabled) }
                    else { Text("lesson.activity.stepUnavailable").foregroundStyle(.secondary) }
                }.id(step.id)
            }
        }

        }
    }
    private var positionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            if selection.canChoosePosition {
                Picker("lesson.position.label", selection: Binding(get: { selection.choice }, set: {
                    selection.selectChoice($0); saveBookmark()
                })) {
                    ForEach(selection.availableChoices, id: \.self) { choice in
                        PositionChoiceLabel(choice: choice).tag(choice)
                    }
                    if !selection.availableChoices.contains(selection.choice) {
                        PositionChoiceLabel(choice: selection.choice).tag(selection.choice).disabled(true)
                    }
                }.accessibilityIdentifier("lesson.position")
            } else {
                LabeledContent("lesson.activity.fixedPosition") { PositionChoiceLabel(choice: selection.choice) }
            }
            if let width = selection.policy?.windowFrets { Text("lesson.activity.window \(width)").font(.caption) }
            Text("lesson.position.explanation").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var playbackFretboard: FretboardModel? {
        guard preview.requestID != nil, let exercise = preview.exercise else { return nil }
        return FretboardModel(tuning: exercise.requiredTuning ?? localData.preferences.instrument.tuning,
            orientation: localData.preferences.instrument.orientation, frets: localData.preferences.instrument.frets, positions: preview.activeEvent()?.positions ?? [])
    }
    private func saveBookmark() { reading.visit(lessonID: lesson.id, version: lesson.manifest.version, stepID: selection.stepID, activityChoices: selection.activityChoices, activityConfirmations: selection.activityConfirmations) }
}

private struct LessonVariantView: View {
    let variant: LessonActivityText
    let instrument: InstrumentProfile
    let policy: LessonAdaptationPolicy?
    private var openStrings: String {
        instrument.tuning.strings.reversed().map { $0.openPitch.name(spelling: instrument.tuning.preferredSpelling) }.joined(separator: " · ")
    }
    private var openExample: String { instrument.tuning.strings[5].openPitch.name(spelling: instrument.tuning.preferredSpelling) }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: variant.title).font(.headline).accessibilityIdentifier("lesson.variant.title")
                HStack {
                    TuningName(profile: instrument.tuning)
                    Text("result.fretCount \(instrument.fretCount)")
                }
                Text("lesson.variant.openStrings \(openStrings)")
                LabeledContent("tuning.reference") { Text(instrument.tuning.referenceA4, format: .number.precision(.fractionLength(1))) }
                Text(verbatim: variant.body).textSelection(.enabled).accessibilityIdentifier("lesson.variant.body")
                DisclosureGroup("lesson.variant.help") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let policy { Text(LocalizedStringKey(policy == .transposeIntervals ? "lesson.variant.intervals" : "lesson.variant.pattern")) }
                        Text("lesson.variant.notation \(openExample)")
                        Text("lesson.variant.practiceGuide")
                    }.font(.callout).padding(.top, 8)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("lesson.variant.title").accessibilityAddTraits(.isHeader)
        }.accessibilityIdentifier("lesson.variant")
    }
}

struct PositionChoiceLabel: View {
    let choice: PositionChoice
    var body: some View {
        switch choice {
        case .original: Text("lesson.position.original")
        case let .region(firstFret): Text("lesson.position.from \(firstFret)")
        }
    }
}
