import Foundation

public struct LessonModule: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let titles: [String: String]
    public let summaries: [String: String]
    public init(id: String, order: Int, titles: [String: String], summaries: [String: String]) {
        self.id = id; self.order = order; self.titles = titles; self.summaries = summaries
    }
    public func title(_ language: LessonLanguage) -> String { titles[language.rawValue] ?? id }
    public func summary(_ language: LessonLanguage) -> String { summaries[language.rawValue] ?? "" }
}

/// Editorial placement does not change musical content or historic performance versions.
public struct LessonCurriculumPlacement: Codable, Equatable, Sendable {
    public let moduleID: String
    public let ordinal: Int
    public let durationMinutes: Int
    public let prerequisites: [String]
    public let keywords: [String]
    public init(moduleID: String, ordinal: Int, durationMinutes: Int, prerequisites: [String] = [], keywords: [String] = []) {
        self.moduleID = moduleID; self.ordinal = ordinal; self.durationMinutes = durationMinutes
        self.prerequisites = prerequisites; self.keywords = keywords
    }
    private enum CodingKeys: String, CodingKey { case moduleID, ordinal, durationMinutes, prerequisites, keywords }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(moduleID: try values.decode(String.self, forKey: .moduleID),
                  ordinal: try values.decode(Int.self, forKey: .ordinal),
                  durationMinutes: try values.decode(Int.self, forKey: .durationMinutes),
                  prerequisites: try values.decodeIfPresent([String].self, forKey: .prerequisites) ?? [],
                  keywords: try values.decodeIfPresent([String].self, forKey: .keywords) ?? [])
    }
}

extension LessonCatalogLoader {
    func validateModules(_ modules: [LessonModule]) throws {
        guard modules.count <= 64 else { throw ContentFailure(.invalidCurriculum, "Too many modules") }
        try uniqueIDs(modules.map(\.id))
        guard Set(modules.map(\.order)).count == modules.count else { throw ContentFailure(.invalidCurriculum, "Duplicate module order") }
        for module in modules {
            guard (1...64).contains(module.order), Set(module.titles.keys) == ["en", "uk"], Set(module.summaries.keys) == ["en", "uk"],
                  (Array(module.titles.values) + Array(module.summaries.values)).allSatisfy({
                      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.contains("{{") && $0.count <= 500
                  }) else { throw ContentFailure(.invalidCurriculum, "Invalid bilingual module: \(module.id)") }
        }
    }
    func validatePlacement(_ placement: LessonCurriculumPlacement, lessonID: String, catalog: LessonCatalogManifest) throws {
        guard catalog.modules?.contains(where: { $0.id == placement.moduleID }) == true,
              (1...1024).contains(placement.ordinal), (1...120).contains(placement.durationMinutes),
              placement.prerequisites.count <= 16, placement.keywords.count <= 32,
              placement.prerequisites.allSatisfy({ $0 != lessonID && catalog.lessons.contains($0) }),
              placement.keywords.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 80 }) else {
            throw ContentFailure(.invalidCurriculum, "Invalid placement/prerequisites: \(lessonID)")
        }
        try uniqueIDs(placement.prerequisites)
    }
    /// Identify every participant in a dependency cycle without invalidating unrelated lessons.
    func curriculumCycles(_ lessons: [LoadedLesson]) -> Set<String> {
        let graph = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0.manifest.curriculum?.prerequisites ?? []) })
        var done = Set<String>(), cycles = Set<String>(), path: [String] = []
        func visit(_ id: String) {
            if let start = path.firstIndex(of: id) { cycles.formUnion(path[start...]); return }
            guard !done.contains(id) else { return }
            path.append(id)
            for dependency in graph[id] ?? [] { visit(dependency) }
            path.removeLast(); done.insert(id)
        }
        for lesson in lessons { visit(lesson.id) }
        return cycles
    }
}
