import Foundation
import Testing
import Yams
import Domain
@testable import Learning

struct LessonCurriculumTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func fixture() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for id in ["guitar-anatomy", "guitar-foundations", "pick-grip"] {
            try FileManager.default.copyItem(at: root.appendingPathComponent("Resources/Lessons/\(id)"), to: dir.appendingPathComponent(id))
        }
        try """
        schemaVersion: 1
        lessons: [guitar-anatomy, guitar-foundations, pick-grip]
        modules:
          - id: getting-started
            order: 1
            titles: {en: Setup, uk: Підготовка}
            summaries: {en: Prepare your guitar, uk: Підготуйте гітару}
        """.write(to: dir.appendingPathComponent("catalog.yml"), atomically: true, encoding: .utf8)
        return dir
    }
    private func edit(_ dir: URL, _ path: String, _ body: (inout [String: Any]) -> Void) throws {
        let file = dir.appendingPathComponent(path)
        var value = try #require(Yams.load(yaml: String(contentsOf: file, encoding: .utf8)) as? [String: Any])
        body(&value)
        try Yams.dump(object: value).write(to: file, atomically: true, encoding: .utf8)
    }
    @Test(arguments: ["module", "ordinal", "duration", "missing", "self", "duplicate", "keywords"])
    func invalidPlacementIsIsolated(problem: String) throws {
        let dir = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(LessonCatalogLoader().load(directory: dir).issues.isEmpty)
        try edit(dir, "pick-grip/lesson.yml") { value in
            var p = value["curriculum"] as! [String: Any]
            switch problem {
            case "module": p["moduleID"] = "absent"
            case "ordinal": p["ordinal"] = 1
            case "duration": p["durationMinutes"] = 0
            case "missing": p["prerequisites"] = ["absent"]
            case "self": p["prerequisites"] = ["pick-grip"]
            case "duplicate": p["prerequisites"] = ["guitar-anatomy", "guitar-anatomy"]
            default: p["keywords"] = ["  "]
            }
            value["curriculum"] = p
        }
        let report = LessonCatalogLoader().load(directory: dir)
        #expect(report.lessons.map(\.id) == ["guitar-anatomy", "guitar-foundations"])
        #expect(report.issues.count == 1 && report.issues[0].lessonID == "pick-grip")
    }
    @Test func cyclesRejectEveryParticipantButKeepIndependentLessons() throws {
        let dir = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
        try edit(dir, "guitar-anatomy/lesson.yml") { value in
            var p = value["curriculum"] as! [String: Any]; p["prerequisites"] = ["guitar-foundations"]; value["curriculum"] = p
        }
        let report = LessonCatalogLoader().load(directory: dir)
        #expect(report.lessons.map(\.id) == ["pick-grip"])
        #expect(Set(report.issues.compactMap(\.lessonID)) == ["guitar-anatomy", "guitar-foundations"])
        #expect(report.issues.allSatisfy { $0.code == .invalidCurriculum })
    }
    @Test(arguments: ["translation", "blank", "duplicate", "order", "token"])
    func malformedModuleCannotSupplyMisleadingLabels(problem: String) throws {
        let dir = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
        try edit(dir, "catalog.yml") { value in
            var modules = value["modules"] as! [[String: Any]]
            switch problem {
            case "translation": modules[0]["titles"] = ["en": "Setup"]
            case "blank": modules[0]["summaries"] = ["en": "  ", "uk": "Текст"]
            case "duplicate": modules.append(modules[0])
            case "order": modules[0]["order"] = 0
            default: modules[0]["titles"] = ["en": "{{root}}", "uk": "Назва"]
            }
            value["modules"] = modules
        }
        let report = LessonCatalogLoader().load(directory: dir)
        #expect(report.lessons.isEmpty && report.issues.count == 1)
    }
    @Test func optionalEditorialListsDefaultToEmpty() throws {
        let value = try YAMLDecoder().decode(LessonCurriculumPlacement.self, from: "moduleID: basics\nordinal: 1\ndurationMinutes: 5\n")
        #expect(value.prerequisites.isEmpty && value.keywords.isEmpty)
    }
    @Test func optionalPlacementKeepsStandaloneAuthorTemplatesUsable() throws {
        let dir = try fixture(); defer { try? FileManager.default.removeItem(at: dir) }
        for id in ["guitar-anatomy", "guitar-foundations", "pick-grip"] {
            try edit(dir, "\(id)/lesson.yml") { $0.removeValue(forKey: "curriculum") }
        }
        try edit(dir, "catalog.yml") { $0.removeValue(forKey: "modules") }
        let report = LessonCatalogLoader().load(directory: dir)
        #expect(report.issues.isEmpty && report.lessons.count == 3 && report.modules.isEmpty)
    }
    @Test func foundationExamplesHaveIndependentTargetsAcrossAllPresetsAndNecks() throws {
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let golden: [String: [Int]] = [
            "clean-fretted-note": [57,57,57,57], "down-up-strokes": Array(repeating: 59, count: 8),
            "adjacent-strings": [55,59,55,59,55,59,55,59], "reading-tab": [59,60,62,64,62,60],
            "first-melody": [60,62,64,64,62,60,62,64,65,64,62,60,59,60]
        ]
        for source in report.lessons where golden[source.id] != nil {
            for tuning in TuningProfile.presets {
                let offset = tuning.strings[0].openPitch.midi - TuningProfile.standard.strings[0].openPitch.midi
                for frets in GuitarFretCount.allCases {
                    for entry in source.manifest.practiceEntries {
                        let adapted = try source.resolveActivity(id: entry.activityID, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                        let exercise = try #require(adapted.exercises.first { $0.id == entry.exerciseID })
                        #expect(try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi) == golden[source.id]!.map { $0 + offset })
                        for bpm in [exercise.minimumBPM, exercise.defaultBPM, exercise.maximumBPM] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                        #expect(adapted.english.body == source.english.body && adapted.ukrainian.body == source.ukrainian.body)
                    }
                }
            }
        }
        let toolLesson = try #require(report.lessons.first { $0.id == "standard-and-drop" })
        let activity = try #require(toolLesson.manifest.activities.first)
        let resolved = try toolLesson.resolveActivity(id: activity.id, instrument: InstrumentProfile(tuning: .dropD))
        #expect(resolved.steps.allSatisfy { step in step.tool == toolLesson.manifest.steps.first { $0.id == step.id }?.tool })
        #expect(toolLesson.manifest.steps.contains { $0.tool != nil })
    }
    @Test func standardAndDropPracticeHasCorrectIndependentLowStringTargets() throws {
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        let source = try #require(report.lessons.first { $0.id == "standard-and-drop" })
        let targets: [(TuningProfile, [Int])] = [
            (.standard, [40,45,42,45]), (.dropD, [38,45,40,45]),
            (.dStandard, [38,43,40,43]), (.dropC, [36,43,38,43]),
            (.cStandard, [36,41,38,41]), (.dropBFlat, [34,41,36,41]),
            (.bStandard, [35,40,37,40]), (.dropA, [33,40,35,40])
        ]
        #expect(source.manifest.practiceEntries.count == 1)
        let entry = try #require(source.manifest.practiceEntries.first)
        for (tuning, expected) in targets {
            for frets in GuitarFretCount.allCases {
                let adapted = try source.resolveActivity(id: entry.activityID, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                let exercise = try #require(adapted.exercises.first { $0.id == entry.exerciseID })
                #expect(exercise.assessmentMode == .monophonic)
                #expect(try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi) == expected)
                for bpm in [exercise.minimumBPM, exercise.defaultBPM, exercise.maximumBPM] {
                    try exercise.validateForPractice(instrument: tuning, bpm: bpm)
                }
            }
        }
    }
}
