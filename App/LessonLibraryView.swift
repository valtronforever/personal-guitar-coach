import SwiftUI
import Learning
import Domain

struct LessonLibraryView: View {
    @Environment(LessonLibraryStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @Environment(ReadingProgressStore.self) private var reading
    @Environment(LocalDataStore.self) private var data
    @State private var filter = LessonFilter()
    @State private var showsFilters = false
    @FocusState private var searchFocused: Bool
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }
    private var filtered: [LoadedLesson] { filter.results(store.catalogLessons, language: language, progress: reading.progress, modules: store.modules) }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.lessonPath) {
            VStack(alignment: .leading, spacing: 0) {
                if !store.hasLoaded || store.isLoading || !reading.hasLoaded {
                    ProgressView("lessons.loading").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ReadingProgressNotice()
                    catalogIssues
                    if store.lessons.isEmpty {
                        FeatureStateView(title: "navigation.lessons", message: store.issues.isEmpty && !store.missingBundle ? "lessons.empty" : "content.noReadableLessons", symbol: "book") { EmptyView() }
                    } else {
                        libraryHeader
                        searchAndFilters
                        if filtered.isEmpty {
                            FeatureStateView(title: "lessons.noMatches", message: "lessons.changeFilters", symbol: "magnifyingglass") {
                                Button("lessons.clearFilters") { clearFilters() }
                            }
                        } else {
                            courseList
                        }
                    }
                }
            }
            .navigationTitle("navigation.lessons")
            .toolbar {
                ToolbarItemGroup {
                    Button("library.focusSearch", systemImage: "magnifyingglass") { searchFocused = true }
                        .keyboardShortcut("f", modifiers: [.command, .option])
                    Button("common.refresh", systemImage: "arrow.clockwise") { Task { await store.load(force: true) } }
                        .disabled(store.isLoading).help(Text("common.refresh"))
                }
            }
            .navigationDestination(for: String.self) { id in
                if let lesson = store.sourceLesson(id: id) {
                    LessonTextView(lesson: lesson, bookmark: reading.progress.lessons[lesson.id], tuning: data.preferences.instrument.tuning, frets: data.preferences.instrument.frets)
                        .id("\(lesson.id):\(lesson.manifest.version)")
                } else { FeatureStateView(title: "common.error", message: "content.error.missingFile", symbol: "book") { EmptyView() } }
            }
        }
        .task {
            await store.load(); await reading.load()
            // Return to the course overview; the explicit Continue action restores the saved step.
            navigation.restoredReading = true
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("library.courseTitle").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text("library.courseSubtitle").font(.callout).foregroundStyle(.secondary)
            if !filter.isActive, let lesson = store.continuation(reading.progress) {
                Button { navigation.lessonPath = [lesson.id] } label: {
                    HStack {
                        Image(systemName: "book.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("library.continue").font(.caption)
                            Text(verbatim: lesson.text(for: language).title).font(.headline).lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }.padding(10)
                }.buttonStyle(.bordered).accessibilityIdentifier("library.continue")
            }
        }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
    }

    private var searchAndFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("lessons.search", text: $filter.query).textFieldStyle(.roundedBorder)
                    .focused($searchFocused).accessibilityIdentifier("lessons.search")
                if !filter.query.isEmpty {
                    Button("library.clearSearch", systemImage: "xmark.circle.fill") { filter.query = "" }
                        .labelStyle(.iconOnly).help(Text("library.clearSearch"))
                }
                Button { showsFilters.toggle() } label: {
                    if filter.selectionCount == 0 { Label("library.filters", systemImage: "line.3.horizontal.decrease") }
                    else { Label("library.filtersCount \(filter.selectionCount)", systemImage: "line.3.horizontal.decrease") }
                }.accessibilityIdentifier("library.filters")
                    .popover(isPresented: $showsFilters) { filterPanel.environment(\.locale, settings.locale) }
            }
            if filter.selectionCount > 0 {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        if let id = filter.moduleID, let module = store.modules.first(where: { $0.id == id }) {
                            filterChip(module.title(language)) { filter.moduleID = nil }
                        }
                        if let value = filter.difficulty { filterChip { Text(LocalizedStringKey("difficulty." + value.rawValue)) } clear: { filter.difficulty = nil } }
                        if let value = filter.topic { filterChip { Text(LocalizedStringKey("topic." + value.rawValue)) } clear: { filter.topic = nil } }
                        if let value = filter.mode { filterChip { Text(LocalizedStringKey("library.mode." + value.rawValue)) } clear: { filter.mode = nil } }
                        if let value = filter.readingStatus { filterChip { Text(LocalizedStringKey("library.reading." + value.rawValue)) } clear: { filter.readingStatus = nil } }
                    }
                }.scrollIndicators(.hidden)
            }
            HStack {
                Text("library.matchCount \(filtered.count) \(store.catalogLessons.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if filter.isActive { Button("lessons.clearFilters") { clearFilters() }.font(.caption) }
            }
        }.padding(.horizontal, 24).padding(.bottom, 12)
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("library.filters").font(.headline)
            Form {
                Picker("library.module", selection: $filter.moduleID) {
                    Text("library.allModules").tag(nil as String?)
                    ForEach(store.modules.filter { module in store.catalogLessons.contains { $0.manifest.curriculum?.moduleID == module.id } }) { module in
                        Text(verbatim: module.title(language)).tag(Optional(module.id))
                    }
                }.accessibilityIdentifier("library.module")
                Picker("lessons.difficulty", selection: $filter.difficulty) {
                    Text("lessons.allDifficulties").tag(nil as LessonDifficulty?)
                    ForEach(LessonDifficulty.allCases, id: \.self) { value in Text(LocalizedStringKey("difficulty." + value.rawValue)).tag(Optional(value)) }
                }
                Picker("lessons.topic", selection: $filter.topic) {
                    Text("lessons.allTopics").tag(nil as LessonTopic?)
                    ForEach(LessonTopic.allCases, id: \.self) { value in Text(LocalizedStringKey("topic." + value.rawValue)).tag(Optional(value)) }
                }
                Picker("library.mode", selection: $filter.mode) {
                    Text("library.allModes").tag(nil as LessonLearningMode?)
                    ForEach(LessonLearningMode.allCases, id: \.self) { value in Text(LocalizedStringKey("library.mode." + value.rawValue)).tag(Optional(value)) }
                }
                Picker("library.reading", selection: $filter.readingStatus) {
                    Text("library.anyReading").tag(nil as LessonReadingStatus?)
                    ForEach(LessonReadingStatus.allCases, id: \.self) { value in Text(LocalizedStringKey("library.reading." + value.rawValue)).tag(Optional(value)) }
                }
                Divider()
                Picker("library.sort", selection: $filter.sort) {
                    ForEach(LessonSort.allCases, id: \.self) { value in Text(LocalizedStringKey("library.sort." + value.rawValue)).tag(value) }
                }
            }
            Text("library.readingHelp").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("lessons.clearFilters") { clearFilters() }.disabled(!filter.isActive)
                Spacer()
                Button("library.done") { showsFilters = false }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 380)
    }

    private var courseList: some View {
        List {
            ForEach(store.groups(for: filtered, sort: filter.sort)) { group in
                Section {
                    ForEach(group.lessons) { lesson in
                        NavigationLink(value: lesson.id) {
                            LessonLibraryRow(lesson: lesson, language: language,
                                readingStatus: .status(lesson, bookmark: reading.progress.lessons[lesson.id]))
                        }.accessibilityIdentifier("lesson.\(lesson.id)")
                    }
                } header: {
                    if let module = group.module {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(verbatim: "\(module.order). " + module.title(language)).font(.headline)
                                Spacer()
                                let members = store.catalogLessons.filter { $0.manifest.curriculum?.moduleID == module.id }
                                let count = members.filter { reading.progress.lessons[$0.id]?.readVersion == $0.manifest.version }.count
                                Text("library.moduleRead \(count) \(members.count)").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(verbatim: module.summary(language)).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8).accessibilityAddTraits(.isHeader)
                    } else if group.id == "_additional" && !store.modules.isEmpty { Text("library.additional") }
                }
            }
        }.listStyle(.inset).accessibilityIdentifier("library.list")
    }

    private var catalogIssues: some View {
        VStack(alignment: .leading) {
            if store.missingBundle { Label("content.error.unavailableCatalog", systemImage: "exclamationmark.triangle") }
            if !store.issues.isEmpty {
                DisclosureGroup {
                    ScrollView {
                        ForEach(store.issues) { issue in
                            VStack(alignment: .leading) {
                                Label(LocalizedStringKey("content.error." + issue.code.rawValue), systemImage: "exclamationmark.triangle")
                                if let id = issue.lessonID { Text(verbatim: id).font(.caption) }
                            }
                        }
                    }.frame(maxHeight: 140)
                } label: { Text("content.issues \(store.issues.count)") }
            }
        }.padding(.horizontal, 24)
    }
    private func clearFilters() { filter = LessonFilter(sort: filter.sort) }
    private func filterChip(_ title: String, clear: @escaping () -> Void) -> some View {
        filterChip { Text(verbatim: title) } clear: { clear() }
    }
    private func filterChip<Label: View>(@ViewBuilder label: () -> Label, clear: @escaping () -> Void) -> some View {
        Button(action: clear) { HStack(spacing: 6) { label(); Image(systemName: "xmark") } }
            .font(.caption).buttonStyle(.bordered).help(Text("library.removeFilter"))
    }
}

struct LessonLibraryRow: View {
    let lesson: LoadedLesson
    let language: LessonLanguage
    let readingStatus: LessonReadingStatus
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let ordinal = lesson.manifest.curriculum?.ordinal {
                Text(ordinal, format: .number).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(minWidth: 26, alignment: .trailing).padding(.top, 2).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: lesson.text(for: language).title).font(.headline)
                Text(verbatim: lesson.text(for: language).summary).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { metadata }
                    VStack(alignment: .leading, spacing: 4) { metadata }
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
        }
    }
    @ViewBuilder private var metadata: some View {
        Text(LocalizedStringKey("difficulty." + lesson.manifest.difficulty.rawValue))
        if let minutes = lesson.manifest.curriculum?.durationMinutes { Label("library.minutes \(minutes)", systemImage: "clock") }
        if !lesson.manifest.practiceEntries.isEmpty { Label("lesson.mode.scored", systemImage: "waveform") }
        else if LessonLearningMode.listening.includes(lesson) { Label("library.mode.listening", systemImage: "ear") }
        else if LessonLearningMode.selfPractice.includes(lesson) { Label("library.mode.selfPractice", systemImage: "checklist") }
        else { Label("library.mode.theory", systemImage: "book") }
        if readingStatus != .notStarted {
            Label(LocalizedStringKey("library.reading." + readingStatus.rawValue), systemImage: readingStatus == .read ? "book.closed.fill" : "bookmark")
        }
    }
}
