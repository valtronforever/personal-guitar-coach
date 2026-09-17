import Foundation
import Learning
import Persistence

enum LessonReadingStatus: String, CaseIterable {
    case notStarted, inProgress, read, updated
    static func status(_ lesson: LoadedLesson, bookmark: LessonBookmark?) -> Self {
        guard let bookmark else { return .notStarted }
        if bookmark.readVersion == lesson.manifest.version { return .read }
        if bookmark.lessonVersion != lesson.manifest.version || bookmark.readVersion != nil { return .updated }
        return .inProgress
    }
}

enum LessonLearningMode: String, CaseIterable {
    case theory, selfPractice, quiz, listening, scored
    func includes(_ lesson: LoadedLesson) -> Bool {
        switch self {
        case .scored: return !lesson.manifest.practiceEntries.isEmpty
        case .selfPractice: return lesson.manifest.tasks.contains { $0.kind == .selfPractice }
        case .listening: return lesson.manifest.tasks.contains { $0.stimulusExerciseID != nil } || lesson.manifest.practiceEntries.contains { $0.presentation == .listenAndRepeat }
        case .quiz: return lesson.manifest.tasks.contains { $0.kind == .quiz && $0.stimulusExerciseID == nil }
        case .theory: return lesson.manifest.exercises.isEmpty || lesson.manifest.tasks.contains { $0.kind == .checklist }
        }
    }
}

enum LessonSort: String, CaseIterable { case course, title, duration }

struct LessonFilter: Equatable {
    var query = ""
    var difficulty: LessonDifficulty?
    var topic: LessonTopic?
    var moduleID: String?
    var mode: LessonLearningMode?
    var readingStatus: LessonReadingStatus?
    var sort: LessonSort = .course
    var isActive: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || difficulty != nil || topic != nil || moduleID != nil || mode != nil || readingStatus != nil }
    var selectionCount: Int { [difficulty != nil, topic != nil, moduleID != nil, mode != nil, readingStatus != nil].filter { $0 }.count }

    func matches(_ lesson: LoadedLesson, language: LessonLanguage, bookmark: LessonBookmark? = nil, module: LessonModule? = nil) -> Bool {
        guard difficulty == nil || lesson.manifest.difficulty == difficulty,
              topic == nil || lesson.manifest.topic == topic,
              moduleID == nil || lesson.manifest.curriculum?.moduleID == moduleID,
              mode == nil || mode?.includes(lesson) == true,
              readingStatus == nil || LessonReadingStatus.status(lesson, bookmark: bookmark) == readingStatus else { return false }
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if terms.isEmpty { return true }
        // Search both editions so familiar technique names continue to work after changing UI language.
        let copies = [lesson.text(for: language), lesson.text(for: language == .en ? .uk : .en)]
        let fields = copies.flatMap { [$0.title, $0.summary, $0.goal] } + (lesson.manifest.curriculum?.keywords ?? [])
            + (module.map { Array($0.titles.values) } ?? [])
        let haystack = fields.joined(separator: " ")
        return terms.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: language.rawValue)) != nil }
    }
    func results(_ lessons: [LoadedLesson], language: LessonLanguage, progress: ReadingProgress, modules: [LessonModule]) -> [LoadedLesson] {
        let moduleMap = Dictionary(uniqueKeysWithValues: modules.map { ($0.id, $0) })
        return lessons.filter { matches($0, language: language, bookmark: progress.lessons[$0.id],
                                       module: $0.manifest.curriculum.flatMap { moduleMap[$0.moduleID] }) }.sorted { left, right in
            switch sort {
            case .title:
                let comparison = left.text(for: language).title.compare(right.text(for: language).title, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: language.rawValue))
                if comparison != .orderedSame { return comparison == .orderedAscending }
            case .duration:
                let a = left.manifest.curriculum?.durationMinutes ?? Int.max, b = right.manifest.curriculum?.durationMinutes ?? Int.max
                if a != b { return a < b }
            case .course: break
            }
            return Self.ordered(left, right)
        }
    }
    static func ordered(_ left: LoadedLesson, _ right: LoadedLesson) -> Bool {
        let a = left.manifest.curriculum?.ordinal ?? Int.max, b = right.manifest.curriculum?.ordinal ?? Int.max
        return a == b ? left.id < right.id : a < b
    }
}

struct LessonLibraryGroup: Identifiable {
    let id: String
    let module: LessonModule?
    let lessons: [LoadedLesson]
}

extension LessonLibraryStore {
    var courseLessons: [LoadedLesson] { catalogLessons.sorted(by: LessonFilter.ordered) }
    func nextLesson(after lessonID: String) -> LoadedLesson? {
        let lessons = courseLessons
        guard let index = lessons.firstIndex(where: { $0.id == lessonID }), lessons.indices.contains(index + 1) else { return nil }
        return lessons[index + 1]
    }
    func continuation(_ progress: ReadingProgress) -> LoadedLesson? {
        guard let lastID = progress.lastLessonID, let last = sourceLesson(id: lastID) else { return nil }
        if progress.lessons[last.id]?.readVersion != last.manifest.version { return last }
        let later = courseLessons.filter { ($0.manifest.curriculum?.ordinal ?? Int.max) > (last.manifest.curriculum?.ordinal ?? Int.max) }
        return (later + courseLessons).first { progress.lessons[$0.id]?.readVersion != $0.manifest.version }
    }
    func groups(for lessons: [LoadedLesson], sort: LessonSort) -> [LessonLibraryGroup] {
        guard sort == .course else { return [LessonLibraryGroup(id: "_all", module: nil, lessons: lessons)] }
        var groups = modules.compactMap { module -> LessonLibraryGroup? in
            let members = lessons.filter { $0.manifest.curriculum?.moduleID == module.id }
            return members.isEmpty ? nil : LessonLibraryGroup(id: module.id, module: module, lessons: members)
        }
        let other = lessons.filter { $0.manifest.curriculum == nil }
        if !other.isEmpty { groups.append(LessonLibraryGroup(id: "_additional", module: nil, lessons: other)) }
        return groups
    }
}
