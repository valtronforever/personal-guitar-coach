import SwiftUI
import Persistence

@MainActor @Observable
final class ReadingProgressStore {
    @ObservationIgnored private let repository: (any ReadingRepository)?
    private(set) var progress = ReadingProgress()
    private(set) var hasLoaded = false
    private(set) var loadFailed = false
    private(set) var saveFailed = false
    private(set) var isSaving = false
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var pendingRevision = 0
    @ObservationIgnored private var savedRevision = 0
    var canEdit: Bool { hasLoaded && !loadFailed }

    init(repository: (any ReadingRepository)?) { self.repository = repository }

    func load() async {
        guard !isLoading, !hasLoaded || loadFailed else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            guard let repository else { throw StorageError.corruptDocument }
            progress = try await repository.loadReadingProgress()
            loadFailed = false
        } catch { loadFailed = true }
    }

    func visit(lessonID: String, version: Int, stepID: String?) {
        guard canEdit else { return }
        var next = progress
        next.lastLessonID = lessonID
        next.lessons[lessonID] = LessonBookmark(lessonVersion: version, stepID: stepID,
                                              readVersion: progress.lessons[lessonID]?.readVersion)
        update(next)
    }

    func setRead(_ read: Bool, lessonID: String, version: Int, stepID: String?) {
        guard canEdit else { return }
        var next = progress
        next.lessons[lessonID] = LessonBookmark(lessonVersion: version, stepID: stepID, readVersion: read ? version : nil)
        update(next)
    }

    private func update(_ next: ReadingProgress) {
        guard next != progress else { return }
        progress = next; pendingRevision += 1
        Task { await flush() }
    }

    /// A single writer drains the latest snapshot; rapid navigation cannot commit out of order.
    func flush() async {
        guard canEdit, !isSaving, let repository else { return }
        isSaving = true
        defer { isSaving = false }
        while savedRevision < pendingRevision {
            let revision = pendingRevision
            let snapshot = progress
            do {
                try await repository.saveReadingProgress(snapshot)
                savedRevision = revision; saveFailed = false
            } catch { saveFailed = true; return }
        }
    }
}

struct ReadingProgressNotice: View {
    @Environment(ReadingProgressStore.self) private var store
    var body: some View {
        if store.loadFailed || store.saveFailed {
            HStack {
                Label(LocalizedStringKey(store.loadFailed ? "reading.loadFailed" : "reading.saveFailed"), systemImage: "exclamationmark.triangle")
                Button("common.retry") { Task { if store.loadFailed { await store.load() } else { await store.flush() } } }
            }.font(.callout).padding(12)
        }
    }
}
