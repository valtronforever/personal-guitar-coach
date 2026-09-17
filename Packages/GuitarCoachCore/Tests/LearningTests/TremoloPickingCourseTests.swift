import Foundation
import Testing
import Domain
@testable import Learning

struct TremoloPickingCourseTests {
    @Test func burstsKeepCountsRestsAndDirectionsWhileFastApplicationRemainsUnscored() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let lesson = try #require(report.lessons.first { $0.id == "tremolo-picking" })
        let targets = ["subdivision": Array(repeating: 60, count: 12), "measured-bursts": Array(repeating: 60, count: 14),
            "fast-short": Array(repeating: 60, count: 12), "fast-long": Array(repeating: 60, count: 16),
            "burst-study": Array(repeating: 60, count: 4) + Array(repeating: 62, count: 4) + Array(repeating: 64, count: 8) + Array(repeating: 62, count: 16) + Array(repeating: 60, count: 8)]
        let lengths: [String: Int64] = ["subdivision": 7680, "measured-bursts": 15360, "fast-short": 7680, "fast-long": 7680, "burst-study": 15360]
        #expect(lesson.manifest.practiceEntries.map(\.id) == ["subdivision", "measured-bursts"])
        var cases = 0
        for (index,tuning) in TuningProfile.presets.enumerated() {
            let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                for activity in lesson.manifest.activities {
                    #expect(lesson.availableChoices(activityID: activity.id, instrument: instrument) == [.original])
                    let snapshot = try lesson.resolveActivity(id: activity.id, instrument: instrument)
                    let exercise = try #require(snapshot.exercises.first)
                    let pitches = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                    #expect(pitches == targets[activity.id]!.map { $0 + shift })
                    #expect(exercise.durationTicks == lengths[activity.id])
                    #expect(exercise.events.flatMap(\.positions).allSatisfy { instrument.contains($0) && $0.string == 3 })
                    let graded = activity.id == "subdivision" || activity.id == "measured-bursts"
                    var stroke = 0
                    for event in exercise.events {
                        if event.kind == .rest { stroke = 0; continue }
                        #expect(event.pickStroke == (stroke % 2 == 0 ? .down : .up)); stroke += 1
                    }
                    if graded {
                        #expect(exercise.assessmentMode == .monophonic)
                        for bpm in [40.0,60.0,120.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                    } else {
                        #expect(exercise.assessmentMode == .displayOnly && exercise.maximumBPM == 160)
                        #expect(exercise.events.filter { $0.kind == .note }.allSatisfy { $0.durationTicks == 240 })
                        #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm: 80) }
                    }
                    if activity.id == "measured-bursts" {
                        #expect(exercise.events.filter { $0.kind == .rest }.map(\.durationTicks) == [2880,1920,3840])
                    }
                    for language in [LessonLanguage.en,.uk] {
                        let text = snapshot.text(for: language)
                        #expect(text.body == lesson.text(for: language).body && !text.activities[activity.id]!.body.contains("{{"))
                    }
                    cases += 1
                }
            }
        }
        #expect(cases == 200)
        let context = LessonTaskContext(lessonVersion: 1, instrument: InstrumentProfile())
        let task = try #require(lesson.manifest.tasks.first { $0.kind == .selfPractice })
        #expect(!task.isComplete(LessonTaskProgress(context: context, checkedIDs: ["even"]), context: context))
        let quiz = try #require(lesson.manifest.tasks.first { $0.kind == .quiz })
        #expect(quiz.correctOptionID == "four")
    }
}
