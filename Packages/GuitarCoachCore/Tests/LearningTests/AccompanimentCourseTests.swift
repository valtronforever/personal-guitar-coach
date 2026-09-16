import Foundation
import Testing
import Domain
@testable import Learning

struct AccompanimentCourseTests {
    @Test func chordChangesAndPhysicalBarresKeepTheirTaughtStructure() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let changes = try #require(report.lessons.first { $0.id == "two-chord-changes" })
        let barre = try #require(report.lessons.first { $0.id == "small-barre" })
        #expect(changes.manifest.practiceEntries.isEmpty)
        #expect(barre.manifest.practiceEntries.count == 2)
        for tuning in TuningProfile.presets {
            for frets in GuitarFretCount.allCases {
                let instrument = try InstrumentProfile(tuning: tuning, frets: frets)
                for activity in changes.manifest.activities {
                    let resolved = try changes.resolveActivity(id: activity.id, instrument: instrument)
                    let exercise = try #require(resolved.exercises.first)
                    #expect(exercise.durationTicks == 15360 && exercise.assessmentMode == .displayOnly)
                    let notes = exercise.events.filter { $0.kind == .note }
                    #expect(notes.count == (activity.id == "prepare-change" ? 4 : 16))
                    for note in notes {
                        let fiveStrings = (note.startTick / 3840).isMultiple(of: 2)
                        #expect(note.positions.count == (fiveStrings ? 5 : 4))
                        #expect(note.strum?.direction == .down)
                        let pitches = try note.positions.map { try tuning.pitch(at: $0).midi }
                        let root = (fiveStrings ? 45 : 50) + tuning.strings[0].openPitch.midi - 64
                        #expect(Set(pitches.map { ($0 - root + 120) % 12 }) == [0,3,7])
                    }
                }
                for activity in barre.manifest.activities {
                    let resolved = try barre.resolveActivity(id: activity.id, instrument: instrument)
                    let exercise = try #require(resolved.exercises.first)
                    #expect(exercise.events.flatMap(\.positions).allSatisfy { $0.fret == 5 })
                    if activity.id.hasSuffix("shape") {
                        let shape = try #require(resolved.fingerings.first?.fingering)
                        #expect(Set(shape.fingerNumbers.values) == [1])
                        #expect(Set(shape.fingerNumbers.keys) == Set(shape.positions.map(\.string)))
                        #expect(exercise.assessmentMode == .displayOnly)
                    } else {
                        #expect(exercise.noteCount == 6 && exercise.durationTicks == 7680)
                        #expect(exercise.events.last?.kind == .rest && exercise.events.last?.durationTicks == 1920)
                        for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                    }
                }
            }
        }
    }
}

extension AccompanimentCourseTests {
    @Test func bassComparisonAndSongFormHaveIndependentPitchAndTimingGoldens() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let selection = try #require(report.lessons.first { $0.id == "chord-string-selection" })
        let song = try #require(report.lessons.first { $0.id == "first-song-form" })
        #expect(song.manifest.practiceEntries.isEmpty && selection.manifest.practiceEntries.count == 2)
        let shifts = [0,0,-2,-2,-4,-4,-5,-5]
        for (index, tuning) in TuningProfile.presets.enumerated() {
            for frets in GuitarFretCount.allCases {
                let instrument = try InstrumentProfile(tuning: tuning, frets: frets)
                let comparison = try selection.resolveActivity(id: "bass-comparison", instrument: instrument)
                let exercise = try #require(comparison.exercises.first)
                let basses = try exercise.resolvedEvents(instrument: tuning).map { try #require($0.pitches.map(\.midi).min()) }
                #expect(basses == [45,40,50,45].map { $0 + shifts[index] })
                #expect(exercise.assessmentMode == .displayOnly)
                for entry in selection.manifest.practiceEntries {
                    let activity = try selection.resolveActivity(id: entry.activityID, instrument: instrument)
                    let target = try #require(activity.exercises.first)
                    #expect(target.durationTicks == 7680)
                    #expect(target.noteCount == (entry.id == "five-strings" ? 5 : 4))
                    for bpm in [40.0,50.0,90.0] { try target.validateForPractice(instrument: tuning, bpm: bpm) }
                }
                for activity in song.manifest.activities {
                    let resolved = try song.resolveActivity(id: activity.id, instrument: instrument)
                    let target = try #require(resolved.exercises.first)
                    #expect(target.assessmentMode == .displayOnly)
                    #expect(target.durationTicks == (activity.id == "complete" ? 61440 : 30720))
                    #expect(target.noteCount == (activity.id == "complete" ? 40 : activity.id == "verse" ? 8 : 32))
                    for event in target.events {
                        let bar = Int(event.startTick / 3840), inSection = bar % 8
                        let major = [4,5].contains(inSection)
                        let rootMIDI = (major ? 40 : [2,3].contains(inSection) ? 50 : 45) + shifts[index]
                        let pitches = try event.positions.map { try tuning.pitch(at: $0).midi }
                        #expect(Set(pitches.map { ($0 - rootMIDI + 120) % 12 }) == [0,major ? 4 : 3,7])
                        let chorus = activity.id == "chorus" || (activity.id == "complete" && bar >= 8)
                        #expect(event.durationTicks == (chorus ? 960 : 3840))
                        #expect(event.accented == (chorus && event.startTick % 3840 == 0))
                    }
                }
            }
        }
    }
}
