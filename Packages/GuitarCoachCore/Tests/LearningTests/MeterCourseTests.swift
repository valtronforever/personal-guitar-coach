import Foundation
import Testing
import Domain
@testable import Learning

struct MeterCourseTests {
    @Test func compoundAndOddLessonsKeepIndependentMusicAndPulseInEveryInstrument() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let melody = [60,62,64,67,64,60,60,64,67,64,62,60,64,65,67,69,67,64,62,64,62,60]
        for id in ["compound-meters","odd-meters"] {
            let source = try #require(report.lessons.first { $0.id == id })
            for (i,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
                for activity in source.manifest.activities {
                    let ex = try source.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises[0]
                    let pitches: [Int], duration: Int64, pulse: Int64, bars: Int64, groups: [Int], step: Int64
                    switch activity.id {
                    case "six-eight-pulse": pitches=Array(repeating:60,count:24); duration=11520; pulse=1440; bars=4; groups=[1,1]; step=480
                    case "six-eight-phrase": pitches=melody; duration=11520; pulse=1440; bars=4; groups=[1,1]; step=480
                    case "twelve-eight-flow": pitches=melody; duration=11520; pulse=1440; bars=2; groups=[1,1,1,1]; step=480
                    case "five-three-two": pitches=Array(repeating:[60,62,64,67,60],count:3).flatMap { $0 }; duration=14400; pulse=960; bars=3; groups=[3,2]; step=960
                    case "five-two-three": pitches=Array(repeating:[60,62,64,67,60],count:3).flatMap { $0 }; duration=14400; pulse=960; bars=3; groups=[2,3]; step=960
                    case "seven-two-two-three": pitches=Array(repeating:[60,62,64,65,67,64,60],count:4).flatMap { $0 }; duration=13440; pulse=480; bars=4; groups=[2,2,3]; step=480
                    case "seven-three-two-two": pitches=Array(repeating:[60,62,64,65,67,64,60],count:4).flatMap { $0 }; duration=13440; pulse=480; bars=4; groups=[3,2,2]; step=480
                    default: Issue.record("Unexpected activity"); continue
                    }
                    let shift = [0,0,-2,-2,-4,-4,-5,-5][i]
                    #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == pitches.map { $0+shift })
                    #expect(ex.durationTicks == duration && ex.timeSignature.pulseTicks == pulse)
                    #expect(ex.durationTicks/ex.timeSignature.ticksPerBar == bars && ex.effectiveBeatGrouping == groups)
                    #expect(ex.events.map(\.startTick) == pitches.indices.map { Int64($0)*step })
                    #expect(ex.triplets.isEmpty)
                    if activity.id == "six-eight-phrase" || activity.id == "twelve-eight-flow" {
                        #expect(ex.events.last?.durationTicks == 1440 && ex.events.filter(\.assessSustain).map(\.id) == [ex.events.last!.id])
                    } else { #expect(ex.events.allSatisfy { $0.durationTicks == step && !$0.assessSustain }) }
                    for bpm in [ex.minimumBPM,ex.defaultBPM,ex.maximumBPM] { try ex.validateForPractice(instrument:tuning,bpm:bpm) }
                }
            } }
        }
    }
}
