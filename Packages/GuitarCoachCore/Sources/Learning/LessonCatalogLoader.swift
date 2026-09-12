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
                try checkSchema(data, allowed: [2])
                let manifest = try JSONDecoder().decode(LessonManifest.self, from: data)
                guard manifest.id == id else { throw ContentFailure(.invalidIdentifier, "Folder and lesson IDs differ: \(id)") }
                try validate(manifest)
                let en = try translation(.en, folder: folder, manifest: manifest)
                let uk = try translation(.uk, folder: folder, manifest: manifest)
                guard exerciseIDs.isDisjoint(with: Set(manifest.exercises.map(\.id))) else {
                    throw ContentFailure(.duplicateIdentifier, "Exercise ID is already used by another lesson")
                }
                exerciseIDs.formUnion(manifest.exercises.map(\.id))
                try validatePresentationParity(en, uk)
                let lesson = LoadedLesson(manifest: manifest, english: en, ukrainian: uk)
                lessons.append(lesson)
            } catch { issues.append(issue(error, lessonID: id)) }
        }
        return LessonCatalogReport(lessons: lessons, issues: issues)
    }

    public func validate(_ manifest: LessonManifest) throws {
        guard manifest.schemaVersion == 2 else { throw ContentFailure(.unsupportedSchema, "Lesson schema \(manifest.schemaVersion)") }
        try validateID(manifest.id)
        guard manifest.version > 0, !manifest.steps.isEmpty, manifest.steps.count <= 512,
              !manifest.exercises.isEmpty, manifest.exercises.count <= 64 else {
            throw ContentFailure(.invalidStep, "A lesson needs bounded steps/exercises and a positive version")
        }
        try uniqueIDs(manifest.steps.map(\.id)); try uniqueIDs(manifest.exercises.map(\.id))
        for exercise in manifest.exercises {
            guard exercise.events.count <= 4096 else { throw ContentFailure(.invalidMusicalData, "Too many source events") }
            try uniqueIDs(exercise.events.map(\.id))
        }
        try validateActivities(manifest)
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
        guard Set(text.activities.keys) == Set(manifest.activities.map(\.id)) else {
            throw ContentFailure(.translationMismatch, "Translation activity IDs differ")
        }
        try ActivityTextRenderer.validate(text)
        for step in manifest.steps where step.activityID == nil {
            if let copy = text.steps[step.id], [copy.title, copy.body].contains(where: { $0.contains("{{") || $0.contains("}}") }) {
                throw ContentFailure(.invalidText, "Context tokens need a step activity: \(step.id)")
            }
        }
        var strings = [text.title, text.summary, text.goal, text.body]
        strings += text.steps.values.flatMap { [$0.title, $0.body] }
        strings += text.activities.values.flatMap { [$0.title, $0.body] }
        strings += text.historicalTitle.map { [$0] } ?? []
        guard strings.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ContentFailure(.invalidText, "Blank text in \(language.rawValue)")
        }
        return text
    }
    private func validatePresentationParity(_ en: LessonText, _ uk: LessonText) throws {
        guard (en.historicalTitle == nil) == (uk.historicalTitle == nil) else {
            throw ContentFailure(.translationMismatch, "Historical titles must exist in both languages")
        }
        do {
            let activities = en.activities
            for (id, copy) in activities {
                guard let other = uk.activities[id],
                      ActivityTextRenderer.tokenNames(copy.title) == ActivityTextRenderer.tokenNames(other.title),
                      ActivityTextRenderer.tokenNames(copy.body) == ActivityTextRenderer.tokenNames(other.body) else {
                    throw ContentFailure(.translationMismatch, "Activity template tokens differ: \(id)")
                }
            }
            for (id, copy) in en.steps {
                guard let other = uk.steps[id],
                      ActivityTextRenderer.tokenNames(copy.title) == ActivityTextRenderer.tokenNames(other.title),
                      ActivityTextRenderer.tokenNames(copy.body) == ActivityTextRenderer.tokenNames(other.body) else {
                    throw ContentFailure(.translationMismatch, "Step template tokens differ: \(id)")
                }
            }
        }
    }
    private func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    private func checkSchema(_ data: Data, allowed: Set<Int> = [1]) throws {
        struct Header: Decodable { let schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard allowed.contains(version) else { throw ContentFailure(.unsupportedSchema, "Unsupported schema: \(version)") }
    }
    func validateID(_ id: String) throws {
        let bytes = Array(id.utf8)
        guard (1...64).contains(bytes.count), let first = bytes.first, (97...122).contains(first),
              bytes.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }) else {
            throw ContentFailure(.invalidIdentifier, "Use a stable lowercase ASCII ID: \(id)")
        }
    }
    func uniqueIDs(_ ids: [String]) throws {
        for id in ids { try validateID(id) }
        guard Set(ids).count == ids.count else { throw ContentFailure(.duplicateIdentifier, "Duplicate identifier") }
    }
    private func issue(_ error: Error, lessonID: String?) -> ContentIssue {
        if error is PositioningError { return ContentIssue(lessonID: lessonID, code: .invalidMusicalData, detail: String(describing: error)) }
        if error is LessonAdaptationError { return ContentIssue(lessonID: lessonID, code: .invalidText, detail: "Invalid adaptive lesson template or fingering") }
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
