import SwiftUI
import Learning

@MainActor @Observable
final class LessonLibraryStore {
    @ObservationIgnored private let directory: URL?
    private(set) var report: LessonCatalogReport?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var missingBundle = false
    var lessons: [LoadedLesson] { report?.lessons ?? [] }
    var issues: [ContentIssue] { report?.issues ?? [] }

    init(directory: URL? = Bundle.main.url(forResource: "Lessons", withExtension: nil)) { self.directory = directory }

    func load(force: Bool = false) async {
        guard !isLoading, !hasLoaded || force else { return }
        isLoading = true
        defer { isLoading = false }
        guard let directory else { missingBundle = true; hasLoaded = true; return }
        let report = await Task.detached(priority: .userInitiated) { LessonCatalogLoader().load(directory: directory) }.value
        guard !Task.isCancelled else { return }
        self.report = report; hasLoaded = true; missingBundle = false
    }
}
