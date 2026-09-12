import SwiftUI
import Domain
import Learning
import Persistence

struct HistoryView: View {
    @Environment(LocalDataStore.self) private var store
    @Environment(LessonLibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @State private var confirmsClear = false
    @State private var showsAudio = false
    @State private var path: [UUID] = []
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: CoachLayout.spacing) {
                StorageNotices().padding(.horizontal, CoachLayout.padding)
                if store.isLoading {
                    ProgressView("common.loading").frame(maxHeight: .infinity)
                } else if store.records.isEmpty {
                    FeatureStateView(title: "progress.emptyTitle", message: "progress.empty", symbol: "chart.xyaxis.line") { EmptyView() }
                } else {
                    List(store.records) { record in
                        NavigationLink(value: record.id) { row(record) }.accessibilityIdentifier("history.record." + record.id.uuidString)
                    }
                }
                HStack {
                    Button("common.refresh") { Task { await store.reload() } }.disabled(store.isBusy)
                    Spacer()
                    Button("history.clear", role: .destructive) { confirmsClear = true }
                        .disabled(store.isBusy || !store.hasHistory).accessibilityIdentifier("history.clear")
                }.padding(CoachLayout.padding)
            }
            .navigationDestination(for: UUID.self) { id in
                if let record = store.records.first(where: { $0.id == id }) {
                    if let result = record.assessment?.payload {
                        ResultDetailView(result: result, history: store.records.compactMap { $0.assessment?.payload },
                            onRetry: { navigation.openPractice($0) }, onAudioSetup: { showsAudio = true },
                            onTuner: { target in
                                guard store.canEditPreferences else { return false }
                                await store.restoreArchivedTuning(target)
                                guard store.operationError == nil, store.preferences.instrument.tuning.hasSamePitches(as: target) else { return false }
                                navigation.destination = .tuner; return true
                            })
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                row(record)
                                Text("result.legacyExplanation")
                                Text("result.exerciseVersion \(record.exercise.id) \(record.exercise.version)")
                                Text("result.scoringVersion \(record.result.payload.algorithmVersion)")
                                Text("assessment.expected \(record.result.payload.expectedCount)")
                                Text("assessment.matched \(record.result.payload.matchedCount)")
                                Text("assessment.missed \(record.result.payload.missedCount)")
                                Text("assessment.extra \(record.result.payload.extraCount)")
                            }.padding(CoachLayout.padding)
                        }
                    }
                }
            }
        }
        .onChange(of: store.records.map(\.id)) { _, ids in if path.contains(where: { !ids.contains($0) }) { path = [] } }
        .sheet(isPresented: $showsAudio) { AudioProbeView().environment(\.locale, settings.locale) }
        .confirmationDialog("history.clearTitle", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("history.clear", role: .destructive) { Task { await store.clearHistory() } }
            Button("common.cancel", role: .cancel) {}
        } message: { Text("history.clearExplanation") }
    }
    private func row(_ record: PracticeRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = ResultPresentation.title(record: record, lessons: library.lessons, language: language) {
                Text(verbatim: title).font(.headline)
            } else { Text("result.savedExercise").font(.headline) }
            Text(record.startedAt, format: .dateTime.year().month().day().hour().minute()).foregroundStyle(.secondary)
            HStack { TuningName(profile: record.instrument.tuning); Text("practice.selectedTempo \(Int(record.bpm))"); Text("result.fretCount \(record.instrument.fretCount)") }
            if let score = record.result.payload.overallScore {
                Text("history.score \(Int(score.rounded()))").font(.title3.bold())
            } else {
                Text(LocalizedStringKey("history.validity." + record.result.payload.validity.rawValue))
                if let pitch = record.result.payload.pitchScore { Text("history.pitchScore \(Int(pitch.rounded()))") }
            }
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}
