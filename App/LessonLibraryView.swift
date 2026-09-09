import SwiftUI
import Learning
import Domain

struct LessonLibraryView: View {
    @Environment(LessonLibraryStore.self) private var store
    @Environment(AppSettings.self) private var settings
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CoachLayout.spacing) {
                if !store.hasLoaded || store.isLoading {
                    ProgressView("lessons.loading").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if store.missingBundle { Label("content.error.unavailableCatalog", systemImage: "exclamationmark.triangle").padding() }
                    if !store.issues.isEmpty {
                        DisclosureGroup {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(store.issues) { issue in
                                        VStack(alignment: .leading) {
                                            Label(LocalizedStringKey(issueKey(issue.code)), systemImage: "exclamationmark.triangle")
                                            if let id = issue.lessonID { Text(verbatim: id).font(.caption).foregroundStyle(.secondary) }
                                        }
                                    }
                                }
                            }.frame(maxHeight: 140)
                        } label: { Text("content.issues \(store.issues.count)") }
                        .padding(.horizontal, CoachLayout.padding)
                    }
                    if store.lessons.isEmpty {
                        FeatureStateView(title: "navigation.lessons", message: store.issues.isEmpty && !store.missingBundle ? "lessons.empty" : "content.noReadableLessons", symbol: "book") { EmptyView() }
                    } else {
                        Text("lessons.count \(store.lessons.count)").font(.headline).padding(.horizontal, CoachLayout.padding)
                        List(store.lessons) { lesson in
                            NavigationLink(value: lesson.id) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(verbatim: lesson.text(for: language).title).font(.headline)
                                    Text(verbatim: lesson.text(for: language).summary).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.padding(.vertical, 8)
                            }.accessibilityIdentifier("lesson.\(lesson.id)")
                        }
                    }
                    Button("common.refresh") { Task { await store.load(force: true) } }.padding(.horizontal, CoachLayout.padding)
                }
            }
            .padding(.vertical, CoachLayout.spacing)
            .navigationDestination(for: String.self) { id in
                if let lesson = store.lessons.first(where: { $0.id == id }) { LessonTextView(lesson: lesson) }
                else { FeatureStateView(title: "common.error", message: "content.error.missingFile", symbol: "book") { EmptyView() } }
            }
        }
        .task { await store.load() }
    }

    private func issueKey(_ code: ContentIssueCode) -> String { "content.error.\(code.rawValue)" }
}

/// Step-to-fretboard selection; shared timeline selection and restoration follow in task 10.
struct LessonTextView: View {
    let lesson: LoadedLesson
    @State private var selectedStepID: String?
    @State private var selectedPosition: FretPosition?
    @Environment(AppSettings.self) private var settings
    @Environment(LocalDataStore.self) private var localData
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }

    var body: some View {
        let text = lesson.text(for: language)
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: CoachLayout.padding) {
                Text(verbatim: text.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("lesson.title")
                VStack(alignment: .leading, spacing: 8) {
                    Text("content.goal").font(.headline)
                    Text(verbatim: text.goal)
                }
                Text(verbatim: text.body).textSelection(.enabled)
                if let exercise = lesson.manifest.exercises.first(where: { lesson.manifest.practiceExerciseIDs.contains($0.id) }) {
                    TuningRequirementView(exercise: exercise, instrument: localData.preferences.instrument.tuning)
                }
                ForEach(lesson.manifest.steps) { step in
                    if let copy = text.steps[step.id] {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                selectedStepID = step.id
                                selectedPosition = nil
                            } label: {
                                Label { Text(verbatim: copy.title).font(.title3.bold()) } icon: {
                                    Image(systemName: selectedStepID == step.id ? "checkmark.circle.fill" : "circle")
                                }
                            }.buttonStyle(.plain).accessibilityIdentifier("lesson.step.\(step.id)")
                                .accessibilityValue(Text(LocalizedStringKey(selectedStepID == step.id ? "fretboard.selected" : "fretboard.unmarked")))
                            Text(verbatim: copy.body).textSelection(.enabled)
                        }
                    }
                }
            }
            .frame(maxWidth: 740, alignment: .leading)
            .padding(CoachLayout.padding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(minHeight: 140)
        Divider()
        if let visual = try? lesson.visual(stepID: selectedStepID ?? lesson.manifest.steps[0].id, instrument: localData.preferences.instrument.tuning) {
            FretboardView(model: FretboardModel(tuning: visual.tuning, orientation: localData.preferences.instrument.orientation,
                positions: visual.positions.map(\.position), mutedStrings: visual.mutedStrings,
                fingers: Dictionary(uniqueKeysWithValues: visual.positions.compactMap { item in item.finger.map { (item.position.string, $0) } })), selected: $selectedPosition)
                .padding(16)
        }
        }
        .onAppear { if selectedStepID == nil { selectedStepID = lesson.manifest.steps.first?.id } }
        .navigationTitle(text.title)
    }
}
