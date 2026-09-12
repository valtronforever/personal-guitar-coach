import Foundation
import Testing
import Domain
@testable import Learning

struct LessonAuthoringTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    @Test func teachingStaysIndependentAcrossEveryInstrumentWhileExamplesFollowPitches() throws {
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        for source in report.lessons where source.manifest.adaptation != nil && source.id != "same-notes-new-position" {
            let baseline = try source.resolveActivity(id: "lesson", instrument: InstrumentProfile())
            for tuning in TuningProfile.presets {
                for frets in GuitarFretCount.allCases {
                    let adapted = try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: tuning, frets: frets))
                    let practice = try #require(adapted.exercises.first { source.manifest.practiceEntries.map(\.exerciseID).contains($0.id) })
                    let first = try #require(practice.resolvedEvents(instrument: tuning).flatMap(\.pitches).first)
                    for language in [LessonLanguage.en, .uk] {
                        let text = adapted.text(for: language), original = baseline.text(for: language)
                        #expect([text.title, text.summary, text.goal, text.body] == [original.title, original.summary, original.goal, original.body])
                        let variant = try #require(text.activities["lesson"])
                        #expect(variant.body.contains(first.name(spelling: tuning.preferredSpelling)))
                        #expect(!variant.title.contains("{{") && !variant.body.contains("{{"))
                        #expect(!text.body.contains("A4 =") && !text.body.contains("{{"))
                    }
                }
            }
        }
    }
    @Test func scaffoldProducesLoadableBilingualDraftsAndRefusesOverwriteAndUnsafeIDs() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let catalog = directory.appendingPathComponent("catalog.json")
        try Data(#"{"schemaVersion":1,"lessons":[]}"#.utf8).write(to: catalog)
        func scaffold(_ id: String, policy: String = "fretPattern") throws -> Int32 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", root.appendingPathComponent("Scripts/new_lesson.py").path, id, "--catalog", directory.path, "--policy", policy]
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try process.run(); process.waitUntilExit(); return process.terminationStatus
        }
        #expect(try scaffold("physical-draft") == 0)
        #expect(try scaffold("musical-draft", policy: "transposeIntervals") == 0)
        let report = LessonCatalogLoader().load(directory: directory)
        #expect(report.issues.isEmpty && report.lessons.count == 2)
        for source in report.lessons {
            #expect(source.manifest.exercises[0].id == source.id + "-practice")
            for tuning in TuningProfile.presets {
                let adapted = try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: tuning, frets: .nineteen))
                #expect(adapted.english.activities["lesson"] != nil && adapted.ukrainian.activities["lesson"] != nil)
                #expect(try adapted.visual(stepID: "reflect").positions.isEmpty)
                #expect(adapted.english.steps["reflect"]?.body.contains("{{") == false)
                #expect(adapted.exercises.flatMap(\.events).flatMap(\.positions).allSatisfy { $0.fret <= 19 })
            }
        }
        let bytes = try Data(contentsOf: catalog)
        let manifestURL = directory.appendingPathComponent("physical-draft/lesson.json")
        let manifest = try Data(contentsOf: manifestURL)
        #expect(try scaffold("physical-draft") != 0)
        for id in ["../escape", "Uppercase", String(repeating: "a", count: 56)] { #expect(try scaffold(id) != 0) }
        #expect(try Data(contentsOf: catalog) == bytes)
        #expect(try Data(contentsOf: manifestURL) == manifest)
        var existing = try #require(JSONSerialization.jsonObject(with: manifest) as? [String: Any])
        var exercises = try #require(existing["exercises"] as? [[String: Any]])
        exercises[0]["id"] = "collision-practice"; existing["exercises"] = exercises
        try JSONSerialization.data(withJSONObject: existing).write(to: manifestURL)
        #expect(try scaffold("collision") != 0)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("collision").path))
        #expect(try Data(contentsOf: catalog) == bytes)
    }
    @Test func variantValidationRejectsPartialTranslationsBlankTextAndTokensInTheory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(at: root.appendingPathComponent("docs/templates/lesson"), to: directory.appendingPathComponent("lesson-template"))
        try Data(#"{"schemaVersion":1,"lessons":["lesson-template"]}"#.utf8).write(to: directory.appendingPathComponent("catalog.json"))
        let file = directory.appendingPathComponent("lesson-template/uk.json")
        let original = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        func invalid(_ value: [String: Any], code: ContentIssueCode) throws {
            try JSONSerialization.data(withJSONObject: value).write(to: file)
            let report = LessonCatalogLoader().load(directory: directory)
            #expect(report.lessons.isEmpty && report.issues.contains { $0.code == code })
        }
        var changed = original; changed["activities"] = [:]
        try invalid(changed, code: .translationMismatch)
        changed = original; changed["activities"] = ["lesson": ["title": " ", "body": "Example"]]
        try invalid(changed, code: .invalidText)
        changed = original; changed["body"] = "Theory {{root}}"
        try invalid(changed, code: .invalidText)
        changed = original; changed["activities"] = ["lesson": ["title": "{{unknown}}", "body": "Example"]]
        try invalid(changed, code: .invalidText)
        #expect(original["activities"] != nil)
    }
}
