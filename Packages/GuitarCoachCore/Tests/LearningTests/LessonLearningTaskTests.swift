import Foundation
import Testing
import Domain
import Yams
@testable import Learning

struct LessonLearningTaskTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func lesson(_ id: String) throws -> LoadedLesson {
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first { $0.id == id })
    }
    @Test func theoryAndSelfAssessmentNeedNoDummyScoredExercise() throws {
        let theory = try lesson("guitar-foundations")
        #expect(theory.manifest.exercises.isEmpty && theory.manifest.activities.isEmpty && theory.manifest.practiceEntries.isEmpty)
        #expect(theory.manifest.tasks.map(\.kind) == [.checklist, .quiz])
        let chord = try lesson("power-chord-self-practice")
        #expect(chord.manifest.practiceEntries.isEmpty)
        let exercise = try #require(chord.manifest.exercises.first)
        #expect(exercise.assessmentMode == .displayOnly && exercise.events[0].positions.count == 2)
        #expect(throws: (any Error).self) { try exercise.validateForPractice(instrument: .standard, bpm: 60) }
    }

    @Test func examplesKeepTheirMusicalMeaningAcrossEveryPresetAndNeck() throws {
        for (id, interval) in [("hear-pitch-direction", 2), ("power-chord-self-practice", 7)] {
            let lesson = try lesson(id)
            for tuning in TuningProfile.presets {
                for frets in GuitarFretCount.allCases {
                    let resolved = try lesson.resolveActivity(id: "example", instrument: InstrumentProfile(tuning: tuning, frets: frets))
                    let exercise = try #require(resolved.exercises.first)
                    let pitches = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                    #expect(pitches.count == 2 && abs(pitches[1] - pitches[0]) == interval)
                    #expect(exercise.events.flatMap(\.positions).allSatisfy { $0.fret <= frets.rawValue })
                    #expect(resolved.english.taskTexts == lesson.english.taskTexts)
                    #expect(resolved.ukrainian.taskTexts == lesson.ukrainian.taskTexts)
                }
            }
        }
    }

    @Test(arguments: ["step", "duplicate", "empty", "answer", "stimulus", "pattern", "graded", "visual", "options", "translation", "explanation", "token", "schema"])
    func brokenTasksAndTranslationsAreRejected(problem: String) throws {
        let id = "hear-pitch-direction"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(at: root.appendingPathComponent("Resources/Lessons/\(id)"), to: directory.appendingPathComponent(id))
        try Data("schemaVersion: 1\nlessons: [\(id)]\n".utf8).write(to: directory.appendingPathComponent("catalog.yml"))
        let manifestURL = directory.appendingPathComponent("\(id)/lesson.yml")
        let textURL = directory.appendingPathComponent("\(id)/uk.yml")
        var manifest = try #require(Yams.load(yaml: String(contentsOf: manifestURL, encoding: .utf8)) as? [String: Any])
        var tasks = try #require(manifest["learningTasks"] as? [[String: Any]])
        var text = try #require(Yams.load(yaml: String(contentsOf: textURL, encoding: .utf8)) as? [String: Any])
        var copies = try #require(text["learningTasks"] as? [String: [String: Any]])
        switch problem {
        case "step": tasks[0]["stepID"] = "missing"
        case "duplicate": tasks.append(tasks[0])
        case "empty": tasks[0]["itemIDs"] = []
        case "answer": tasks[0]["correctOptionID"] = "missing"
        case "stimulus": tasks[0]["stimulusExerciseID"] = "missing"
        case "pattern": manifest["adaptation"] = ["policy": "fretPattern"]
        case "graded": manifest["practiceEntries"] = [["id":"play", "activityID":"example", "exerciseID":id + "-practice"]]
        case "visual": manifest["steps"] = [["id":"listen", "kind":"events", "eventIDs":["first"], "exerciseID":id + "-practice", "activityID":"example"]]
        case "options": copies["direction"]?["items"] = ["higher":"Вище"]
        case "translation": copies = [:]
        case "explanation": copies["direction"]?.removeValue(forKey: "explanation")
        case "token": copies["direction"]?["body"] = "{{first}}"
        default: manifest["schemaVersion"] = 2
        }
        manifest["learningTasks"] = tasks; text["learningTasks"] = copies
        try Yams.dump(object: manifest).write(to: manifestURL, atomically: true, encoding: .utf8)
        try Yams.dump(object: text).write(to: textURL, atomically: true, encoding: .utf8)
        let report = LessonCatalogLoader().load(directory: directory)
        #expect(report.lessons.isEmpty && report.issues.count == 1)
    }

    @Test func progressChecksRequireExactContextAndAllCriteria() throws {
        let task = try #require(lesson("power-chord-self-practice").manifest.tasks.first)
        let context = LessonTaskContext(lessonVersion: 1, instrument: InstrumentProfile(tuning: .cStandard))
        #expect(!task.isComplete(LessonTaskProgress(context: context, checkedIDs: [task.itemIDs[0]]), context: context))
        let value = LessonTaskProgress(context: context, checkedIDs: Set(task.itemIDs))
        #expect(task.isComplete(value, context: context))
        #expect(!task.isComplete(value, context: LessonTaskContext(lessonVersion: 2, instrument: context.instrument)))
        #expect(!task.isComplete(value, context: LessonTaskContext(lessonVersion: 1, instrument: InstrumentProfile(tuning: .dropD))))
        let quiz = try #require(lesson("hear-pitch-direction").manifest.tasks.first)
        #expect(!quiz.isComplete(LessonTaskProgress(context: context, answerID: "lower"), context: context))
        #expect(quiz.isComplete(LessonTaskProgress(context: context, answerID: "higher"), context: context))
    }

    @Test(arguments: ["theory", "selfPractice", "listening"])
    func authorScaffoldsLoadAsCompleteBilingualLessons(mode: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("schemaVersion: 1\nlessons: []\n".utf8).write(to: directory.appendingPathComponent("catalog.yml"))
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", root.appendingPathComponent("Scripts/new_lesson.py").path, "new-mode", "--catalog", directory.path, "--mode", mode]
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let report = LessonCatalogLoader().load(directory: directory)
        #expect(report.issues.isEmpty && report.lessons.count == 1)
        #expect(report.lessons.first?.manifest.tasks.isEmpty == false)
    }
}
