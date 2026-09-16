import Foundation
import Testing
import Domain
@testable import Learning

struct FirstChordCourseTests {
    @Test func everyChordKeepsItsThirdFifthRootAndSilentStringsAcrossAllPresets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(library.issues.isEmpty)
        let shifts = [0, 0, -2, -2, -4, -4, -5, -5]
        let roots = ["e": 40, "a": 45, "d": 50]
        let rootNames = ["e": ["E","E","D","D","C","C","B","B"], "a": ["A","A","G","G","F","F","E","E"], "d": ["D","D","C","C","B♭","B♭","A","A"]]
        for id in ["minor-chord-shapes", "major-chord-shapes"] {
            let lesson = try #require(library.lessons.first { $0.id == id })
            #expect(lesson.manifest.practiceEntries.count == (id == "minor-chord-shapes" ? 3 : 6))
            for (index, tuning) in TuningProfile.presets.enumerated() {
                for frets in GuitarFretCount.allCases {
                    for activity in lesson.manifest.activities {
                        let name = String(activity.id.split(separator: "-")[0])
                        let family = String(name.prefix(1)), minor = name.hasSuffix("m")
                        let rootMIDI = try #require(roots[family]) + shifts[index]
                        let resolved = try lesson.resolveActivity(id: activity.id, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                        let exercise = try #require(resolved.exercises.first)
                        let pitches = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches)
                        #expect(Set(pitches.map { ($0.midi - rootMIDI + 120) % 12 }) == [0, minor ? 3 : 4, 7])
                        #expect(resolved.english.activities[activity.id]?.title.hasPrefix(rootNames[family]![index] + (minor ? " minor" : " major")) == true)
                        if activity.id.hasSuffix("-shape") {
                            #expect(exercise.assessmentMode == .displayOnly && exercise.events.count == 1)
                            let shape = try #require(resolved.fingerings.first?.fingering)
                            #expect(shape.positions.count == (family == "e" ? 6 : family == "a" ? 5 : 4))
                            #expect(shape.mutedStrings == (family == "e" ? [] : family == "a" ? [6] : [5,6]))
                            if family == "e" && index.isMultiple(of: 2) == false { #expect(shape.fingerNumbers.isEmpty) }
                            #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm: 50) }
                        } else {
                            #expect(exercise.durationTicks == 7680 && exercise.assessmentMode == .monophonic)
                            #expect(exercise.events.filter { $0.kind == .note }.allSatisfy { $0.positions.count == 1 })
                            for bpm in [exercise.minimumBPM, exercise.defaultBPM, exercise.maximumBPM] {
                                try exercise.validateForPractice(instrument: tuning, bpm: bpm)
                            }
                        }
                    }
                }
            }
        }
    }
}
