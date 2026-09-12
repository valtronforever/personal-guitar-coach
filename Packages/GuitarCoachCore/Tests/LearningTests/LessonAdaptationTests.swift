import Foundation
import Testing
import Domain
import Learning

struct LessonAdaptationTests {
    private func course() throws -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let lessons = report.lessons.filter { $0.manifest.adaptation != nil }
        #expect(lessons.count == 6)
        return lessons
    }
    @Test func everyPresetPreservesIntervalsOrTheTaughtPhysicalPatternAndBothTranslations() throws {
        for tuning in TuningProfile.presets {
            for source in try course() {
                let lesson = try source.adapted(to: tuning)
                #expect(lesson.id == source.id && lesson.manifest.version > source.manifest.version)
                #expect(lesson.manifest.steps.map(\.id) == source.manifest.steps.map(\.id))
                let shift = tuning.strings[0].openPitch.midi - 64
                for (original, exercise) in zip(source.manifest.exercises, lesson.manifest.exercises) {
                    #expect(exercise.id == original.id && exercise.version == 2 && exercise.requiredTuning == tuning)
                    #expect(exercise.events.map(\.id) == original.events.map(\.id))
                    #expect(exercise.events.map(\.startTick) == original.events.map(\.startTick))
                    #expect(exercise.events.map(\.durationTicks) == original.events.map(\.durationTicks))
                    let pitches = try exercise.resolvedEvents(instrument: .standard).flatMap(\.pitches).map(\.midi)
                    if source.manifest.adaptation?.policy == .transposeIntervals {
                        #expect(try pitches == original.resolvedEvents(instrument: .standard).flatMap(\.pitches).map { $0.midi + shift })
                    } else { #expect(exercise.events == original.events) }
                    if [TuningProfile.standard, .dStandard, .cStandard, .bStandard].contains(tuning) { #expect(exercise.events == original.events) }
                    if exercise.assessmentMode == .monophonic {
                        for bpm in [exercise.minimumBPM, exercise.defaultBPM, exercise.maximumBPM] {
                            if pitches.contains(where: { $0 < 36 }) {
                                #expect(throws: MusicError.unsupportedPitch) { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                            } else { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                        }
                    }
                }
                for language in [LessonLanguage.en, .uk] {
                    let text = lesson.text(for: language)
                    #expect(!text.body.contains("{{") && text.body.contains(tuning.name))
                    #expect(text.body.contains("\(tuning.strings[5].openPitch.name(spelling: tuning.preferredSpelling)) (6/0)"))
                    #expect(text.lessonVersion == lesson.manifest.version && text.steps.count == lesson.manifest.steps.count)
                    for step in lesson.manifest.steps {
                        let visual = try lesson.visual(stepID: step.id, instrument: .standard)
                        #expect(visual.tuning == tuning)
                        let copy = try #require(text.steps[step.id])
                        #expect(!copy.body.contains("{{") && !copy.title.contains("{{"))
                        for position in visual.positions {
                            #expect(copy.body.contains(position.pitch.name(spelling: tuning.preferredSpelling)))
                            #expect(copy.body.contains("(\(position.position.string)/\(position.position.fret))"))
                        }
                    }
                }
            }
        }
    }
    @Test func cStandardAndDropDHaveIndependentGoldenTargetsAndCorrectChordVoicing() throws {
        let lessons = try course()
        let major = try #require(lessons.first { $0.id == "c-major" })
        let cMajor = try major.adapted(to: .cStandard)
        #expect(cMajor.english.title == "A♭ major across the strings")
        #expect(cMajor.ukrainian.title == "Мажорна гама A♭ через кілька струн")
        #expect(try cMajor.manifest.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches).map(\.midi) == [44,46,48,49,51,53,55,56,55,53,51,49,48,46,44])
        let pent = try #require(lessons.first { $0.id == "a-minor-pentatonic" }).adapted(to: .dropD)
        let notes = pent.manifest.exercises[0].events.filter { $0.kind == .note }
        #expect(notes.prefix(2).flatMap(\.positions).map(\.fret) == [7, 10])
        #expect(try pent.manifest.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches).map(\.midi) == [45,48,50,52,55,57,60,62,64,67,69,72,69,67,64,62,60,57,55,52,50,48,45])
        let chord = try #require(lessons.first { $0.id == "em-arpeggio" }).adapted(to: .dropD)
        let shape = try #require(chord.manifest.steps[0].fingering)
        #expect(shape.positions.reversed().map(\.fret) == [2,2,2,0,0,0])
        #expect(shape.fingerNumbers.isEmpty)
        #expect(try chord.manifest.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches).map(\.midi) == [40,47,52,55,59,64])
        #expect(!chord.manifest.practiceExerciseIDs.contains(chord.manifest.exercises[0].id))
    }
    @Test func customNamesAreLiteralAndMissingOrUnknownTemplateTokensFailClosed() throws {
        let source = try #require(course().first)
        let named = try TuningProfile(id: "literal-name", name: "My {{root}} tuning", strings: TuningProfile.cStandard.strings)
        #expect(try source.adapted(to: named).english.body.contains("My {{root}} tuning"))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(at: root.appendingPathComponent("Resources/Lessons"), to: directory)
        let template = directory.appendingPathComponent("open-strings-intro/adaptive.en.json")
        var text = try String(contentsOf: template, encoding: .utf8)
        text = text.replacingOccurrences(of: "{{openStrings}}", with: "{{unknown}}")
        try text.write(to: template, atomically: true, encoding: .utf8)
        var report = LessonCatalogLoader().load(directory: directory)
        #expect(report.issues.contains { $0.lessonID == "open-strings-intro" && $0.code == .invalidText })
        #expect(!report.lessons.contains { $0.id == "open-strings-intro" })
        try FileManager.default.removeItem(at: template)
        report = LessonCatalogLoader().load(directory: directory)
        #expect(report.issues.contains { $0.lessonID == "open-strings-intro" && $0.code == .missingTranslation })
    }
    @Test func customReferenceNonuniformTuningAndImpossibleVoicingsAreExplicit() throws {
        let strings = try [64,59,55,48,43,38].enumerated().map { try TunedString(number: $0.offset + 1, openPitch: Pitch(midi: $0.element)) }
        let custom = try TuningProfile(id: "custom-test", name: "My tuning", strings: strings, referenceA4: 442)
        for source in try course() {
            let lesson = try source.adapted(to: custom)
            #expect(lesson.english.body.contains("442.0") && lesson.ukrainian.body.contains("442,0"))
            for exercise in lesson.manifest.exercises { #expect(exercise.requiredTuning == custom) }
        }
        let impossible = try TuningProfile(id: "impossible", name: "Extreme", strings: (1...6).map { try TunedString(number: $0, openPitch: Pitch(midi: $0 == 1 ? 100 : 0)) })
        let major = try #require(course().first { $0.id == "c-major" })
        #expect(throws: LessonAdaptationError.unplayable) { try major.adapted(to: impossible) }
        // String-pattern lessons can still be visualized; capability gates refuse unsupported grading.
        let intro = try #require(course().first { $0.id == "open-strings-intro" }).adapted(to: impossible)
        #expect(throws: (any Error).self) { try intro.manifest.exercises[0].validateForPractice(instrument: impossible, bpm: 60) }
    }
}
