import SwiftUI
import Persistence

struct HistoryView: View {
    @Environment(LocalDataStore.self) private var store
    @State private var confirmsClear = false

    var body: some View {
        VStack(spacing: CoachLayout.spacing) {
            StorageNotices().padding(.horizontal, CoachLayout.padding)
            if store.isLoading {
                ProgressView("common.loading").frame(maxHeight: .infinity)
            } else if store.records.isEmpty {
                FeatureStateView(title: "progress.emptyTitle", message: "progress.empty", symbol: "chart.xyaxis.line") { EmptyView() }
            } else {
                List(store.records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: record.exercise.id).font(.headline)
                        Text(record.startedAt, format: .dateTime.year().month().day().hour().minute()).foregroundStyle(.secondary)
                        Text("history.conditions \(record.instrument.tuning.name) \(Int(record.bpm))")
                        if let score = record.result.payload.overallScore {
                            Text("history.score \(Int(score.rounded()))").font(.title3.bold())
                        } else {
                            Text(LocalizedStringKey(validityKey(record.result.payload.validity)))
                            if let pitch = record.result.payload.pitchScore {
                                Text("history.pitchScore \(Int(pitch.rounded()))")
                            }
                        }
                    }.padding(.vertical, 8).accessibilityElement(children: .combine)
                }
            }
            HStack {
                Button("common.refresh") { Task { await store.reload() } }.disabled(store.isBusy)
                Spacer()
                Button("history.clear", role: .destructive) { confirmsClear = true }
                    .disabled(store.isBusy || !store.hasHistory).accessibilityIdentifier("history.clear")
            }.padding(CoachLayout.padding)
        }
        .confirmationDialog("history.clearTitle", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("history.clear", role: .destructive) { Task { await store.clearHistory() } }
            Button("common.cancel", role: .cancel) {}
        } message: { Text("history.clearExplanation") }
    }

    private func validityKey(_ validity: StoredResultValidity) -> String { "history.validity.\(validity.rawValue)" }
}
