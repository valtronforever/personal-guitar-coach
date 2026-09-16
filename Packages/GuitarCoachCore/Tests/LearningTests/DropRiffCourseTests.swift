import Foundation
import Testing
import Domain
@testable import Learning

struct DropRiffCourseTests {
    @Test func dropRiffKeepsOpenBassCorrectPowerIntervalsAndSeparateGrading() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let lesson = try #require(report.lessons.first { $0.id == "drop-tuning-riffs" })
        #expect(lesson.manifest.adaptation?.anchorString == 6 && lesson.manifest.practiceEntries.count == 2)
        let roots = [40,38,38,36,36,34,35,33]
        for (index,tuning) in TuningProfile.presets.enumerated() {
            for frets in GuitarFretCount.allCases {
                let instrument = try InstrumentProfile(tuning: tuning, frets: frets)
                for activity in lesson.manifest.activities {
                    let resolved = try lesson.resolveActivity(id: activity.id, instrument: instrument)
                    let target = try #require(resolved.exercises.first)
                    if activity.id.hasSuffix("shape") {
                        let moved = activity.id == "moved-shape", offset = moved ? 3 : 0
                        let shape = try #require(resolved.fingerings.first?.fingering)
                        let positions = Dictionary(uniqueKeysWithValues: shape.positions.map { ($0.string, $0.fret) })
                        #expect(positions[6] == offset)
                        #expect(positions[5] == offset + (index.isMultiple(of: 2) ? 2 : 0))
                        #expect(positions[4] == positions[5])
                        #expect(target.assessmentMode == .displayOnly)
                        let expected = [roots[index]+offset,roots[index]+offset+7,roots[index]+offset+12]
                        #expect(try target.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi).sorted() == expected)
                    } else if activity.id == "power-notes" {
                        #expect(target.durationTicks == 7680 && target.noteCount == 7)
                        #expect(try target.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi) == [0,7,12,3,10,15,0].map { roots[index]+$0 })
                        for bpm in [40.0,50.0,90.0] { try target.validateForPractice(instrument: tuning, bpm: bpm) }
                    } else {
                        #expect(target.durationTicks == 15360 && target.noteCount == 20)
                        for (n,event) in target.events.enumerated() {
                            let offset = [0,0,3,5,0][n%5]
                            #expect(event.durationTicks == (n%5 < 2 ? 480 : 960))
                            #expect(event.positions.first?.string == 6 && event.positions.first?.fret == offset)
                            let pitches = try event.positions.map { try tuning.pitch(at: $0).midi }.sorted()
                            let tones = activity.id == "full-riff" && offset > 0 ? [0,7,12] : [0]
                            #expect(pitches == tones.map { roots[index]+offset+$0 })
                        }
                        if activity.id == "bass-riff" {
                            for bpm in [40.0,50.0,90.0] { try target.validateForPractice(instrument: tuning, bpm: bpm) }
                        } else { #expect(throws: MusicError.displayOnlyExercise) { try target.validateForPractice(instrument: tuning, bpm: 50) } }
                    }
                }
            }
        }
    }
}

extension DropRiffCourseTests {
    @Test func powerChordCourseSeparatesChordReferencesFromScoredRootsAndFifths() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let lesson = try #require(report.lessons.first { $0.id == "power-chord-self-practice" })
        #expect(lesson.manifest.version == 2 && lesson.manifest.exercises[0].version == 1)
        #expect(lesson.manifest.tasks.map(\.kind) == [.selfPractice,.quiz])
        #expect(lesson.manifest.tasks.last?.correctOptionID == "fifth")
        #expect(lesson.manifest.practiceEntries.count == 1 && lesson.manifest.practiceEntries[0].activityID == "separate")
        let roots = [43,43,41,41,39,39,38,38]
        for (index,tuning) in TuningProfile.presets.enumerated() {
            for frets in GuitarFretCount.allCases {
                for activity in lesson.manifest.activities {
                    let resolved = try lesson.resolveActivity(id: activity.id, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                    let target = try #require(resolved.exercises.first)
                    let pitches = try target.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                    let offsets = activity.id == "separate" ? [0,7,0,7,2,9,2,9] : activity.id == "octave" ? [0,7,12] : activity.id == "move" ? [2,9] : [0,7]
                    #expect(pitches == offsets.map { roots[index]+$0 })
                    if activity.id == "separate" {
                        #expect(target.durationTicks == 7680 && target.noteCount == 8)
                        for bpm in [40.0,60.0,100.0] { try target.validateForPractice(instrument: tuning, bpm: bpm) }
                    } else {
                        #expect(target.assessmentMode == .displayOnly && target.durationTicks == 3840)
                        #expect(target.events.last?.kind == .rest)
                    }
                }
            }
        }
    }
}
