import Foundation
import Testing
import Domain
@testable import Learning

struct LessonAdaptationTests {
    private func course() throws -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let lessons = report.lessons.filter { $0.manifest.adaptation != nil && $0.id != "same-notes-new-position" }
        #expect(lessons.count == 6)
        return lessons
    }
    @Test func everyPresetPreservesIntervalsOrTheTaughtPhysicalPatternAndBothTranslations() throws {
        for tuning in TuningProfile.presets {
            for source in try course() {
                let lesson = try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: tuning))
                #expect(lesson.lessonID == source.id && lesson.lessonVersion == source.manifest.version)
                #expect(lesson.steps.map(\.id) == source.manifest.steps.map(\.id))
                let shift = tuning.strings[0].openPitch.midi - 64
                for (original, exercise) in zip(source.manifest.exercises, lesson.exercises) {
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
                    #expect(!text.body.contains("{{") && text.activities["lesson"] != nil)
                    #expect(text.title == source.text(for: language).title)
                    #expect(!text.activities["lesson"]!.body.contains("{{"))
                    #expect(text.lessonVersion == lesson.lessonVersion && text.steps.count == lesson.steps.count)
                    for step in lesson.steps {
                        let visual = try lesson.visual(stepID: step.id)
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
    @Test func allPresetAndFretCountCombinationsFitTheCourse() throws {
        for count in GuitarFretCount.allCases {
            for tuning in TuningProfile.presets {
                let instrument = InstrumentProfile(tuning: tuning, frets: count)
                for source in try course() {
                    let lesson = try source.resolveActivity(id: "lesson", instrument: instrument)
                    #expect(lesson.exercises.flatMap(\.events).flatMap(\.positions).allSatisfy(instrument.contains))
                    #expect(lesson.fingerings.map(\.fingering).flatMap(\.positions).allSatisfy(instrument.contains))
                }
            }
        }
    }
    @Test func shorterNeckRemapsReachablePitchesAndRejectsUnreachableNotes() throws {
        let source = try #require(course().first { $0.id == "c-major" })
        func highLesson(string: Int) throws -> LoadedLesson {
            let exercises = try source.manifest.exercises.map { original in
                let events = try original.events.map { event in
                    try MusicalEvent(id: event.id, startTick: event.startTick, durationTicks: event.durationTicks,
                        kind: event.kind, positions: event.kind == .rest ? [] : [FretPosition(string: string, fret: 24)])
                }
                return try Exercise(id: original.id, events: events, tuningPolicy: .fixedTuning, requiredTuning: .standard)
            }
            return LoadedLesson(manifest: LessonManifest(id: source.id, steps: source.manifest.steps,
                exercises: exercises, adaptation: source.manifest.adaptation, materials: source.manifest.materials, activities: source.manifest.activities, practiceEntries: source.manifest.practiceEntries),
                english: source.english, ukrainian: source.ukrainian)
        }
        let reachable = try highLesson(string: 2).resolveActivity(id: "lesson", instrument: InstrumentProfile(frets: .nineteen))
        #expect(reachable.exercises.flatMap(\.events).flatMap(\.positions).allSatisfy { $0.string == 1 && $0.fret == 19 })
        #expect(try reachable.exercises[0].resolvedEvents(instrument: .standard).flatMap(\.pitches).allSatisfy { $0.midi == 83 })
        let unreachable = try highLesson(string: 1)
        #expect(throws: PositioningError.regionUnplayable) { try unreachable.resolveActivity(id: "lesson", instrument: InstrumentProfile(frets: .nineteen)) }
        #expect(try unreachable.resolveActivity(id: "lesson", instrument: InstrumentProfile()).exercises.flatMap(\.events).flatMap(\.positions).allSatisfy { $0.fret == 24 })
    }
    @Test func cStandardAndDropDHaveIndependentGoldenTargetsAndCorrectChordVoicing() throws {
        let lessons = try course()
        let major = try #require(lessons.first { $0.id == "c-major" })
        let cMajor = try major.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: .cStandard))
        #expect(cMajor.english.title == "Major scale" && cMajor.english.activities["lesson"]?.title == "A♭ major")
        #expect(cMajor.ukrainian.title == "Мажорна гама" && cMajor.ukrainian.activities["lesson"]?.title == "A♭ мажор")
        #expect(try cMajor.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches).map(\.midi) == [44,46,48,49,51,53,55,56,55,53,51,49,48,46,44])
        let pent = try #require(lessons.first { $0.id == "a-minor-pentatonic" }).resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: .dropD))
        let notes = pent.exercises[0].events.filter { $0.kind == .note }
        #expect(notes.prefix(2).flatMap(\.positions).map(\.fret) == [7, 10])
        #expect(try pent.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches).map(\.midi) == [45,48,50,52,55,57,60,62,64,67,69,72,69,67,64,62,60,57,55,52,50,48,45])
        let chord = try #require(lessons.first { $0.id == "em-arpeggio" }).resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: .dropD))
        let shape = try #require(chord.fingerings.first?.fingering)
        #expect(shape.positions.reversed().map(\.fret) == [2,2,2,0,0,0])
        #expect(shape.fingerNumbers.isEmpty)
        #expect(try chord.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches).map(\.midi) == [40,47,52,55,59,64])
        #expect(lessons.first { $0.id == "em-arpeggio" }?.manifest.practiceEntries.contains { $0.exerciseID == chord.exercises[0].id } == false)
    }
    @Test func customNamesRemainLiteral() throws {
        let source = try #require(course().first)
        let named = try TuningProfile(id: "literal-name", name: "My {{root}} tuning", strings: TuningProfile.cStandard.strings)
        let copy = LessonText(lessonID: source.id, lessonVersion: source.manifest.version, locale: "en", title: "Generic",
            summary: "Generic", goal: "Generic", body: "Generic", steps: source.english.steps,
            activities: ["lesson": LessonActivityText(title: "{{tuning}}", body: "A4 {{reference}}")])
        let lesson = LoadedLesson(manifest: source.manifest, english: copy, ukrainian: source.ukrainian)
        #expect(try lesson.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: named)).english.activities["lesson"]?.title == named.name)
    }
    @Test func customReferenceNonuniformTuningAndImpossibleVoicingsAreExplicit() throws {
        let strings = try [64,59,55,48,43,38].enumerated().map { try TunedString(number: $0.offset + 1, openPitch: Pitch(midi: $0.element)) }
        let custom = try TuningProfile(id: "custom-test", name: "My tuning", strings: strings, referenceA4: 442)
        for source in try course() {
            let lesson = try source.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: custom))
            #expect(lesson.english.activities["lesson"] != nil && lesson.ukrainian.activities["lesson"] != nil)
            for exercise in lesson.exercises { #expect(exercise.requiredTuning == custom) }
        }
        let impossible = try TuningProfile(id: "impossible", name: "Extreme", strings: (1...6).map { try TunedString(number: $0, openPitch: Pitch(midi: $0 == 1 ? 100 : 0)) })
        let major = try #require(course().first { $0.id == "c-major" })
        #expect(throws: PositioningError.regionUnplayable) { try major.resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: impossible)) }
        // String-pattern lessons can still be visualized; capability gates refuse unsupported grading.
        let intro = try #require(course().first { $0.id == "open-strings-intro" }).resolveActivity(id: "lesson", instrument: InstrumentProfile(tuning: impossible))
        #expect(throws: (any Error).self) { try intro.exercises[0].validateForPractice(instrument: impossible, bpm: 60) }
    }
}
