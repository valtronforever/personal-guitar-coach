import Foundation
import Testing
import Domain
@testable import Learning

struct TripletLessonTests {
    private func lesson(_ id: String) throws -> LoadedLesson {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first { $0.id == id })
    }
    @Test func courseKeepsTripletSlotsShuffleRatioAndPitchTargetsInEveryPreset() throws {
        for id in ["triplets","swing-shuffle"] {
            let source = try lesson(id)
            for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning:tuning,frets:frets)
                for activity in source.manifest.activities {
                    let resolved = try source.resolveActivity(id:activity.id,instrument:instrument)
                    let ex = try #require(resolved.exercises.first)
                    let sourceExercise = try #require(source.manifest.exercises.first { $0.id == ex.id })
                    #expect(ex.triplets == sourceExercise.triplets)
                    let pitches: [Int]
                    switch activity.id {
                    case "duple-and-triple": pitches = Array(repeating:60,count:25)
                    case "triplet-pulse": pitches = Array(repeating:60,count:24)
                    case "triplet-melody": pitches = [60,62,64,62,64,65,64,65,67,67,65,64,65,64,62,64,62,60,64,62,60,60]
                    case "straight-and-shuffle", "shuffle-pulse": pitches = Array(repeating:48,count:16)
                    case "shuffle-phrase": pitches = [48,55,48,57,48,58,48,57,48,55,52,55,48]
                    default: Issue.record("Unexpected activity"); continue
                    }
                    let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                    #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == pitches.map { $0+shift })
                    #expect(ex.durationTicks == (activity.id == "duple-and-triple" ? 15360 : 7680))
                    for group in ex.triplets {
                        let members = ex.events.filter { group.eventIDs.contains($0.id) }
                        if id == "swing-shuffle" { #expect(members.map(\.durationTicks) == [640,320]) }
                        else if members.count == 3 { #expect(members.map(\.durationTicks) == [320,320,320]) }
                        else { #expect(members.map(\.kind) == [.note,.rest] && members.map(\.durationTicks) == [320,640]) }
                    }
                    for bpm in [40.0,60.0,90.0] { try ex.validateForPractice(instrument:tuning,bpm:bpm) }
                    #expect(try JSONDecoder().decode(Exercise.self,from:JSONEncoder().encode(ex)) == ex)
                }
            } }
        }
    }
    @Test func eventMaterialsMustKeepWholeGroupsAndNormalizeTheirQuarterBoundary() throws {
        let source = try lesson("triplets"), exercise = source.manifest.exercises[0]
        func fixture(_ ids: [String]) throws -> LoadedLesson {
            let material = LessonMaterial(id:"fragment",source:LessonMaterialSource(kind:.events,exerciseID:exercise.id,eventIDs:ids))
            let activity = LessonActivity(id:"fragment",materialID:material.id)
            let step = LessonStep(id:"play",kind:.events,exerciseID:exercise.id,eventIDs:ids,activityID:activity.id)
            let manifest = LessonManifest(id:"fragment",steps:[step],exercises:[exercise],adaptation:LessonAdaptationDefinition(policy:.transposeIntervals),materials:[material],activities:[activity],practiceEntries:[],fingerings:[])
            try LessonCatalogLoader().validate(manifest)
            func text(_ locale:String) -> LessonText {
                LessonText(lessonID:"fragment",lessonVersion:1,locale:locale,title:"Fragment",summary:"Triplet",goal:"Keep time",body:"Three equal slots",steps:["play":LessonStepText(title:"Play",body:"{{positions}}")],activities:["fragment":LessonActivityText(title:"Triplet",body:"{{sequence}}")])
            }
            return LoadedLesson(manifest:manifest,english:text("en"),ukrainian:text("uk"))
        }
        let group = try #require(exercise.triplets.first)
        let scoped = try fixture(group.eventIDs).resolveActivity(id:"fragment",instrument:InstrumentProfile(tuning:.cStandard))
        #expect(scoped.exercises[0].events.map(\.startTick) == [0,320,640])
        #expect(scoped.exercises[0].triplets == [group])
        #expect(scoped.sourceMappings.first?.startTick == 7680)
        #expect(throws: ContentFailure.self) { try fixture(Array(group.eventIDs.prefix(2))) }
        #expect(throws: ContentFailure.self) { try fixture(["e12"] + group.eventIDs) }
    }
}
