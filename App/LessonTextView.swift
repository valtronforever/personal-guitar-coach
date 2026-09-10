import SwiftUI
import Learning
import Domain
import Persistence
import Audio

struct LessonTextView: View {
    let lesson: LoadedLesson
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

    init(lesson: LoadedLesson, bookmark: LessonBookmark?) {
        self.lesson = lesson
        restoresBookmark = bookmark?.lessonVersion == lesson.manifest.version && bookmark?.stepID != nil
        _selection = State(initialValue: LessonSelection(lesson: lesson, bookmark: bookmark))
    }

    var body: some View {
        @Bindable var selection = selection
        let text = lesson.text(for: language)
        VStack(spacing: 0) {
            ReadingProgressNotice()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: CoachLayout.padding) {
                        Text(verbatim: text.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader).accessibilityIdentifier("lesson.title")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("content.goal").font(.headline)
                            Text(verbatim: text.goal)
                        }
                        Text(verbatim: text.body).textSelection(.enabled)
                        ForEach(lesson.manifest.steps) { step in
                            if let copy = text.steps[step.id] {
                                VStack(alignment: .leading, spacing: 8) {
                                    Button { selection.selectStep(step.id); saveBookmark() } label: {
                                        Label { Text(verbatim: copy.title).font(.title3.bold()) } icon: {
                                            Image(systemName: selection.stepID == step.id ? "checkmark.circle.fill" : "circle")
                                        }
                                    }.buttonStyle(.plain).accessibilityIdentifier("lesson.step.\(step.id)")
                                        .accessibilityValue(Text(LocalizedStringKey(selection.stepID == step.id ? "fretboard.selected" : "fretboard.unmarked")))
                                    Text(verbatim: copy.body).textSelection(.enabled)
                                }.id(step.id)
                            }
                        }
                        Divider()
                        Toggle("reading.markRead", isOn: Binding(get: {
                            reading.progress.lessons[lesson.id]?.readVersion == lesson.manifest.version
                        }, set: { reading.setRead($0, lessonID: lesson.id, version: lesson.manifest.version, stepID: selection.stepID) }))
                            .disabled(!reading.canEdit).accessibilityIdentifier("lesson.markRead")
                        Text("reading.explanation").font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(lesson.manifest.practiceExerciseIDs.enumerated()), id: \.element) { index, id in
                            if let request = PracticeRequest(lesson: lesson, exerciseID: id) {
                                TuningRequirementView(exercise: request.exercise, instrument: localData.preferences.instrument.tuning)
                                Button { navigation.openPractice(request) } label: {
                                    if lesson.manifest.practiceExerciseIDs.count == 1 { Text("lesson.practice") }
                                    else { Text("lesson.practiceNumber \(index + 1)") }
                                }.accessibilityIdentifier("lesson.practice.\(id)")
                            }
                        }
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
        .onAppear { saveBookmark() }
        .task(id: selection.exercise) { await preview.configure(selection.exercise, audio: audio) }
        .onChange(of: audio.state) { _, state in preview.update(state) }
        .onChange(of: localData.preferences.instrument) { _, _ in Task { await preview.stop(audio: audio) } }
        .onDisappear { Task { await preview.stop(audio: audio) } }
        .navigationTitle(text.title)
    }
    private var playbackFretboard: FretboardModel? {
        guard preview.requestID != nil, let exercise = preview.exercise else { return nil }
        return FretboardModel(tuning: exercise.requiredTuning ?? localData.preferences.instrument.tuning,
            orientation: localData.preferences.instrument.orientation, positions: preview.activeEvent()?.positions ?? [])
    }
    private func saveBookmark() { reading.visit(lessonID: lesson.id, version: lesson.manifest.version, stepID: selection.stepID) }
}
