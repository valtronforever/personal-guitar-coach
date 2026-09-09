import Foundation
import Testing
import Domain
import Learning

struct LessonContentTests {
    private struct Fixture {
        let root: URL
        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("lesson-tests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try write(LessonCatalogManifest(lessons: ["lesson-one", "lesson-two"]), "catalog.json")
            for id in ["lesson-one", "lesson-two"] {
                try FileManager.default.createDirectory(at: root.appendingPathComponent(id), withIntermediateDirectories: true)
                let exerciseID = id + "-practice"
                let exercise = try Exercise(id: exerciseID, events: [
                    MusicalEvent(id: "low", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)]),
                    MusicalEvent(id: "rest", startTick: 960, durationTicks: 960, kind: .rest),
                    MusicalEvent(id: "high", startTick: 1920, durationTicks: 960, kind: .note, positions: [FretPosition(string: 1, fret: 0)])
                ], tuningPolicy: id == "lesson-two" ? .fixedTuning : .followsInstrument, requiredTuning: id == "lesson-two" ? .standard : nil)
                let steps = try [LessonStep(id: "intro", kind: .none),
                                 LessonStep(id: "low-step", kind: .events, exerciseID: exerciseID, eventIDs: ["low"]),
                                 LessonStep(id: "rest-step", kind: .events, exerciseID: exerciseID, eventIDs: ["rest"]),
                                 LessonStep(id: "high-step", kind: .events, exerciseID: exerciseID, eventIDs: ["high"]),
                                 LessonStep(id: "shape-step", kind: .fingering, exerciseID: exerciseID,
                                            fingering: Fingering(positions: [FretPosition(string: 5, fret: 2)], mutedStrings: [6], fingerNumbers: [5: 1]))]
                try write(LessonManifest(id: id, steps: steps, exercises: [exercise], practiceExerciseIDs: [exerciseID]), "\(id)/lesson.json")
                for locale in ["en", "uk"] {
                    let text = LessonText(lessonID: id, locale: locale, title: locale == "en" ? "Open strings" : "Відкриті струни",
                                          summary: "Summary", goal: "Goal", body: "Text",
                                          steps: Dictionary(uniqueKeysWithValues: steps.map { ($0.id, LessonStepText(title: $0.id, body: "Explanation")) }))
                    try write(text, "\(id)/\(locale).json")
                }
            }
        }
        func write<T: Encodable>(_ value: T, _ path: String) throws { try JSONEncoder().encode(value).write(to: root.appendingPathComponent(path)) }
        func mutate(_ path: String, _ transform: (inout [String: Any]) throws -> Void) throws {
            let url = root.appendingPathComponent(path)
            var value = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            try transform(&value)
            try JSONSerialization.data(withJSONObject: value).write(to: url)
        }
        func remove() { try? FileManager.default.removeItem(at: root) }
        func load() -> LessonCatalogReport { LessonCatalogLoader().load(directory: root) }
    }

    @Test func validBilingualContentResolvesWithoutAudio() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let report = fixture.load()
        #expect(report.issues.isEmpty)
        #expect(report.lessons.count == 2)
        let follows = try #require(report.lessons.first)
        #expect(follows.text(for: .en).lessonID == follows.text(for: .uk).lessonID)
        #expect(follows.text(for: .en).title != follows.text(for: .uk).title)
        #expect(try follows.visual(stepID: "low-step", instrument: .dropD).positions.first?.pitch.midi == 38)
        #expect(try report.lessons[1].visual(stepID: "low-step", instrument: .dropD).positions.first?.pitch.midi == 40)
        let rest = try follows.visual(stepID: "rest-step", instrument: .standard)
        #expect(rest.positions.isEmpty)
        #expect(rest.events.map(\.event.kind) == [.rest])
        let shape = try follows.visual(stepID: "shape-step", instrument: .standard)
        #expect(shape.positions.first?.pitch.midi == 47)
        #expect(shape.positions.first?.finger == 1)
        #expect(shape.mutedStrings == [6])
        #expect(try follows.visual(stepID: "intro", instrument: .standard).positions.isEmpty)
        #expect(try JSONDecoder().decode(LessonManifest.self, from: JSONEncoder().encode(follows.manifest)) == follows.manifest)
        #expect(try JSONDecoder().decode(LessonText.self, from: JSONEncoder().encode(follows.ukrainian)) == follows.ukrainian)
    }

    @Test func missingTranslationDoesNotHideHealthyLesson() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("lesson-one/uk.json"))
        let report = fixture.load()
        #expect(report.lessons.map(\.id) == ["lesson-two"])
        #expect(report.issues.map(\.code) == [.missingTranslation])
    }

    @Test func unknownEventAndDuplicateStepAreRejected() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.mutate("lesson-one/lesson.json") { value in
            var steps = try #require(value["steps"] as? [[String: Any]])
            steps[1]["eventIDs"] = ["does-not-exist"]; value["steps"] = steps
        }
        #expect(fixture.load().issues.map(\.code) == [.unknownEvent])
        try fixture.mutate("lesson-one/lesson.json") { value in
            var steps = try #require(value["steps"] as? [[String: Any]])
            steps.append(steps[0]); value["steps"] = steps
        }
        #expect(fixture.load().issues.map(\.code) == [.duplicateIdentifier])
    }

    @Test(arguments: ["bad-fret", "negative-duration", "unsupported-mode", "duplicate-event"])
    func musicalErrorsCannotReachVisualization(kind: String) throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.mutate("lesson-one/lesson.json") { value in
            var exercises = try #require(value["exercises"] as? [[String: Any]])
            var events = try #require(exercises[0]["events"] as? [[String: Any]])
            switch kind {
            case "bad-fret": events[0]["positions"] = [["string": 6, "fret": 25]]
            case "negative-duration": events[0]["durationTicks"] = -1
            case "unsupported-mode": exercises[0]["assessmentMode"] = "polyphonic"
            default: events[2]["id"] = "low"
            }
            exercises[0]["events"] = events; value["exercises"] = exercises
        }
        let report = fixture.load()
        #expect(report.lessons.map(\.id) == ["lesson-two"])
        let expected: ContentIssueCode = kind == "unsupported-mode" ? .unsupportedMode : (kind == "duplicate-event" ? .duplicateIdentifier : .invalidMusicalData)
        #expect(report.issues.map(\.code) == [expected])
    }

    @Test func translationParityAndVersionsAreStrict() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.mutate("lesson-one/uk.json") { $0["lessonVersion"] = 2 }
        #expect(fixture.load().issues.map(\.code) == [.translationMismatch])
        try fixture.mutate("lesson-one/uk.json") { $0["lessonVersion"] = 1; $0["steps"] = [:] }
        #expect(fixture.load().issues.map(\.code) == [.translationMismatch])
        try fixture.mutate("lesson-two/en.json") { $0["title"] = "  " }
        #expect(fixture.load().issues.map(\.code) == [.translationMismatch, .invalidText])
    }

    @Test func futureSchemaIsCheckedBeforeUnknownPayload() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.mutate("lesson-one/lesson.json") { $0 = ["schemaVersion": 99, "future": true] }
        #expect(fixture.load().issues.map(\.code) == [.unsupportedSchema])
        #expect(fixture.load().lessons.map(\.id) == ["lesson-two"])
    }

    @Test func identifiersCannotEscapeTheCatalog() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.write(LessonCatalogManifest(lessons: ["../escape", "lesson-one\n", "lesson-two"]), "catalog.json")
        let report = fixture.load()
        #expect(report.issues.map(\.code) == [.invalidIdentifier, .invalidIdentifier])
        #expect(report.lessons.map(\.id) == ["lesson-two"])
    }

    @Test func explicitChordShapeCannotBecomeAPracticeEntry() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.mutate("lesson-one/lesson.json") { value in
            var exercises = try #require(value["exercises"] as? [[String: Any]])
            exercises[0]["assessmentMode"] = "displayOnly"; value["exercises"] = exercises
        }
        #expect(fixture.load().issues.map(\.code) == [.unsupportedMode])
    }

    @Test func duplicateCatalogEntriesKeepLoadedIDsUnique() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.write(LessonCatalogManifest(lessons: ["lesson-one", "lesson-one", "lesson-one", "lesson-two"]), "catalog.json")
        let report = fixture.load()
        #expect(report.lessons.map(\.id) == ["lesson-one", "lesson-two"])
        #expect(report.issues.map(\.code) == [.duplicateIdentifier, .duplicateIdentifier])
        #expect(Set(report.issues.map(\.id)).count == 2)
    }

    @Test func chordEventsCanBeDisplayedBesideAMonophonicPractice() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let lesson = try #require(fixture.load().lessons.first)
        let positions = try [(6, 0), (5, 2), (4, 2), (3, 0), (2, 0), (1, 0)].map { try FretPosition(string: $0.0, fret: $0.1) }
        let chord = try Exercise(id: "lesson-one-chord", events: [MusicalEvent(id: "em", startTick: 0, durationTicks: 960, kind: .note, positions: positions)],
                                 tuningPolicy: .fixedTuning, requiredTuning: .standard, assessmentMode: .displayOnly)
        let manifest = LessonManifest(id: lesson.id, steps: lesson.manifest.steps + [LessonStep(id: "chord-step", kind: .events, exerciseID: chord.id, eventIDs: ["em"])],
                                      exercises: lesson.manifest.exercises + [chord], practiceExerciseIDs: lesson.manifest.practiceExerciseIDs)
        try fixture.write(manifest, "lesson-one/lesson.json")
        for locale in ["en", "uk"] {
            try fixture.mutate("lesson-one/\(locale).json") { value in
                var steps = try #require(value["steps"] as? [String: Any])
                steps["chord-step"] = ["title": "Em", "body": "Display-only shape"]
                value["steps"] = steps
            }
        }
        let report = fixture.load()
        #expect(report.issues.isEmpty)
        let updated = try #require(report.lessons.first)
        #expect(try updated.visual(stepID: "chord-step", instrument: .dropD).positions.count == 6)
        #expect(throws: MusicError.displayOnlyExercise) { try chord.validateForPractice(instrument: .standard, bpm: 60) }
    }
}
