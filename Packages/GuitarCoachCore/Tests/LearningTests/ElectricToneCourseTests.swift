import Foundation
import Testing
import Domain
@testable import Learning

struct ElectricToneCourseTests {
    private func catalog() -> LessonCatalogReport {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
    }

    @Test func controlledToneComparisonsRetainIndependentMusicAndDoNotGradeEffects() throws {
        let report = catalog()
        #expect(report.issues.isEmpty)
        let common = [60,64,67,60]
        let targets: [String: [String: [Int]]] = [
            "pickup-volume-tone": ["control": common], "clean-crunch-high-gain": ["control": common],
            "amp-cabinet-ir": ["control": common], "equalization": ["control": [57,60,64,67,57]],
            "drive-compression-gate": ["control": [60,60,64]], "time-and-modulation-effects": ["control": [60,67]],
            "expressive-hardware": ["long-note": [60,64], "chord-swell": [60,64,67,60,64,67]],
            "record-di-monitoring": ["attack-rest": [60,64,67], "clean-take": [60,62,64,67,64,60,62,64,67,64,62,60]]]
        var cases = 0
        for id in targets.keys.sorted() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(lesson.manifest.topic == .tone && lesson.manifest.curriculum?.moduleID == "electric-tone")
            #expect(lesson.manifest.practiceEntries.count == (id == "record-di-monitoring" ? 2 : 0))
            #expect(lesson.manifest.tasks.contains { $0.kind == .selfPractice })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for activity in lesson.manifest.activities {
                        #expect(lesson.availableChoices(activityID: activity.id, instrument: instrument) == [.original])
                        let resolved = try lesson.resolveActivity(id: activity.id, instrument: instrument)
                        let exercise = try #require(resolved.exercises.first)
                        let sounding = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                        #expect(sounding == targets[id]![activity.id]!.map { $0 + shift })
                        #expect(exercise.durationTicks == (activity.id == "clean-take" ? 15360 : 7680))
                        #expect(exercise.events.last?.kind == .rest)
                        #expect(exercise.events.flatMap(\.positions).allSatisfy(instrument.contains))
                        if id == "record-di-monitoring" {
                            for bpm in [40.0,60.0,120.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                        } else {
                            #expect(exercise.assessmentMode == .displayOnly)
                            #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm: 60) }
                        }
                        if id == "time-and-modulation-effects" {
                            #expect(exercise.events.map(\.startTick) == [0,960,3840,4800])
                            #expect(exercise.events.map(\.durationTicks) == [960,2880,960,2880])
                        }
                        for language in [LessonLanguage.en,.uk] {
                            let text = resolved.text(for: language)
                            #expect(text.body == lesson.text(for: language).body)
                            #expect(!text.activities[activity.id]!.body.contains("{{"))
                            #expect(text.taskTexts == lesson.text(for: language).taskTexts)
                        }
                        cases += 1
                    }
                }
            }
        }
        #expect(cases == 400)
    }

    @Test func hardwareSelfChecksStayIncompleteAndQuizzesHaveExplicitFactualAnswers() throws {
        let report = catalog()
        let hardware = try #require(report.lessons.first { $0.id == "expressive-hardware" })
        let task = try #require(hardware.manifest.tasks.first)
        let context = LessonTaskContext(lessonVersion: 1, instrument: InstrumentProfile(tuning: .cStandard))
        let limited = LessonTaskProgress(context: context, checkedIDs: ["swell","restore"])
        #expect(task.itemIDs == ["swell","arm","feedback","restore"])
        #expect(!task.isComplete(limited, context: context))
        #expect(hardware.manifest.practiceEntries.isEmpty)
        for (id,answer) in [("clean-crunch-high-gain","clean"),("amp-cabinet-ir","response"),("time-and-modulation-effects","dotted"),("record-di-monitoring","rendered")] {
            let lesson = try #require(report.lessons.first { $0.id == id })
            let question = try #require(lesson.manifest.tasks.first { $0.kind == .quiz })
            #expect(question.correctOptionID == answer && question.stimulusExerciseID == nil)
            #expect(question.isComplete(LessonTaskProgress(context: context, answerID: answer), context: context))
            for language in [LessonLanguage.en,.uk] {
                #expect(lesson.text(for: language).taskTexts[question.id]?.explanation?.isEmpty == false)
            }
        }
        let di = try #require(report.lessons.first { $0.id == "record-di-monitoring" })
        #expect(di.manifest.steps.first?.tool == .audioSetup)
    }
}
