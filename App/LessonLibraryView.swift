import SwiftUI
import Learning
import Domain

struct LessonLibraryView: View {
    @Environment(LessonLibraryStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @Environment(ReadingProgressStore.self) private var reading
    @State private var filter = LessonFilter()
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }
    private var filtered: [LoadedLesson] { store.lessons.filter { filter.matches($0, language: language) } }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.lessonPath) {
            VStack(alignment: .leading, spacing: CoachLayout.spacing) {
                if !store.hasLoaded || store.isLoading || !reading.hasLoaded {
                    ProgressView("lessons.loading").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ReadingProgressNotice()
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
                        filters
                        if filtered.isEmpty {
                            FeatureStateView(title: "lessons.noMatches", message: "lessons.changeFilters", symbol: "magnifyingglass") {
                                Button("lessons.clearFilters") { filter = LessonFilter() }
                            }
                        } else {
                            List(filtered) { lesson in
                                NavigationLink(value: lesson.id) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(verbatim: lesson.text(for: language).title).font(.headline)
                                        Text(verbatim: lesson.text(for: language).summary).foregroundStyle(.secondary).lineLimit(3)
                                        HStack {
                                            Text(LocalizedStringKey(difficultyKey(lesson.manifest.difficulty)))
                                            Text(LocalizedStringKey(topicKey(lesson.manifest.topic)))
                                            if let readVersion = reading.progress.lessons[lesson.id]?.readVersion {
                                                Label(LocalizedStringKey(readVersion == lesson.manifest.version ? "reading.read" : "reading.updated"), systemImage: "book.closed.fill")
                                            }
                                        }.font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 8)
                                }.accessibilityIdentifier("lesson.\(lesson.id)")
                            }
                        }
                    }
                    Button("common.refresh") { Task { await store.load(force: true) } }.padding(.horizontal, CoachLayout.padding)
                }
            }
            .padding(.vertical, CoachLayout.spacing)
            .navigationDestination(for: String.self) { id in
                if let lesson = store.lessons.first(where: { $0.id == id }) {
                    LessonTextView(lesson: lesson, bookmark: reading.progress.lessons[id]).id("\(lesson.id):\(lesson.manifest.version)")
                } else { FeatureStateView(title: "common.error", message: "content.error.missingFile", symbol: "book") { EmptyView() } }
            }
        }
        .task {
            await store.load()
            await reading.load()
            if !navigation.restoredReading && store.hasLoaded && reading.hasLoaded {
                navigation.restoredReading = true
                if navigation.lessonPath.isEmpty, let id = reading.progress.lastLessonID, store.lessons.contains(where: { $0.id == id }) {
                    navigation.lessonPath = [id]
                }
            }
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("lessons.search", text: $filter.query).textFieldStyle(.roundedBorder).accessibilityIdentifier("lessons.search")
            HStack {
                Picker("lessons.difficulty", selection: $filter.difficulty) {
                    Text("lessons.allDifficulties").tag(nil as LessonDifficulty?)
                    ForEach(LessonDifficulty.allCases, id: \.self) { value in Text(LocalizedStringKey(difficultyKey(value))).tag(Optional(value)) }
                }
                Picker("lessons.topic", selection: $filter.topic) {
                    Text("lessons.allTopics").tag(nil as LessonTopic?)
                    ForEach(LessonTopic.allCases, id: \.self) { value in Text(LocalizedStringKey(topicKey(value))).tag(Optional(value)) }
                }
            }
            Text("lessons.count \(filtered.count)").font(.headline)
        }.padding(.horizontal, CoachLayout.padding)
    }
    private func issueKey(_ code: ContentIssueCode) -> String { "content.error.\(code.rawValue)" }
    private func difficultyKey(_ value: LessonDifficulty) -> String { "difficulty.\(value.rawValue)" }
    private func topicKey(_ value: LessonTopic) -> String { "topic.\(value.rawValue)" }
}
