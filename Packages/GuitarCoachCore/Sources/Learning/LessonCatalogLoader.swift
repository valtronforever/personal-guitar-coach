import Foundation
import Domain

/// Read-only and synchronous. UI callers run it on a worker; no audio permission or engine is involved.
public struct LessonCatalogLoader: Sendable {
    public init() {}

    public func load(directory: URL) -> LessonCatalogReport {
        let catalog: LessonCatalogManifest
        do {
            let data = try read(directory.appendingPathComponent("catalog.json"))
            try checkSchema(data)
            catalog = try JSONDecoder().decode(LessonCatalogManifest.self, from: data)
        } catch { return LessonCatalogReport(lessons: [], issues: [issue(error, lessonID: nil)]) }
        var lessons: [LoadedLesson] = [], issues: [ContentIssue] = []
        var lessonIDs = Set<String>(), exerciseIDs = Set<String>()
        for id in catalog.lessons {
            do {
                try validateID(id)
                guard lessonIDs.insert(id).inserted else { throw ContentFailure(.duplicateIdentifier, "Duplicate lesson: \(id)") }
                let folder = directory.appendingPathComponent(id, isDirectory: true)
                guard folder.resolvingSymlinksInPath().deletingLastPathComponent().path == directory.resolvingSymlinksInPath().path else {
                    throw ContentFailure(.invalidIdentifier, "Lesson directory escapes the catalog")
                }
                let data = try read(folder.appendingPathComponent("lesson.json"))
                try checkSchema(data)
                let manifest = try JSONDecoder().decode(LessonManifest.self, from: data)
                guard manifest.id == id else { throw ContentFailure(.invalidIdentifier, "Folder and lesson IDs differ: \(id)") }
                try validate(manifest)
                let en = try translation(.en, folder: folder, manifest: manifest)
                let uk = try translation(.uk, folder: folder, manifest: manifest)
                guard exerciseIDs.isDisjoint(with: Set(manifest.exercises.map(\.id))) else {
                    throw ContentFailure(.duplicateIdentifier, "Exercise ID is already used by another lesson")
                }
                exerciseIDs.formUnion(manifest.exercises.map(\.id))
                lessons.append(LoadedLesson(manifest: manifest, english: en, ukrainian: uk))
            } catch { issues.append(issue(error, lessonID: id)) }
        }
        return LessonCatalogReport(lessons: lessons, issues: issues)
    }

    public func validate(_ manifest: LessonManifest) throws {
        guard manifest.schemaVersion == 1 else { throw ContentFailure(.unsupportedSchema, "Lesson schema \(manifest.schemaVersion)") }
        try validateID(manifest.id)
        guard manifest.version > 0, !manifest.steps.isEmpty, !manifest.exercises.isEmpty else {
            throw ContentFailure(.invalidStep, "A lesson needs a positive version, steps, and exercises")
        }
        try uniqueIDs(manifest.steps.map(\.id))
        try uniqueIDs(manifest.exercises.map(\.id))
        for exercise in manifest.exercises { try uniqueIDs(exercise.events.map(\.id)) }
        let exercises = Dictionary(uniqueKeysWithValues: manifest.exercises.map { ($0.id, $0) })
        try uniqueIDs(manifest.practiceExerciseIDs)
        guard !manifest.practiceExerciseIDs.isEmpty else { throw ContentFailure(.unknownExercise, "A lesson needs a practice exercise") }
        for id in manifest.practiceExerciseIDs {
            guard let exercise = exercises[id] else { throw ContentFailure(.unknownExercise, "Unknown practice exercise: \(id)") }
            guard exercise.assessmentMode == .monophonic else { throw ContentFailure(.unsupportedMode, "Display-only exercise cannot be a practice entry: \(id)") }
        }
        for step in manifest.steps {
            if step.kind == .none {
                guard step.exerciseID == nil, step.eventIDs.isEmpty, step.fingering == nil else {
                    throw ContentFailure(.invalidStep, "Text-only step has visual data: \(step.id)")
                }
                continue
            }
            guard let id = step.exerciseID, let exercise = exercises[id] else {
                throw ContentFailure(.unknownExercise, "Unknown exercise in step: \(step.id)")
            }
            switch step.kind {
            case .events:
                guard step.fingering == nil, !step.eventIDs.isEmpty else { throw ContentFailure(.invalidStep, "Event step needs references and no fingering: \(step.id)") }
                try uniqueIDs(step.eventIDs)
                let known = Set(exercise.events.map(\.id))
                guard Set(step.eventIDs).isSubset(of: known) else { throw ContentFailure(.unknownEvent, "Unknown event in step: \(step.id)") }
                guard exercise.events.filter({ step.eventIDs.contains($0.id) }).map(\.id) == step.eventIDs else {
                    throw ContentFailure(.invalidStep, "Event references must follow exercise order: \(step.id)")
                }
            case .fingering:
                guard step.eventIDs.isEmpty, let fingering = step.fingering,
                      !fingering.positions.isEmpty || !fingering.mutedStrings.isEmpty else {
                    throw ContentFailure(.invalidStep, "Fingering step needs a shape and no event references: \(step.id)")
                }
            case .none: break
            }
        }
    }

    private func translation(_ language: LessonLanguage, folder: URL, manifest: LessonManifest) throws -> LessonText {
        let data: Data
        do { data = try read(folder.appendingPathComponent(language.rawValue + ".json")) }
        catch { throw ContentFailure(.missingTranslation, "Missing/unreadable \(language.rawValue) translation") }
        let text = try JSONDecoder().decode(LessonText.self, from: data)
        guard text.lessonID == manifest.id, text.lessonVersion == manifest.version, text.locale == language.rawValue,
              Set(text.steps.keys) == Set(manifest.steps.map(\.id)) else {
            throw ContentFailure(.translationMismatch, "Translation IDs/version/steps differ: \(language.rawValue)")
        }
        let strings = [text.title, text.summary, text.goal, text.body] + text.steps.values.flatMap { [$0.title, $0.body] }
        guard strings.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ContentFailure(.invalidText, "Blank text in \(language.rawValue)")
        }
        return text
    }
    private func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    private func checkSchema(_ data: Data) throws {
        struct Header: Decodable { let schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard version == 1 else { throw ContentFailure(.unsupportedSchema, "Unsupported schema: \(version)") }
    }
    private func validateID(_ id: String) throws {
        let bytes = Array(id.utf8)
        guard (1...64).contains(bytes.count), let first = bytes.first, (97...122).contains(first),
              bytes.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }) else {
            throw ContentFailure(.invalidIdentifier, "Use a stable lowercase ASCII ID: \(id)")
        }
    }
    private func uniqueIDs(_ ids: [String]) throws {
        for id in ids { try validateID(id) }
        guard Set(ids).count == ids.count else { throw ContentFailure(.duplicateIdentifier, "Duplicate identifier") }
    }
    private func issue(_ error: Error, lessonID: String?) -> ContentIssue {
        if let failure = error as? ContentFailure { return ContentIssue(lessonID: lessonID, code: failure.code, detail: failure.detail) }
        if let error = error as? MusicError {
            return ContentIssue(lessonID: lessonID, code: error == .duplicateIdentifier ? .duplicateIdentifier : .invalidMusicalData, detail: String(describing: error))
        }
        if case let DecodingError.dataCorrupted(context) = error,
           context.codingPath.contains(where: { ["assessmentMode", "tuningPolicy", "kind"].contains($0.stringValue) }) {
            return ContentIssue(lessonID: lessonID, code: .unsupportedMode, detail: context.debugDescription)
        }
        let code: ContentIssueCode = error is DecodingError ? .invalidJSON : (lessonID == nil ? .unavailableCatalog : .missingFile)
        return ContentIssue(lessonID: lessonID, code: code, detail: String(describing: error))
    }
}
