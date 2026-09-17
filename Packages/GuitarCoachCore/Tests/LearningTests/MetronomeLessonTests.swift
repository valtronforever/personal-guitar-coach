import Foundation
import Testing
import Domain
@testable import Learning

struct MetronomeLessonTests {
    @Test func authoredGapsFollowTuningAndMaterialNormalizationWithoutRemovingNotes() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let lesson = try #require(report.lessons.first { $0.id == "missing-clicks" })
        for (i,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            for activity in lesson.manifest.activities {
                let ex = try lesson.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises[0]
                let count = activity.id == "sparse-clicks" ? 16 : activity.id == "one-silent-bar" ? 24 : 32
                let sourcePitches = count == 32 ? Array(repeating:[60,62,64,60],count:8).flatMap { $0 } : Array(repeating:60,count:count)
                let silent: [Int64] = count == 16 ? [0,1920,3840,5760,7680,9600,11520,13440] : count == 24 ? [3840,4800,5760,6720,11520,12480,13440,14400] : [7680,8640,9600,10560,11520,12480,13440,14400]
                #expect(ex.events.count == count && ex.events.allSatisfy { $0.kind == .note && $0.durationTicks == 960 })
                #expect(ex.events.map(\.startTick) == (0..<count).map { Int64($0*960) })
                #expect(ex.metronome?.silentBeatTicks == silent)
                let shift = [0,0,-2,-2,-4,-4,-5,-5][i]
                #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == sourcePitches.map { $0+shift })
                for bpm in [40.0,60.0,90.0] { try ex.validateForPractice(instrument:tuning,bpm:bpm) }
            }
        } }
        let exercise = lesson.manifest.exercises[1], ids = Array(exercise.events[4..<8]).map(\.id)
        let material = LessonMaterial(id:"fragment",source:LessonMaterialSource(kind:.events,exerciseID:exercise.id,eventIDs:ids))
        let activity = LessonActivity(id:"fragment",materialID:material.id)
        let step = LessonStep(id:"play",kind:.events,exerciseID:exercise.id,eventIDs:ids,activityID:activity.id)
        let manifest = LessonManifest(id:"fragment",steps:[step],exercises:[exercise],adaptation:LessonAdaptationDefinition(policy:.transposeIntervals),materials:[material],activities:[activity],practiceEntries:[],fingerings:[])
        try LessonCatalogLoader().validate(manifest)
        func text(_ locale:String) -> LessonText {
            LessonText(lessonID:"fragment",lessonVersion:1,locale:locale,title:"Fragment",summary:"Silent bar",goal:"Keep time",body:"Continue the notes",steps:["play":LessonStepText(title:"Play",body:"{{positions}}")],activities:["fragment":LessonActivityText(title:"Silent bar",body:"{{sequence}}")])
        }
        let scoped = try LoadedLesson(manifest:manifest,english:text("en"),ukrainian:text("uk")).resolveActivity(id:"fragment",instrument:InstrumentProfile(tuning:.cStandard))
        #expect(scoped.exercises[0].events.map(\.startTick) == [0,960,1920,2880])
        #expect(scoped.exercises[0].metronome?.silentBeatTicks == [0,960,1920,2880])
        #expect(scoped.sourceMappings.first?.startTick == 3840)
    }
}
