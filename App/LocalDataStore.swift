import SwiftUI
import Domain
import Persistence

@MainActor @Observable
final class LocalDataStore {
    @ObservationIgnored private let repository: LocalRepository?
    /// The practice coordinator installs its synchronous interrupt handler before a new snapshot becomes visible.
    @ObservationIgnored var instrumentWillChange: ((InstrumentProfile) -> Void)?
    @ObservationIgnored private var historyRevision = 0
    private(set) var preferences = InstrumentPreferences.defaults
    private(set) var records: [PracticeRecord] = []
    private(set) var preferencesIssue: StorageIssue?
    private(set) var historyIssues: [StorageIssue] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var hasLoaded = false
    private(set) var operationError: String?
    var isBusy: Bool { isLoading || isSaving }
    var canEditPreferences: Bool { repository != nil && hasLoaded && !isBusy && preferencesIssue == nil }
    var hasHistory: Bool { !records.isEmpty || historyIssues.contains { $0.reason != .indexUnavailable } }

    init(repository: LocalRepository? = nil) {
        do { self.repository = try repository ?? LocalRepository.applicationSupport() }
        catch { self.repository = nil; operationError = "storage.unavailable" }
    }

    func reload() async {
        guard !isBusy, let repository else { return }
        isLoading = true
        defer { isLoading = false }
        operationError = nil
        switch await repository.loadPreferences() {
        case let .available(value, _): publishPreferences(value); preferencesIssue = nil
        case let .needsRecovery(issue): preferencesIssue = issue
        }
        hasLoaded = true
        await refreshHistory()
    }

    func refreshHistory() async {
        guard let repository else { return }
        historyRevision += 1; let revision = historyRevision
        do {
            let loaded = try await repository.history()
            guard revision == historyRevision else { return }
            records = loaded.records; historyIssues = loaded.issues
        } catch { if revision == historyRevision { operationError = "storage.readFailed" } }
    }

    func savePreferences(_ value: InstrumentPreferences) async {
        guard canEditPreferences, let repository else { return }
        isSaving = true; operationError = nil
        defer { isSaving = false }
        do {
            try await repository.savePreferences(value)
            publishPreferences(value) // Publish only after the atomic write commits.
        } catch { operationError = "storage.saveFailed" }
    }

    private func publishPreferences(_ value: InstrumentPreferences) {
        if preferences.instrument != value.instrument { instrumentWillChange?(value.instrument) }
        preferences = value
    }

    func selectTuning(id: String) async {
        do { try await savePreferences(preferences.selectingTuning(id: id)) }
        catch { operationError = "tuning.error.profile" }
    }

    func changeOrientation(_ orientation: FretboardOrientation) async {
        do {
            let instrument = InstrumentProfile(tuning: preferences.instrument.tuning, orientation: orientation, source: preferences.instrument.source)
            try await savePreferences(InstrumentPreferences(instrument: instrument, customTunings: preferences.customTunings,
                                                           practiceBPM: preferences.practiceBPM))
        } catch { operationError = "storage.saveFailed" }
    }

    func saveTuning(_ tuning: TuningProfile, expectedRevision: Int?) async -> Bool {
        guard canEditPreferences else { return false }
        do {
            let value = try preferences.savingCustomTuning(tuning, expectedRevision: expectedRevision)
            await savePreferences(value)
            return operationError == nil && preferences.instrument.tuning == tuning
        } catch { operationError = "tuning.error.conflict"; return false }
    }

    func changeSource(_ source: InputSource) async {
        do {
            let instrument = InstrumentProfile(tuning: preferences.instrument.tuning, orientation: preferences.instrument.orientation, source: source)
            try await savePreferences(InstrumentPreferences(instrument: instrument, customTunings: preferences.customTunings,
                                                           practiceBPM: preferences.practiceBPM))
        } catch { operationError = "storage.saveFailed" }
    }

    func recoverPreferences() async {
        guard !isBusy, let repository else { return }
        isSaving = true
        do {
            try await repository.restoreDefaultPreferencesPreservingCopy()
            isSaving = false
            await reload()
        } catch { isSaving = false; operationError = "storage.recoveryFailed" }
    }

    func clearHistory() async {
        guard !isBusy, let repository else { return }
        isSaving = true
        var failed = false
        do { try await repository.clearHistory() } catch { failed = true }
        isSaving = false
        await reload()
        if failed { operationError = "storage.clearFailed" }
    }
}

extension InputSource {
    var titleKey: String {
        switch self {
        case .electricInterface: "source.electric"
        case .acousticMicrophone: "source.microphone"
        case .acousticPickup: "source.pickup"
        }
    }
}

struct StorageNotices: View {
    @Environment(LocalDataStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = store.operationError {
                Label(LocalizedStringKey(error), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).accessibilityIdentifier("storage.error")
            }
            if store.preferencesIssue != nil {
                Label("storage.preferencesProblem", systemImage: "exclamationmark.triangle")
                Button("storage.restoreDefaults") { Task { await store.recoverPreferences() } }.disabled(store.isBusy)
                Text("storage.restoreExplanation").font(.caption).foregroundStyle(.secondary)
            }
            if !store.historyIssues.isEmpty {
                Label("storage.historyProblem", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("storage.historyWarning")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
