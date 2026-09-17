import Foundation
import Testing
import Domain
@testable import Learning

struct RhythmPhrasingCourseTests {
    private func lesson(_ id:String) throws -> LoadedLesson {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first { $0.id == id })
    }
    @Test func syncopationAndDisplacementKeepIndependentPitchTimeAndHoldGoldens() throws {
        for id in ["syncopation","displaced-accents"] {
            let source = try lesson(id)
            for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for activity in source.manifest.activities {
                    let ex = try #require(source.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises.first)
                    let notes = ex.events.filter { $0.kind == .note }
                    let pitches: [Int], starts: [Int64], end: Int64, holds: [Int64]
                    switch activity.id {
                    case "offbeat-attacks": pitches=[48,48,48,48]; starts=[480,1440,2400,3360]; end=3840; holds=[]
                    case "hold-over-the-beat": pitches=[48,48]; starts=[480,2400]; end=3840; holds=[480,2400]
                    case "cross-bar-phrase": pitches=[48,52,55,60,52,55,48]; starts=[480,1440,1920,3360,4800,5280,5760]; end=7680; holds=[3360]
                    case "three-eighth-cycle": pitches=Array(repeating:[48,50,52],count:8).flatMap { $0 }; starts=(0..<24).map { Int64($0*480) }; end=11520; holds=[]
                    case "shifted-cycle": pitches=Array(repeating:[48,50,52],count:8).flatMap { $0 }; starts=(0..<24).map { Int64(480+$0*480) }; end=15360; holds=[]
                    case "four-starting-points":
                        pitches=Array(repeating:[48,50,52,55],count:4).flatMap { $0 }
                        starts=[0,480,960,1440,4320,4800,5280,5760,8640,9120,9600,10080,12960,13440,13920,14400]
                        end=15360; holds=[]
                    default: Issue.record("Unexpected activity"); continue
                    }
                    #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == pitches.map { $0+shift })
                    #expect(notes.map(\.startTick) == starts && ex.durationTicks == end && ex.triplets.isEmpty)
                    #expect(notes.filter(\.assessSustain).map(\.startTick) == holds)
                    #expect(notes.filter(\.assessSustain).allSatisfy { $0.durationTicks == 1440 })
                    if id == "syncopation" {
                        #expect(notes.filter(\.accented).map(\.startTick) == starts.filter { $0%960 == 480 })
                    } else if activity.id == "four-starting-points" {
                        #expect(notes.filter(\.accented).map(\.startTick) == [0,4320,8640,12960])
                    } else {
                        let offset: Int64 = activity.id == "shifted-cycle" ? 480 : 0
                        #expect(notes.filter(\.accented).map(\.startTick) == (0..<8).map { offset+Int64($0*1440) })
                    }
                    for bpm in [40.0,60.0,90.0] { try ex.validateForPractice(instrument:tuning,bpm:bpm) }
                }
            } }
        }
    }
    @Test func gallopFamiliesUseFourSlotsContinuousPickingAndLowestStringAnchor() throws {
        let source = try lesson("gallop-patterns")
        let roots = [40,38,38,36,36,34,35,33]
        #expect(source.manifest.adaptation?.anchorString == 6)
        for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            for activity in source.manifest.activities {
                let ex = try #require(source.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises.first)
                let notes = ex.events.filter { $0.kind == .note }
                let riff = activity.id == "gallop-riff"
                let intervals = riff ? Array(repeating:[0,0,7,0,0,9,0,0,10,0,0,9],count:3).flatMap { $0 }+[0] : Array(repeating:0,count:24)
                #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == intervals.map { roots[index]+$0 })
                #expect(ex.durationTicks == (riff ? 15360 : 7680) && ex.triplets.isEmpty)
                #expect(ex.defaultBPM == 50 && ex.maximumBPM == 70)
                for group in 0..<(riff ? 12 : 8) {
                    let reverse = riff ? (group >= 4 && group < 8 || group >= 8 && !group.isMultiple(of:2)) : activity.id == "reverse-pulse"
                    let durations: [Int64] = reverse ? [240,240,480] : [480,240,240]
                    let members = Array(notes[(group*3)..<(group*3+3)])
                    #expect(members.map(\.durationTicks) == durations)
                    #expect(members[0].startTick == Int64(group*960))
                    #expect(members[0].positions == [try FretPosition(string:6,fret:0)])
                }
                for (n,event) in notes.enumerated() { #expect(event.pickStroke == (n.isMultiple(of:2) ? .down : .up) && !event.palmMuted) }
                if riff { #expect(ex.events.last?.kind == .rest && ex.events.last?.durationTicks == 2880) }
                for bpm in [40.0,50.0,70.0] { try ex.validateForPractice(instrument:tuning,bpm:bpm) }
                #expect(try JSONDecoder().decode(Exercise.self,from:JSONEncoder().encode(ex)) == ex)
            }
        } }
    }
}
