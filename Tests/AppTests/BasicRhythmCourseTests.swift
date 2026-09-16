import Foundation
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

struct BasicRhythmCourseTests {
    private func lessons() -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons
    }
    @Test func rhythmicGoldensAndAllInstrumentVariantsPreserveWrittenAttacks() throws {
        let expected: [String: (Int64, Int)] = [
            "eighth-notes": (7680, 12), "rhythm-rests": (7680, 5), "slow-sixteenths": (7680, 22),
            "beat-accents": (7680, 8), "simple-meters": (7680, 8), "first-rhythm-study": (30720, 25)
        ]
        for (id, golden) in expected {
            let lesson = try #require(lessons().first { $0.id == id })
            let source = try #require(lesson.manifest.exercises.first)
            #expect(source.durationTicks == golden.0 && source.noteCount == golden.1, "\(id)")
            for tuning in TuningProfile.presets {
                for frets in GuitarFretCount.allCases {
                    for entry in lesson.manifest.practiceEntries {
                        let snapshot = try lesson.resolveActivity(id: entry.activityID, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                        let exercise = try #require(snapshot.exercises.first { $0.id == entry.exerciseID })
                        let original = try #require(lesson.manifest.exercises.first { $0.id == entry.exerciseID })
                        #expect(exercise.events.map(\.accented) == original.events.map(\.accented))
                        #expect(exercise.events.map(\.assessSustain) == original.events.map(\.assessSustain))
                        #expect(exercise.events.map(\.positions) == original.events.map(\.positions))
                        for bpm in [exercise.minimumBPM, exercise.defaultBPM, exercise.maximumBPM] {
                            try exercise.validateForPractice(instrument: tuning, bpm: bpm)
                        }
                    }
                }
            }
        }
        let meters = try #require(lessons().first { $0.id == "simple-meters" })
        let three = try #require(meters.manifest.exercises.last)
        #expect(three.timeSignature == .threeFour && three.durationTicks == 5760 && three.noteCount == 6)
        #expect(three.events.filter(\.accented).map(\.startTick) == [0, 2880])
        let accents = try #require(lessons().first { $0.id == "beat-accents" }?.manifest.exercises.last)
        #expect(accents.events.filter(\.accented).map(\.startTick) == [960, 2880, 4800, 6720])
    }
    @Test func aTiedAccentAppearsOnlyAtTheInitialAttack() throws {
        let event = try MusicalEvent(id: "held", startTick: 0, durationTicks: 4800, kind: .note,
            positions: [FretPosition(string: 6, fret: 0)], accented: true)
        let staff = try StaffModel(timeline: TimelineModel(exercise: Exercise(id: "accent-tie", events: [event]), instrument: .dropA), key: .neutral)
        let first = try staff.symbols(in: 0), second = try staff.symbols(in: 1)
        #expect(first.first?.accentedAttack == true && second.first?.accentedAttack == false)
        #expect(second.first?.eventID == first.first?.eventID)
    }
}
