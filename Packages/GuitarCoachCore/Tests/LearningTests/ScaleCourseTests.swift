import Foundation
import Testing
import Domain
@testable import Learning

struct ScaleCourseTests {
    private func lessons() throws -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return report.lessons
    }

    @Test func scaleFamiliesAndConnectingRoutesHaveIndependentPitchAndRhythmGoldens() throws {
        let course = try lessons()
        let goldens: [String: [String: [Int]]] = [
            "natural-minor": [
                "up-and-down": [45,47,48,50,52,53,55,57,55,53,52,50,48,47,45],
                "parallel-comparison": [45,47,49,50,52,54,56,57,45,47,48,50,52,53,55,57],
                "tonic-phrase": [45,48,52,45,53,55,47,45]],
            "major-pentatonic": [
                "major-pattern": [48,50,52,55,57,60,57,55,52,50,48],
                "same-tonic-contrast": [48,52,55,60,48,51,55,60,48,57,55,48,48,58,55,48],
                "melodic-answer": [48,50,52,55,57,55,50,48]],
            "blues-scale": [
                "six-note-route": [45,48,50,51,52,55,57,55,52,51,50,48,45],
                "passing-tone": [50,51,52,45,52,51,50,45],
                "blues-phrase": [45,48,50,51,52,50,48,45]],
            "connect-scale-positions": [
                "shared-note": [64,64,64,64],
                "crossing-phrase": [60,62,64,67,69,72,69,67,64,62,60,57],
                "returning-route": [57,60,62,64,67,69,67,64,62,60,57]]
        ]
        let bars: [String: Int64] = ["up-and-down":4,"parallel-comparison":6,"tonic-phrase":2,
            "major-pattern":3,"same-tonic-contrast":4,"melodic-answer":2,
            "six-note-route":4,"passing-tone":2,"blues-phrase":3,
            "shared-note":2,"crossing-phrase":3,"returning-route":3]
        for (id, activities) in goldens {
            let lesson = try #require(course.first { $0.id == id })
            #expect(lesson.manifest.practiceEntries.count == 3)
            for (index, tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    for (activityID, pitches) in activities {
                        let resolved = try lesson.resolveActivity(id: activityID, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                        let exercise = try #require(resolved.exercises.first)
                        let actual = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                        #expect(actual == pitches.map { $0 + shift })
                        #expect(exercise.durationTicks == (try #require(bars[activityID])) * 3840)
                        let expectedDurations: [Int64] = activityID == "passing-tone" ? [480,480,960,1920,480,480,960,1920] : Array(repeating: 960, count: pitches.count)
                        #expect(exercise.events.filter { $0.kind == .note }.map(\.durationTicks) == expectedDurations)
                        if activityID == "parallel-comparison" {
                            #expect(exercise.events.filter { $0.kind == .rest }.map(\.startTick) == [7680,8640,9600,10560,19200,20160,21120,22080])
                        }
                        if activityID == "shared-note" {
                            #expect(exercise.events.flatMap(\.positions).map(\.string) == [2,3,2,3])
                            #expect(exercise.events.flatMap(\.positions).map(\.fret) == [5,9,5,9])
                            #expect(exercise.events.filter { $0.kind == .rest }.map(\.startTick) == [960,2880,4800,6720])
                        }
                        for bpm in [exercise.minimumBPM,exercise.defaultBPM,exercise.maximumBPM] {
                            try exercise.validateForPractice(instrument: tuning, bpm: bpm)
                        }
                        #expect(exercise.events.flatMap(\.positions).allSatisfy { $0.fret <= frets.rawValue })
                        #expect(try JSONDecoder().decode(Exercise.self, from: JSONEncoder().encode(exercise)) == exercise)
                    }
                }
            }
        }
    }

    @Test func sequencesKeepQuarterPulseAndIndependentGroupAccentsAcrossBars() throws {
        let lesson = try #require(lessons().first { $0.id == "scale-sequences" })
        let goldens: [String: [Int]] = [
            "groups-three": [48,50,52,50,52,53,52,53,55,53,55,57,55,57,59,57,59,60],
            "groups-four": [48,50,52,53,50,52,53,55,52,53,55,57,53,55,57,59,55,57,59,60],
            "diatonic-thirds": [48,52,50,53,52,55,53,57,55,59,57,60,48]]
        let accents: [String: [Int64]] = ["groups-three":[0,2880,5760,8640,11520,14400],
            "groups-four":[0,3840,7680,11520,15360],"diatonic-thirds":[0,1920,3840,5760,7680,9600,11520]]
        for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            for (id,pitches) in goldens {
                let ex = try #require(lesson.resolveActivity(id:id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises.first)
                #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == pitches.map { $0 + [0,0,-2,-2,-4,-4,-5,-5][index] })
                #expect(ex.events.allSatisfy { $0.durationTicks == 960 })
                #expect(ex.events.filter(\.accented).map(\.startTick) == accents[id])
                #expect(ex.durationTicks == (id == "groups-three" ? 19200 : id == "groups-four" ? 23040 : 15360))
                try ex.validateForPractice(instrument:tuning,bpm:90)
            }
        } }
    }

    @Test func guidedRelocationPreservesOctavesAndNewLearningTasksKeepHistoricMusicVersions() throws {
        let course = try lessons()
        let position = try #require(course.first { $0.id == "same-notes-new-position" })
        let expected = [48,50,52,53,55,57,59,60,59,57,55,53,52,50,48]
        for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            let instrument = InstrumentProfile(tuning:tuning,frets:frets)
            #expect(position.availableChoices(activityID:"explore",instrument:instrument) == [.original,.region(firstFret:3),.region(firstFret:7)])
            for activity in position.manifest.activities {
                let choices = position.availableChoices(activityID:activity.id,instrument:instrument)
                #expect(!choices.isEmpty)
                for choice in choices {
                    let resolved = try position.resolveActivity(id:activity.id,instrument:instrument,choice:choice)
                    let ex = try #require(resolved.exercises.first)
                    let pitches = activity.id == "note" ? [55] : expected
                    #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == pitches.map { $0 + [0,0,-2,-2,-4,-4,-5,-5][index] })
                    #expect(ex.durationTicks == (activity.id == "note" ? 960 : 15360))
                    if case let .region(start) = choice {
                        let width = activity.id == "note" ? 5 : 6
                        #expect(ex.events.flatMap(\.positions).allSatisfy { (start..<start+width).contains($0.fret) })
                    }
                }
            }
        } }
        let ids = ["c-major","natural-minor","a-minor-pentatonic","major-pentatonic","blues-scale","connect-scale-positions","same-notes-new-position","scale-sequences"]
        for id in ids {
            let lesson = try #require(course.first { $0.id == id })
            #expect(lesson.manifest.tasks.filter { $0.kind == .quiz }.count == 1)
            #expect(lesson.manifest.tasks.filter { $0.kind == .selfPractice }.count == 1)
            #expect(lesson.english.taskTexts.count == 2 && lesson.ukrainian.taskTexts.count == 2)
            if ["c-major","a-minor-pentatonic"].contains(id) {
                #expect(lesson.manifest.version == 3 && lesson.manifest.exercises[0].version == 2)
            } else if id == "same-notes-new-position" {
                #expect(lesson.manifest.version == 2 && lesson.manifest.exercises[0].version == 1)
            }
        }
    }
}
