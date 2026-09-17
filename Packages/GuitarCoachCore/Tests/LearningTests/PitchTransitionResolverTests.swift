import Foundation
import Testing
import Domain
@testable import Learning

struct PitchTransitionResolverTests {
    private func lesson(window: Int) throws -> LoadedLesson {
        let transition = try PitchTransition(kind:.slide,semitones:2,startTick:960,travelTicks:960)
        let event = try MusicalEvent(id:"change",startTick:0,durationTicks:2880,kind:.note,positions:[FretPosition(string:3,fret:5)],pitchTransition:transition)
        let exercise = try Exercise(id:"linked",events:[event],tuningPolicy:.fixedTuning,requiredTuning:.standard)
        let manifest = LessonManifest(id:"linked",steps:[LessonStep(id:"play",kind:.events,exerciseID:"linked",eventIDs:["change"],activityID:"play")],exercises:[exercise],
            adaptation:LessonAdaptationDefinition(policy:.transposeIntervals),
            materials:[LessonMaterial(id:"m",source:LessonMaterialSource(kind:.exercise,exerciseID:"linked"),positioning:try PositioningPolicy(windowFrets:window,allowedStarts:.explicit([7])))],
            activities:[LessonActivity(id:"play",materialID:"m",positionSelection:ActivityPositionSelection(mode:.learner,defaultChoice:.original))],practiceEntries:[LessonPracticeEntry(id:"play",activityID:"play",exerciseID:"linked")])
        try LessonCatalogLoader().validate(manifest)
        func copy(_ language:String) -> LessonText {
            LessonText(lessonID:"linked",locale:language,title:"Fixture",summary:"Fixture",goal:"Fixture",body:"Fixture",
                steps:["play":LessonStepText(title:"Targets",body:"{{positions}}")],activities:["play":LessonActivityText(title:"{{first}}",body:"{{sequence}}")])
        }
        return LoadedLesson(manifest:manifest,english:copy("en"),ukrainian:copy("uk"))
    }
    @Test func relocationKeepsBothEndpointsInOneStringRegionAndRendersBothWithoutAddingAttacks() throws {
        let narrow = try lesson(window:5), wide = try lesson(window:6)
        for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            let instrument = InstrumentProfile(tuning:tuning,frets:frets)
            #expect(throws:PositioningError.regionUnplayable) { try narrow.resolveActivity(id:"play",instrument:instrument,choice:.region(firstFret:7)) }
            let moved = try wide.resolveActivity(id:"play",instrument:instrument,choice:.region(firstFret:7))
            let event = try #require(moved.exercises.first?.events.first)
            #expect(event.positions == [try FretPosition(string:4,fret:10)])
            #expect(event.techniquePositions == [try FretPosition(string:4,fret:10),try FretPosition(string:4,fret:12)])
            #expect(event.pitchTransition?.semitones == 2 && event.startTick == 0 && event.durationTicks == 2880)
            let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
            #expect(try moved.exercises[0].resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == [60+shift])
            let visual = try moved.visual(stepID:"play")
            #expect(visual.positions.map(\.pitch.midi) == [60+shift,62+shift] && visual.events.count == 1)
            #expect(moved.english.steps["play"]?.body.contains("(4/10)") == true && moved.english.steps["play"]?.body.contains("(4/12)") == true)
            #expect(moved.ukrainian.steps["play"]?.body.contains("(4/12)") == true)
            #expect(try JSONDecoder().decode(Exercise.self,from:JSONEncoder().encode(moved.exercises[0])) == moved.exercises[0])
        } }
    }
    @Test func descendingTargetsAndOpenLegatoHaveDifferentReachabilityFromFrettedSlides() throws {
        let down = try FretPosition(string:3,fret:7)
        #expect(throws:LessonAdaptationError.unplayable) { try LessonFingeringResolver.resolve([down],sourceTuning:.standard,tuning:.standard,shift:0,maximumFret:19,region:FretRegion(firstFret:7,windowFrets:5),linkedFretOffset:-2) }
        #expect(try LessonFingeringResolver.resolve([down],sourceTuning:.standard,tuning:.standard,shift:0,maximumFret:19,region:FretRegion(firstFret:5,windowFrets:5),linkedFretOffset:-2) == [down])
        let b = try FretPosition(string:3,fret:4), region = try FretRegion(firstFret:0,windowFrets:3)
        #expect(try LessonFingeringResolver.resolve([b],sourceTuning:.standard,tuning:.standard,shift:0,maximumFret:19,region:region,linkedFretOffset:2) == [FretPosition(string:2,fret:0)])
        #expect(throws:LessonAdaptationError.unplayable) { try LessonFingeringResolver.resolve([b],sourceTuning:.standard,tuning:.standard,shift:0,maximumFret:19,region:region,minimumFret:1,linkedFretOffset:2) }
    }
    @Test func dropBassAdaptationMovesBothFrettedEndpointsTogether() throws {
        let source = try FretPosition(string: 6, fret: 5)
        for (index, tuning) in TuningProfile.presets.enumerated() {
            let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
            let positions = try LessonFingeringResolver.resolve([source], sourceTuning: .standard, tuning: tuning,
                shift: shift, maximumFret: 19, region: nil, minimumFret: 1, linkedFretOffset: 2)
            let base = try #require(positions.first), target = try FretPosition(string: base.string, fret: base.fret + 2)
            #expect(base.string == 6 && base.fret == (index.isMultiple(of: 2) ? 5 : 7))
            #expect(try tuning.pitch(at: base).midi == 45 + shift)
            #expect(try tuning.pitch(at: target).midi == 47 + shift)
        }
    }

}
