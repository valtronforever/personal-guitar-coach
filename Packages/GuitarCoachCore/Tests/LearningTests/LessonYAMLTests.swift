import Foundation
import Testing
import Learning

struct LessonYAMLTests {
    private struct Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        init() throws {
            let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: repository.appendingPathComponent("docs/templates/lesson"),
                                            to: root.appendingPathComponent("lesson-template"))
            try FileManager.default.copyItem(at: repository.appendingPathComponent("Resources/Lessons/c-major"),
                                            to: root.appendingPathComponent("c-major"))
            try write("catalog.yml", "# Display order\nschemaVersion: 1\nlessons: [lesson-template, c-major]\n")
        }
        func write(_ path: String, _ text: String) throws {
            try text.write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        func load() -> LessonCatalogReport { LessonCatalogLoader().load(directory: root) }
        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    @Test func commentsQuotedScalarsAndTextBlocksReachTheLessonUnchanged() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let original = try #require(fixture.load().lessons.first)
        // Replace generic prose in a real bilingual lesson with author-written YAML.
        let url = fixture.root.appendingPathComponent("lesson-template/en.yml")
        var text = try String(contentsOf: url, encoding: .utf8)
        let bodyStart = try #require(text.range(of: "\nbody:"))
        let bodyEnd = try #require(text.range(of: "\nsteps:", range: bodyStart.upperBound..<text.endIndex))
        text.replaceSubrange(bodyStart.lowerBound..<bodyEnd.lowerBound, with: """

        body: |- # Preserve paragraphs, Unicode, colon and sharp notation
          Play C♯4: slowly # this is part of the text.

          Потім повтори — без поспіху.
        """)
        try fixture.write("lesson-template/en.yml", text)
        var loaded = try #require(fixture.load().lessons.first)
        #expect(loaded.english.body == "Play C♯4: slowly # this is part of the text.\n\nПотім повтори — без поспіху.")
        #expect(loaded.manifest == original.manifest)
        #expect(loaded.ukrainian == original.ukrainian)
        text = text.replacingOccurrences(of: "body: |-", with: "body: >-")
            .replacingOccurrences(of: "Play C♯4: slowly # this is part of the text.\n\n  Потім повтори — без поспіху.",
                                  with: "First line\n  continues here.")
        try fixture.write("lesson-template/en.yml", text)
        loaded = try #require(fixture.load().lessons.first)
        #expect(loaded.english.body == "First line continues here.")
    }

    @Test(arguments: ["syntax", "duplicate", "nested-duplicate", "multiple-documents", "wrong-type", "utf8"])
    func invalidLessonHasYAMLDiagnosticAndKeepsHealthyContent(kind: String) throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        let path = "lesson-template/lesson.yml"
        switch kind {
        case "syntax": try fixture.write(path, "schemaVersion: 2\nsteps: [unterminated\n")
        case "duplicate": try fixture.write(path, "schemaVersion: 2\nschemaVersion: 99\n")
        case "nested-duplicate": try fixture.write(path, "schemaVersion: 2\nsource:\n  kind: lesson\n  kind: exercise\n")
        case "multiple-documents": try fixture.write(path, "schemaVersion: 2\n---\nschemaVersion: 2\n")
        case "wrong-type": try fixture.write(path, "schemaVersion: [2]\n")
        default: try Data([0xFF, 0xFE, 0xFF]).write(to: fixture.root.appendingPathComponent(path))
        }
        let report = fixture.load()
        #expect(report.lessons.map(\.id) == ["c-major"])
        #expect(report.issues.map(\.code) == [.invalidYAML])
    }

    @Test func malformedCatalogAndTranslationDifferFromMissingFiles() throws {
        let fixture = try Fixture(); defer { fixture.remove() }
        try fixture.write("lesson-template/uk.yml", "title: [broken\n")
        #expect(fixture.load().issues.map(\.code) == [.invalidYAML])
        #expect(fixture.load().lessons.map(\.id) == ["c-major"])
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("lesson-template/uk.yml"))
        #expect(fixture.load().issues.map(\.code) == [.missingTranslation])
        try fixture.write("catalog.yml", "schemaVersion: 1\nlessons: [broken\n")
        #expect(fixture.load().issues.map(\.code) == [.invalidYAML])
        #expect(fixture.load().lessons.isEmpty)
        try FileManager.default.moveItem(at: fixture.root.appendingPathComponent("catalog.yml"),
                                         to: fixture.root.appendingPathComponent("catalog.json"))
        #expect(fixture.load().issues.map(\.code) == [.unavailableCatalog])
    }
}
