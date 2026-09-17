import Foundation
import Testing
import Domain
@testable import Learning

/// Course-wide integration audit; topic-specific tests retain independent musical goldens.
struct FullCurriculumAcceptanceTests {
    @Test func all128TopicsHaveReachableBilingualActivitiesAcrossEveryPresetAndNeck() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty && report.lessons.count == 134)
        let course = report.lessons.filter { $0.manifest.curriculum != nil }
        #expect(course.count == 128)
        var activityContexts = 0, practiceContexts = 0
        for lesson in course {
            for tuning in TuningProfile.presets {
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for activity in lesson.manifest.activities {
                        let choices = lesson.availableChoices(activityID: activity.id, instrument: instrument)
                        let choice = try #require(choices.first, "No reachable activity: \(lesson.id)/\(activity.id), \(tuning.id), \(frets)")
                        let snapshot = try lesson.resolveActivity(id: activity.id, instrument: instrument, choice: choice)
                        for language in [LessonLanguage.en,.uk] {
                            let text = snapshot.text(for: language)
                            #expect(!text.title.isEmpty && !text.goal.isEmpty)
                            let guidance = try #require(text.activities[activity.id])
                            #expect(!guidance.title.isEmpty && !guidance.body.isEmpty && !guidance.body.contains("{{"))
                        }
                        #expect(snapshot.exercises.flatMap(\.events).flatMap(\.techniquePositions).allSatisfy(instrument.contains))
                        for entry in lesson.manifest.practiceEntries where entry.activityID == activity.id {
                            let exercise = try #require(snapshot.exercises.first { $0.id == entry.exerciseID })
                            try exercise.validateForPractice(instrument: tuning, bpm: exercise.defaultBPM)
                            try exercise.validateForPractice(instrument: tuning, bpm: exercise.minimumBPM)
                            #expect(exercise.assessmentMode != .displayOnly)
                            practiceContexts += 1
                        }
                        activityContexts += 1
                    }
                }
            }
        }
        #expect(activityContexts > 10_000 && practiceContexts > 8_000)
    }
}
