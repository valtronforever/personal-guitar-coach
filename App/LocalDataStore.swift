import SwiftUI
import Domain
import Persistence

@MainActor @Observable
final class LocalDataStore {
    @ObservationIgnored private let repository: LocalRepository?
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
        case let .available(value, _): preferences = value; preferencesIssue = nil
        case let .needsRecovery(issue): preferencesIssue = issue
        }
        hasLoaded = true
        do {
            let loaded = try await repository.history()
            records = loaded.records; historyIssues = loaded.issues
        } catch { operationError = "storage.readFailed" }
    }

    func savePreferences(_ value: InstrumentPreferences) async {
        guard canEditPreferences, let repository else { return }
        isSaving = true; operationError = nil
        defer { isSaving = false }
        do {
            try await repository.savePreferences(value)
            preferences = value // Publish only after the atomic write commits.
        } catch { operationError = "storage.saveFailed" }
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
