import Foundation
import Testing
import Domain
@testable import Learning

struct StrumLessonTests {
    @Test func strummingExamplesKeepDirectionsAndHaveNoAutomaticChordScore() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(library.issues.isEmpty)
        let lesson = try #require(library.lessons.first { $0.id == "down-up-strumming" })
        #expect(lesson.manifest.practiceEntries.isEmpty && lesson.manifest.tasks.first?.kind == .selfPractice)
        for tuning in TuningProfile.presets {
            for frets in GuitarFretCount.allCases {
                for activity in lesson.manifest.activities {
                    let resolved = try lesson.resolveActivity(id: activity.id, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                    let exercise = try #require(resolved.exercises.first)
                    #expect(exercise.assessmentMode == .displayOnly && exercise.durationTicks == 7680)
                    if activity.id == "air-stroke" {
                        #expect(exercise.events.map(\.startTick) == [0,960,1440,2400,2880,3360,3840,4800,5280,6240,6720,7200])
                        #expect(exercise.events[0].durationTicks == 960 && exercise.events[2].durationTicks == 960)
                    }
                    for event in exercise.events {
                            let down = activity.id == "down-pulse" || (event.startTick / 480).isMultiple(of: 2)
                            #expect(event.strum?.direction == (down ? .down : .up))
                            #expect(event.strum?.spreadTicks == 120)
                            #expect(Set(event.positions.map(\.string)) == (down ? [1,2,3,4,5] : [1,2,3]))
                    }
                }
            }
        }
    }
}
