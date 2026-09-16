import Foundation
import Testing
import Domain
@testable import Learning

struct FretboardTheoryCourseTests {
    @Test func noteNamesAndOctavesRetainTheirDistinctTuningPoliciesAndIntervals() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let names = try #require(report.lessons.first { $0.id == "fretboard-note-names" })
        let octaves = try #require(report.lessons.first { $0.id == "octaves" })
        #expect(names.manifest.adaptation?.policy == .fretPattern)
        #expect(octaves.manifest.adaptation?.policy == .transposeIntervals)
        let low = [40,38,38,36,36,34,35,33], middle = [45,45,43,43,41,41,40,40], high = [64,64,62,62,60,60,59,59]
        for (index,tuning) in TuningProfile.presets.enumerated() {
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning:tuning,frets:frets)
                for lesson in [names,octaves] {
                    #expect(lesson.manifest.practiceEntries.count == 3)
                    for activity in lesson.manifest.activities {
                        let resolved = try lesson.resolveActivity(id:activity.id,instrument:instrument)
                        let exercise = try #require(resolved.exercises.first)
                        let pitches = try exercise.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi)
                        let expected: [Int]
                        switch activity.id {
                        case "low-chromatic": expected = (0...4).map { low[index]+$0 }
                        case "high-chromatic": expected = (0...4).map { high[index]+$0 }
                        case "name-repeat": expected = [low[index],low[index]+12,middle[index],middle[index]+12,high[index],high[index]+12]
                        case "same-pitch": expected = Array(repeating:middle[index],count:4)
                        case "cross-string-octave": expected = [0,12,2,14,0,12].map { middle[index]+$0 }
                        case "same-string-octave": expected = [middle[index],middle[index]+12,middle[index],middle[index]+12,high[index],high[index]+12]
                        default: Issue.record("Unexpected activity"); continue
                        }
                        #expect(pitches == expected)
                        #expect(exercise.durationTicks == (activity.id == "same-pitch" ? 3840 : 7680))
                        for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument:tuning,bpm:bpm) }
                        if activity.id == "same-string-octave" {
                            let p=exercise.events.filter { $0.kind == .note }.compactMap { $0.positions.first }
                            for i in stride(from:0,to:p.count,by:2) { #expect(p[i].string == p[i+1].string && p[i+1].fret-p[i].fret == 12) }
                        }
                        for copy in [resolved.english,resolved.ukrainian] {
                            #expect(copy.activities[activity.id]?.body.contains("{{") == false)
                        }
                    }
                }
            }
        }
    }
}

extension FretboardTheoryCourseTests {
    @Test func intervalsDegreesTriadsAndTranspositionHaveIndependentMusicalGoldens() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let ids=["intervals","tonic-and-degrees","building-triads","transpose-a-melody"]
        let golden: [String:[Int]] = [
            "second":[48,50,48,50],"minor-third":[48,51,48,51],"major-third":[48,52,48,52],"fourth":[48,53,48,53],"fifth":[48,55,48,55],"octave":[48,60,48,60],
            "degree-map":[48,50,52,53,55,57,59,60],"return-home":[48,52,55,48,48,53,50,48,48,57,59,60],"two-endings":[48,50,52,50,48,50,52,48],
            "major-stack":[48,52,55,48],"minor-stack":[48,51,55,48],"chord-contrast":[48,52,55,48,51,55],
            "original-key":[48,50,52,55,52,50,48],"whole-tone-up":[50,52,54,57,54,52,50],"phrase-pairs":[48,50,52,55,50,52,54,57]
        ]
        for id in ids {
            let lesson = try #require(report.lessons.first { $0.id == id })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift=[0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    for activity in lesson.manifest.activities {
                        let target = try #require(lesson.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises.first)
                        let expected = try #require(golden[activity.id]).map { $0+shift }
                        #expect(try target.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == expected)
                        if activity.id == "chord-contrast" {
                            #expect(target.assessmentMode == .displayOnly && target.noteCount == 2 && target.durationTicks == 7680)
                            #expect(target.events.filter { $0.kind == .rest }.map(\.startTick) == [2880,6720])
                        } else {
                            #expect(target.events.filter { $0.kind == .note }.allSatisfy { $0.durationTicks == 960 })
                            #expect(target.durationTicks == Int64((expected.count+3)/4)*3840)
                            for bpm in [40.0,50.0,90.0] { try target.validateForPractice(instrument:tuning,bpm:bpm) }
                        }
                    }
                }
            }
        }
    }
}

extension FretboardTheoryCourseTests {
    @Test func tuningGeometryAndSelectableFretboardMapPreserveExactPitchesAcrossEveryPreset() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let geometry = try #require(report.lessons.first { $0.id == "fingering-key-tuning" })
        let map = try #require(report.lessons.first { $0.id == "fretboard-map" })
        for (index,tuning) in TuningProfile.presets.enumerated() {
            let shift=[0,0,-2,-2,-4,-4,-5,-5][index]
            for frets in GuitarFretCount.allCases {
                let instrument=InstrumentProfile(tuning:tuning,frets:frets)
                for (a,activity) in geometry.manifest.activities.enumerated() {
                    let ex=try #require(geometry.resolveActivity(id:activity.id,instrument:instrument).exercises.first)
                    let source=[[43,50,43,50],[48,53,48,53],[57,62,57,62]][a]
                    #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == source.map { $0+shift })
                    if a == 0 { #expect(ex.events[0].positions.first?.fret == (index.isMultiple(of:2) ? 3 : 5)) }
                    try ex.validateForPractice(instrument:tuning,bpm:90)
                }
                let choices=map.availableChoices(activityID:"explore",instrument:instrument)
                #expect(choices.count == 5)
                for activity in map.manifest.activities {
                    let requested: [PositionChoice?] = activity.id == "explore" ? choices.map(Optional.some) : [nil]
                    for choice in requested {
                        let resolved=try map.resolveActivity(id:activity.id,instrument:instrument,choice:choice)
                        let ex=try #require(resolved.exercises.first)
                        #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == [55,57,55,57].map { $0+shift })
                        if case let .region(firstFret) = resolved.choice {
                            #expect(ex.events.flatMap(\.positions).allSatisfy { (firstFret...firstFret+5).contains($0.fret) })
                        }
                        #expect(ex.durationTicks == 3840 && ex.noteCount == 4)
                        try ex.validateForPractice(instrument:tuning,bpm:90)
                    }
                }
            }
        }
    }
}
