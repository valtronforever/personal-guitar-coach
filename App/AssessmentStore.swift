import SwiftUI
import Domain
import Learning
import Persistence

@MainActor @Observable
final class AssessmentStore {
    @ObservationIgnored private let repository: (any PracticeRepository)?
    private(set) var latest: AssessedPractice?
    private(set) var pending: PracticeEvidence?
    private(set) var isSaving = false
    private(set) var errorKey: String?
    private(set) var warnings: [StorageIssue] = []
    var needsRetry: Bool { pending != nil && !isSaving }

    init(repository: (any PracticeRepository)? = nil) {
        self.repository = repository ?? (try? LocalRepository.applicationSupport())
    }
    @discardableResult func receive(_ evidence: PracticeEvidence) async -> Bool {
        guard !isSaving, pending == nil || pending == evidence else { return false }
        pending = evidence; latest = nil
        return await retry()
    }
    @discardableResult func retry() async -> Bool {
        guard !isSaving, let evidence = pending else { return pending == nil }
        isSaving = true; errorKey = nil; warnings = []
        defer { isSaving = false }
        do {
            let result = try await Task.detached { try AssessmentEngine.evaluate(evidence) }.value
            latest = result
            guard let repository else { errorKey = "storage.unavailable"; return false }
            do { warnings = try await repository.save(PracticeRecord(assessment: result)) }
            catch { errorKey = "assessment.saveFailed"; return false }
            pending = nil; return true
        } catch { errorKey = "assessment.failed"; return false }
    }
}
