import SwiftUI
import Learning
import Domain

@MainActor @Observable
final class LessonLibraryStore {
    @ObservationIgnored private let directory: URL?
    private(set) var report: LessonCatalogReport?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var missingBundle = false
    var lessons: [LoadedLesson] { report?.lessons ?? [] }
    var issues: [ContentIssue] { report?.issues ?? [] }
    /// Legacy fixed C Standard copies stay loadable for history, but do not duplicate the live course.
    static let legacyAliases = ["c-standard-open-strings": "open-strings-intro", "c-standard-first-frets": "first-frets",
        "c-standard-steady-pulse": "steady-pulse", "ab-major-c-standard": "c-major",
        "f-minor-pentatonic-c-standard": "a-minor-pentatonic", "cm-arpeggio-c-standard": "em-arpeggio"]
    var catalogLessons: [LoadedLesson] { lessons.filter { Self.legacyAliases[$0.id] == nil } }
    func sourceLesson(id: String) -> LoadedLesson? {
        let canonical = Self.legacyAliases[id] ?? id
        return lessons.first { $0.id == canonical }
    }


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
