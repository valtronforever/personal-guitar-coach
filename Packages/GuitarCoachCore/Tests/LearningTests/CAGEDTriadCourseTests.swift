import Foundation
import Testing
import Domain
@testable import Learning

struct CAGEDTriadCourseTests {
    private func library() -> LessonCatalogReport {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
    }

    private struct Voicing {
        let id: String
        let strings: [Int]
        let frets: [Int]
        let pitches: [Int]
        let practiced: Bool
    }

    @Test func cagedFamiliesAndInversionsKeepTheirHarmonicRootAcrossEveryInstrument() throws {
        let catalog = library()
        #expect(catalog.issues.isEmpty)
        let caged = [
            Voicing(id:"c-family",strings:[5,4,3,2,1],frets:[3,2,0,1,0],pitches:[48,52,55,60,64],practiced:true),
            Voicing(id:"a-family",strings:[5,4,3,2,1],frets:[3,5,5,5,3],pitches:[48,55,60,64,67],practiced:true),
            Voicing(id:"g-family-map",strings:[6,5,4,3,2,1],frets:[8,7,5,5,5,8],pitches:[48,52,55,60,64,72],practiced:false),
            Voicing(id:"g-family-fragment",strings:[4,3,2,1],frets:[5,5,5,8],pitches:[55,60,64,72],practiced:true),
            Voicing(id:"e-family",strings:[6,5,4,3,2,1],frets:[8,10,10,9,8,8],pitches:[48,55,60,64,67,72],practiced:true),
            Voicing(id:"d-family",strings:[4,3,2,1],frets:[10,12,13,12],pitches:[60,67,72,76],practiced:true)
        ]
        let inversions = [
            Voicing(id:"root-position",strings:[3,2,1],frets:[5,5,3],pitches:[60,64,67],practiced:true),
            Voicing(id:"first-inversion",strings:[3,2,1],frets:[9,8,8],pitches:[64,67,72],practiced:true),
            Voicing(id:"second-inversion",strings:[3,2,1],frets:[12,13,12],pitches:[67,72,76],practiced:true)
        ]
        let shifts = [0,0,-2,-2,-4,-4,-5,-5]
        let names = ["C","C","B♭","B♭","A♭","A♭","G","G"]
        for (slug,voicings) in [("caged",caged),("triad-inversions",inversions)] {
            let lesson = try #require(catalog.lessons.first { $0.id == slug })
            #expect(lesson.manifest.practiceEntries.count == 5)
            #expect(Set(lesson.english.activities.values.map(\.title)).count == lesson.manifest.activities.count)
            #expect(Set(lesson.ukrainian.activities.values.map(\.title)).count == lesson.manifest.activities.count)
            #expect(!lesson.manifest.practiceEntries.contains { $0.id == "g-family-map-notes" })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning:tuning,frets:frets)
                    for voicing in voicings {
                        let positions = try zip(voicing.strings,voicing.frets).map { string,fret -> FretPosition in
                            let dropOffset = string == 6 && !index.isMultiple(of:2) ? 2 : 0
                            return try FretPosition(string:string,fret:fret+dropOffset)
                        }
                        let expected = voicing.pitches.map { $0+shifts[index] }
                        for mode in voicing.practiced ? ["shape","notes"] : ["shape"] {
                            let aid = voicing.id + "-" + mode
                            let resolved = try lesson.resolveActivity(id:aid,instrument:instrument)
                            let exercise = try #require(resolved.exercises.first)
                            let pitches = try exercise.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi)
                            let simultaneous = mode == "shape" && voicing.id != "g-family-map"
                            #expect(pitches == (simultaneous ? Array(expected.reversed()) : expected))
                            #expect(exercise.events.flatMap(\.positions) == (simultaneous ? Array(positions.reversed()) : positions))
                            #expect(resolved.english.activities[aid]?.title.hasPrefix(names[index]+" major") == true)
                            #expect(resolved.ukrainian.activities[aid]?.title.hasPrefix(names[index]+" мажорний") == true)
                            if voicing.id == "g-family-map" {
                                #expect(resolved.fingerings.isEmpty && exercise.assessmentMode == .displayOnly)
                                #expect(exercise.events.filter { $0.kind == .note }.allSatisfy { $0.positions.count == 1 })
                                #expect(throws:MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument:tuning,bpm:50) }
                            } else if mode == "shape" {
                                let shape = try #require(resolved.fingerings.first?.fingering)
                                #expect(Set(shape.mutedStrings) == Set(1...6).subtracting(voicing.strings))
                                if voicing.strings.contains(6) && !index.isMultiple(of:2) { #expect(shape.fingerNumbers.isEmpty) }
                                #expect(exercise.assessmentMode == .displayOnly)
                                #expect(throws:MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument:tuning,bpm:50) }
                            } else {
                                #expect(exercise.durationTicks == 7680 && exercise.assessmentMode == .monophonic)
                                #expect(exercise.events.dropLast().map(\.startTick) == (0..<positions.count).map { Int64($0)*960 })
                                #expect(exercise.events.last?.kind == .rest && exercise.events.last?.durationTicks == Int64(8-positions.count)*960)
                                for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument:tuning,bpm:bpm) }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func inversionPhrasesChangeOnlyAuthoredVoicingsAndLeaveAQuarterForEveryShift() throws {
        let lesson = try #require(library().lessons.first { $0.id == "triad-inversions" })
        let expected: [(String,[Int])] = [
            ("ascending-regions",[60,64,67,64,67,72,67,72,76,64,67,72]),
            ("read-the-bass",[64,67,72,60,64,67,67,72,76,60,64,67])
        ]
        let shifts = [0,0,-2,-2,-4,-4,-5,-5]
        let onsets: [Int64] = [0,960,1920,3840,4800,5760,7680,8640,9600,11520,12480,13440]
        for (index,tuning) in TuningProfile.presets.enumerated() {
            for frets in GuitarFretCount.allCases {
                for (aid,pitches) in expected {
                    let resolved = try lesson.resolveActivity(id:aid,instrument:InstrumentProfile(tuning:tuning,frets:frets))
                    let exercise = try #require(resolved.exercises.first)
                    #expect(try exercise.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == pitches.map { $0+shifts[index] })
                    let notes = exercise.events.filter { $0.kind == .note }, rests = exercise.events.filter { $0.kind == .rest }
                    #expect(notes.map(\.startTick) == onsets)
                    #expect(notes.allSatisfy { $0.durationTicks == 960 && $0.positions.count == 1 })
                    #expect(rests.map(\.startTick) == [2880,6720,10560,14400])
                    #expect(rests.allSatisfy { $0.durationTicks == 960 } && exercise.durationTicks == 15360)
                    for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument:tuning,bpm:bpm) }
                }
            }
        }
    }
}
