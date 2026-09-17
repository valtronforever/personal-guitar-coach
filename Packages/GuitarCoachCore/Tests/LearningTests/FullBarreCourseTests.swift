import Foundation
import Testing
import Domain
@testable import Learning

struct FullBarreCourseTests {
    private struct ExpectedShape {
        let id: String
        let root: Int
        let pitches: [Int]
        let strings: [Int]
        let frets: [Int]
        let minor: Bool
        let practiced: Bool
    }

    @Test func movableBarreShapesPreserveIndependentPitchAndPositionGoldensInEveryPreset() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Lessons")
        let library = LessonCatalogLoader().load(directory: directory)
        #expect(library.issues.isEmpty)
        let six = [6,5,4,3,2,1], five = [5,4,3,2,1]
        let cases: [(String, [ExpectedShape])] = [
            ("major-barre-chords", [
                ExpectedShape(id:"sixth-root",root:45,pitches:[45,52,57,61,64,69],strings:six,frets:[5,7,7,6,5,5],minor:false,practiced:true),
                ExpectedShape(id:"sixth-root-moved",root:47,pitches:[47,54,59,63,66,71],strings:six,frets:[7,9,9,8,7,7],minor:false,practiced:true),
                ExpectedShape(id:"fifth-root",root:50,pitches:[50,57,62,66,69],strings:five,frets:[5,7,7,7,5],minor:false,practiced:true)
            ]),
            ("minor-barre-chords", [
                ExpectedShape(id:"major-sixth-reference",root:45,pitches:[45,52,57,61,64,69],strings:six,frets:[5,7,7,6,5,5],minor:false,practiced:false),
                ExpectedShape(id:"minor-sixth",root:45,pitches:[45,52,57,60,64,69],strings:six,frets:[5,7,7,5,5,5],minor:true,practiced:true),
                ExpectedShape(id:"major-fifth-reference",root:50,pitches:[50,57,62,66,69],strings:five,frets:[5,7,7,7,5],minor:false,practiced:false),
                ExpectedShape(id:"minor-fifth",root:50,pitches:[50,57,62,65,69],strings:five,frets:[5,7,7,6,5],minor:true,practiced:true),
                ExpectedShape(id:"minor-sixth-moved",root:47,pitches:[47,54,59,62,66,71],strings:six,frets:[7,9,9,7,7,7],minor:true,practiced:true)
            ])
        ]
        let shifts = [0,0,-2,-2,-4,-4,-5,-5]
        let rootNames: [Int:[String]] = [45:["A","A","G","G","F","F","E","E"],47:["B","B","A","A","G","G","F♯","F♯"],50:["D","D","C","C","B♭","B♭","A","A"]]
        for (id, shapes) in cases {
            let lesson = try #require(library.lessons.first { $0.id == id })
            #expect(lesson.manifest.practiceEntries.map(\.id) == shapes.filter(\.practiced).map { $0.id + "-notes" })
            for (index, tuning) in TuningProfile.presets.enumerated() {
                for fretCount in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning:tuning,frets:fretCount)
                    for shape in shapes {
                        let expectedPitches = shape.pitches.map { $0 + shifts[index] }
                        let positions = try zip(shape.strings,shape.frets).map { string, fret in
                            try FretPosition(string:string,fret:fret + (string == 6 && !index.isMultiple(of:2) ? 2 : 0))
                        }
                        for mode in shape.practiced ? ["shape","notes"] : ["shape"] {
                            let activityID = shape.id + "-" + mode
                            let resolved = try lesson.resolveActivity(id:activityID,instrument:instrument)
                            let exercise = try #require(resolved.exercises.first)
                            let events = try exercise.resolvedEvents(instrument:tuning)
                            // Chord snapshots use canonical string 1→6 ordering; timed notes retain the authored 6→1 order.
                            let orderedPitches = mode == "shape" ? Array(expectedPitches.reversed()) : expectedPitches
                            let orderedPositions = mode == "shape" ? Array(positions.reversed()) : positions
                            #expect(events.flatMap(\.pitches).map(\.midi) == orderedPitches)
                            #expect(exercise.events.flatMap(\.positions) == orderedPositions)
                            let quality = shape.minor ? " minor" : " major"
                            #expect(resolved.english.activities[activityID]?.title.hasPrefix(rootNames[shape.root]![index] + quality) == true)
                            #expect(Set(expectedPitches.map { ($0-shape.root-shifts[index]+120)%12 }) == [0,shape.minor ? 3 : 4,7])
                            if mode == "shape" {
                                let fingering = try #require(resolved.fingerings.first?.fingering)
                                #expect(fingering.positions == orderedPositions)
                                #expect(fingering.mutedStrings == (shape.strings == six ? [] : [6]))
                                if shape.strings == six && !index.isMultiple(of:2) { #expect(fingering.fingerNumbers.isEmpty) }
                                #expect(exercise.assessmentMode == .displayOnly)
                                #expect(throws:MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument:tuning,bpm:50) }
                            } else {
                                #expect(exercise.assessmentMode == .monophonic && exercise.durationTicks == 7680)
                                #expect(exercise.events.dropLast().map(\.startTick) == (0..<positions.count).map { Int64($0)*960 })
                                #expect(exercise.events.dropLast().allSatisfy { $0.kind == .note && $0.durationTicks == 960 && $0.positions.count == 1 })
                                #expect(exercise.events.last?.kind == .rest && exercise.events.last?.durationTicks == Int64(8-positions.count)*960)
                                for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument:tuning,bpm:bpm) }
                            }
                        }
                    }
                }
            }
        }
    }
}
