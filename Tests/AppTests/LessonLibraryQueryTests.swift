import Foundation
import Testing
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct LessonLibraryQueryTests {
    private func library() async -> LessonLibraryStore {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let store = LessonLibraryStore(directory: root.appendingPathComponent("Resources/Lessons"))
        await store.load(); return store
    }
    @Test func combinedFiltersSearchBothLanguagesAndEveryTerm() async throws {
        let store = await library()
        let target = try #require(store.sourceLesson(id: "first-melody"))
        let filter = LessonFilter(query: "мелодія melody", difficulty: target.manifest.difficulty, moduleID: "first-notes", mode: .scored, readingStatus: .notStarted)
        let matches = filter.results(store.catalogLessons, language: .en, progress: ReadingProgress(), modules: store.modules)
        #expect(matches.map(\.id) == [target.id])
        #expect(filter.selectionCount == 4 && filter.isActive)
        var mismatch = filter; mismatch.mode = .listening
        #expect(mismatch.results(store.catalogLessons, language: .uk, progress: ReadingProgress(), modules: store.modules).isEmpty)
        mismatch = filter; mismatch.query += " impossible-keyword"
        #expect(!mismatch.matches(target, language: .uk))
        let reset = LessonFilter(sort: .title)
        #expect(!reset.isActive && reset.results(store.catalogLessons, language: .uk, progress: ReadingProgress(), modules: store.modules).count == store.catalogLessons.count)
    }
    @Test func readStateDependsOnVersionAndNeverOnPracticeScores() async throws {
        let store = await library(), lesson = try #require(store.sourceLesson(id: "guitar-foundations"))
        let v = lesson.manifest.version
        #expect(LessonReadingStatus.status(lesson, bookmark: nil) == .notStarted)
        #expect(LessonReadingStatus.status(lesson, bookmark: LessonBookmark(lessonVersion: v, stepID: "prepare")) == .inProgress)
        #expect(LessonReadingStatus.status(lesson, bookmark: LessonBookmark(lessonVersion: v, stepID: nil, readVersion: v)) == .read)
        #expect(LessonReadingStatus.status(lesson, bookmark: LessonBookmark(lessonVersion: v - 1, stepID: nil)) == .updated)
        let progress = ReadingProgress(lastLessonID: lesson.id, lessons: [lesson.id: LessonBookmark(lessonVersion: v, stepID: nil, readVersion: v)])
        #expect(LessonFilter(readingStatus: .read).results(store.catalogLessons, language: .uk, progress: progress, modules: store.modules).map(\.id) == [lesson.id])
        #expect(store.continuation(progress)?.id == "pick-grip")
        #expect(store.continuation(ReadingProgress()) == nil)
        var reading = progress; reading.lessons[lesson.id]?.readVersion = nil
        #expect(store.continuation(reading)?.id == lesson.id)
    }
    @Test func orderedGroupsOmitEmptyModulesAndSortsRemainDeterministic() async throws {
        let store = await library(), progress = ReadingProgress()
        #expect(store.issues.isEmpty)
        let course = LessonFilter().results(store.catalogLessons.reversed(), language: .en, progress: progress, modules: store.modules)
        #expect(course.prefix(3).map(\.id) == ["guitar-anatomy", "guitar-foundations", "pick-grip"])
        #expect(store.nextLesson(after: "guitar-anatomy")?.id == "guitar-foundations")
        #expect(store.nextLesson(after: try #require(course.last).id) == nil)
        let groups = store.groups(for: course, sort: .course)
        #expect(groups.allSatisfy { !$0.lessons.isEmpty })
        #expect(groups.flatMap(\.lessons).map(\.id) == course.map(\.id))
        #expect(groups[0].lessons.count == 8 && groups[1].lessons.count == 8)
        for language in [LessonLanguage.en, .uk] {
            let byTitle = LessonFilter(sort: .title).results(course, language: language, progress: progress, modules: store.modules)
            #expect(byTitle.map(\.id) == LessonFilter(sort: .title).results(course.reversed(), language: language, progress: progress, modules: store.modules).map(\.id))
            #expect(store.groups(for: byTitle, sort: .title).count == 1)
            let byDuration = LessonFilter(sort: .duration).results(course, language: language, progress: progress, modules: store.modules)
            let times = byDuration.compactMap { $0.manifest.curriculum?.durationMinutes }
            #expect(times == times.sorted())
        }
    }
    @Test func modesDistinguishListeningSelfPracticeAndAudioGrading() async throws {
        let store = await library()
        let hearing = try #require(store.sourceLesson(id: "hear-pitch-direction"))
        #expect(LessonLearningMode.listening.includes(hearing) && !LessonLearningMode.quiz.includes(hearing) && LessonLearningMode.scored.includes(hearing))
        let muted = try #require(store.sourceLesson(id: "stop-a-note"))
        #expect(LessonLearningMode.selfPractice.includes(muted) && !LessonLearningMode.scored.includes(muted))
        let fretted = try #require(store.sourceLesson(id: "clean-fretted-note"))
        #expect(LessonLearningMode.selfPractice.includes(fretted) && LessonLearningMode.scored.includes(fretted))
    }

    @Test func completeScaleModuleIsOrderedAndSearchesBothLanguages() async throws {
        let store = await library()
        let filter = LessonFilter(moduleID: "scales-positions", mode: .scored)
        let expected = ["c-major", "natural-minor", "a-minor-pentatonic", "major-pentatonic",
                        "blues-scale", "connect-scale-positions", "same-notes-new-position", "scale-sequences"]
        for language in [LessonLanguage.en, .uk] {
            let matches = filter.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules)
            #expect(matches.map(\.id) == expected)
            #expect(matches.allSatisfy { LessonLearningMode.quiz.includes($0) && LessonLearningMode.selfPractice.includes($0) })
            let search = LessonFilter(query: "пентатоніка major", moduleID: "scales-positions")
            #expect(search.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules).map(\.id) == ["major-pentatonic"])
        }
    }
    @Test func toneModuleSeparatesEquipmentSelfPracticeFromCleanNoteGrading() async throws {
        let store = await library()
        let expected = ["pickup-volume-tone","clean-crunch-high-gain","amp-cabinet-ir","equalization",
                        "drive-compression-gate","time-and-modulation-effects","expressive-hardware","record-di-monitoring"]
        for language in [LessonLanguage.en,.uk] {
            let filter = LessonFilter(topic: .tone, moduleID: "electric-tone", mode: .selfPractice)
            let matches = filter.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules)
            #expect(matches.map(\.id) == expected)
            #expect(matches.allSatisfy { !LessonLearningMode.listening.includes($0) })
            let graded = LessonFilter(moduleID: "electric-tone", mode: .scored)
            #expect(graded.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules).map(\.id) == ["record-di-monitoring"])
            let search = LessonFilter(query: "кабінет IR", moduleID: "electric-tone")
            #expect(search.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules).map(\.id) == ["amp-cabinet-ir"])
            #expect(store.groups(for: matches, sort: .course).map(\.id) == ["electric-tone"])
        }
    }

    @Test func allEightElectricStylesAreOrderedAndDiscoverableAsSelfPractice() async throws {
        let store = await library()
        let expected = ["blues-accompaniment","blues-solo","classic-rock","punk-hardcore","metal-study","funk-study","rnb-neo-soul","country-chicken-picking"]
        for language in [LessonLanguage.en,.uk] {
            let filter = LessonFilter(moduleID: "electric-styles", mode: .selfPractice)
            let matches = filter.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules)
            #expect(matches.map(\.id) == expected)
            #expect(store.groups(for: matches, sort: .course).map(\.id) == ["electric-styles"])
            let scored = LessonFilter(moduleID: "electric-styles", mode: .scored)
            #expect(scored.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules).isEmpty)
            let search = LessonFilter(query: "neo-soul", moduleID: "electric-styles")
            #expect(search.results(store.catalogLessons, language: language, progress: ReadingProgress(), modules: store.modules).map(\.id) == ["rnb-neo-soul"])
        }
    }

}
