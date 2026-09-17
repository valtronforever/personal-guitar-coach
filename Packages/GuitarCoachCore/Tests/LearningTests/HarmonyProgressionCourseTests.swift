import Foundation
import Testing
import Domain
@testable import Learning

struct HarmonyProgressionCourseTests {
    private func lesson(_ id:String) throws -> LoadedLesson {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return try #require(report.lessons.first { $0.id == id })
    }
    private let shifts = [0,0,-2,-2,-4,-4,-5,-5]

    @Test func seventhQualityAndMovedRootKeepFourIndependentVoicesAndCorrectSymbols() throws {
        let source = try lesson("seventh-chords")
        let examples:[(String,[Int],[Int],String)] = [
            ("major-seventh",[48,55,59,64],[3,5,4,5],"maj7"),
            ("dominant-seventh",[48,55,58,64],[3,5,3,5],"7"),
            ("minor-seventh",[48,55,58,63],[3,5,3,4],"m7"),
            ("moved-dominant",[50,57,60,66],[5,7,5,7],"7")
        ]
        #expect(source.manifest.practiceEntries.count == 4)
        for (index,tuning) in TuningProfile.presets.enumerated() { for fretCount in GuitarFretCount.allCases {
            for (name,pitches,frets,suffix) in examples { for mode in ["shape","notes"] {
                let aid = name+"-"+mode
                let resolved = try source.resolveActivity(id:aid,instrument:InstrumentProfile(tuning:tuning,frets:fretCount))
                let exercise = try #require(resolved.exercises.first)
                let expected = pitches.map { $0+shifts[index] }
                #expect(try exercise.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == (mode == "shape" ? Array(expected.reversed()) : expected))
                let rootNames = name == "moved-dominant" ? ["D","D","C","C","B♭","B♭","A","A"] : ["C","C","B♭","B♭","A♭","A♭","G","G"]
                #expect(resolved.english.activities[aid]?.title.hasPrefix(rootNames[index]+suffix+" —") == true)
                #expect(resolved.ukrainian.activities[aid]?.title.hasPrefix(rootNames[index]+suffix+" —") == true)
                if mode == "shape" {
                    let shape = try #require(resolved.fingerings.first?.fingering)
                    #expect(shape.positions.map(\.string) == [2,3,4,5] && shape.positions.map(\.fret) == Array(frets.reversed()))
                    #expect(shape.mutedStrings == [1,6] && !shape.fingerNumbers.isEmpty)
                    #expect(throws:MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument:tuning,bpm:60) }
                } else {
                    #expect(exercise.events.dropLast().map(\.startTick) == [0,960,1920,2880])
                    #expect(exercise.events.dropLast().flatMap(\.positions).map(\.fret) == frets)
                    #expect(exercise.events.last?.durationTicks == 3840 && exercise.durationTicks == 7680)
                    for bpm in [40.0,50.0,90.0] { try exercise.validateForPractice(instrument:tuning,bpm:bpm) }
                }
            } }
        } }
    }

    @Test func functionalRootsRemainIndependentOfInvertedBassAndReferencesStayUnscored() throws {
        let source = try lesson("harmonic-functions")
        #expect(source.manifest.practiceEntries.isEmpty)
        let shapes:[String:[Int]] = ["tonic-shape":[60,64,67],"subdominant-shape":[57,60,65],"dominant-shape":[59,62,67],"relative-minor-shape":[57,60,64]]
        let rootNames:[String:[String]] = ["tonic-shape":["C","C","B♭","B♭","A♭","A♭","G","G"],"subdominant-shape":["F","F","E♭","E♭","D♭","D♭","C","C"],"dominant-shape":["G","G","F","F","E♭","E♭","D","D"],"relative-minor-shape":["A","A","G","G","F","F","E","E"]]
        let degrees = ["tonic-shape":"I","subdominant-shape":"IV","dominant-shape":"V","relative-minor-shape":"vi"]
        let references = ["return-to-tonic":[60,64,67,57,60,65,59,62,67,60,64,67],"minor-detour":[60,64,67,57,60,64,57,60,65,59,62,67]]
        for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            for activity in source.manifest.activities {
                let resolved = try source.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets))
                let ex = try #require(resolved.exercises.first)
                let expected:[Int]
                if let shape = shapes[activity.id] {
                    expected = Array(shape.reversed())
                    let prefix = degrees[activity.id]!+" — "+rootNames[activity.id]![index]
                    #expect(resolved.english.activities[activity.id]?.title.hasPrefix(prefix) == true)
                    #expect(resolved.ukrainian.activities[activity.id]?.title.hasPrefix(prefix) == true)
                    #expect(ex.events.count == 1 && ex.durationTicks == 3840)
                } else {
                    expected = try #require(references[activity.id])
                    #expect(ex.events.map(\.startTick) == [0,3840,7680,11520] && ex.durationTicks == 15360)
                    #expect(ex.events.allSatisfy { $0.durationTicks == 3840 && $0.positions.count == 3 })
                }
                #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == expected.map { $0+shifts[index] })
                #expect(ex.assessmentMode == .displayOnly)
                #expect(throws:MusicError.displayOnlyExercise) { try ex.validateForPractice(instrument:tuning,bpm:60) }
            }
        } }
    }

    @Test func connectedVoiceLinesRetainCommonTonesAndExplicitThreeBeatSustain() throws {
        let source = try lesson("voice-leading")
        let shapes = ["tonic-shape":[60,64,67],"wide-four-shape":[65,69,72],"wide-five-shape":[67,71,74],"close-four-shape":[60,65,69],"close-five-shape":[59,62,67]]
        let sequences = ["wide-reference":[60,64,67,65,69,72,67,71,74,60,64,67],"connected-reference":[60,64,67,60,65,69,59,62,67,60,64,67],"connected-arpeggio":[60,64,67,60,65,69,59,62,67,60,64,67],"low-line":[60,60,59,60],"middle-line":[64,65,62,64],"high-line":[67,69,67,67]]
        #expect(source.manifest.practiceEntries.map(\.id) == ["low-line","middle-line","high-line","connected-arpeggio"])
        for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            for activity in source.manifest.activities {
                let ex = try #require(source.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises.first)
                let expected = shapes[activity.id].map { Array($0.reversed()) } ?? sequences[activity.id]!
                #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == expected.map { $0+shifts[index] })
                if shapes[activity.id] != nil || activity.id.hasSuffix("reference") {
                    #expect(ex.assessmentMode == .displayOnly)
                    #expect(throws:MusicError.displayOnlyExercise) { try ex.validateForPractice(instrument:tuning,bpm:60) }
                } else {
                    let notes = ex.events.filter { $0.kind == .note }, rests = ex.events.filter { $0.kind == .rest }
                    #expect(ex.durationTicks == 15360 && rests.map(\.startTick) == [2880,6720,10560,14400])
                    #expect(rests.allSatisfy { $0.durationTicks == 960 })
                    if activity.id.hasSuffix("line") {
                        #expect(notes.map(\.startTick) == [0,3840,7680,11520])
                        #expect(notes.allSatisfy { $0.durationTicks == 2880 && $0.assessSustain })
                        let string = activity.id == "low-line" ? 3 : activity.id == "middle-line" ? 2 : 1
                        #expect(notes.flatMap(\.positions).allSatisfy { $0.string == string })
                    } else {
                        #expect(notes.map(\.startTick) == [0,960,1920,3840,4800,5760,7680,8640,9600,11520,12480,13440])
                        #expect(notes.allSatisfy { $0.durationTicks == 960 && !$0.assessSustain })
                    }
                    for bpm in [40.0,60.0,90.0] { try ex.validateForPractice(instrument:tuning,bpm:bpm) }
                }
            }
        } }
    }

    @Test func changingArpeggiosKeepTheirChordToneOrderRhythmsRestsAndFinalRoot() throws {
        let source = try lesson("chord-change-arpeggios")
        let pitches = [
            "hear-the-change":[60,64,67,53,57,60,55,59,62,60,64,67],
            "four-chord-flow":[60,64,67,72,67,64,60,64,57,60,64,69,64,60,57,60,53,57,60,65,60,57,53,57,55,59,62,67,62,59,55,59],
            "changing-chord-study":[60,64,67,72,69,64,60,57,53,57,60,65,60,57,59,62,67,60,64,67,72,67,64,60,64,53,57,60,55,59,62,59,67,64,60]
        ]
        let studyOnsets:[Int64] = [0,960,1920,2880,3840,4800,5760,6720,7680,8160,8640,9120,9600,10080,11520,12480,13440,15360,15840,16320,16800,17280,17760,18240,18720,19200,20160,21120,23040,24000,24960,25920,26880,27840,28800]
        #expect(source.manifest.practiceEntries.count == 3)
        for (index,tuning) in TuningProfile.presets.enumerated() { for frets in GuitarFretCount.allCases {
            for activity in source.manifest.activities {
                let ex = try #require(source.resolveActivity(id:activity.id,instrument:InstrumentProfile(tuning:tuning,frets:frets)).exercises.first)
                #expect(try ex.resolvedEvents(instrument:tuning).flatMap(\.pitches).map(\.midi) == pitches[activity.id]!.map { $0+shifts[index] })
                let notes = ex.events.filter { $0.kind == .note }, rests = ex.events.filter { $0.kind == .rest }
                #expect(ex.assessmentMode == .monophonic && notes.allSatisfy { $0.positions.count == 1 })
                switch activity.id {
                case "hear-the-change":
                    #expect(notes.map(\.startTick) == [0,960,1920,3840,4800,5760,7680,8640,9600,11520,12480,13440])
                    #expect(rests.map(\.startTick) == [2880,6720,10560,14400] && notes.allSatisfy { $0.durationTicks == 960 })
                case "four-chord-flow":
                    #expect(notes.map(\.startTick) == (0..<32).map { Int64($0)*480 })
                    #expect(rests.isEmpty && notes.allSatisfy { $0.durationTicks == 480 })
                case "changing-chord-study":
                    #expect(notes.map(\.startTick) == studyOnsets)
                    #expect(rests.map(\.startTick) == [10560,14400,22080])
                    #expect(notes.filter(\.assessSustain).map(\.startTick) == [28800])
                    #expect(notes.last?.durationTicks == 1920 && ex.durationTicks == 30720)
                    #expect(notes.filter { $0.durationTicks == 480 }.map(\.startTick) == [7680,8160,8640,9120,9600,10080,15360,15840,16320,16800,17280,17760,18240,18720])
                    #expect(notes.filter { $0.durationTicks != 480 && $0.startTick != 28800 }.allSatisfy { $0.durationTicks == 960 })
                default: Issue.record("Unexpected practice")
                }
                #expect(rests.allSatisfy { $0.durationTicks == 960 })
                let bars = activity.id == "changing-chord-study" ? 8 : 4
                #expect(notes.filter(\.accented).map(\.startTick) == (0..<bars).map { Int64($0)*3840 })
                if bars == 4 { #expect(ex.durationTicks == 15360 && notes.allSatisfy { !$0.assessSustain }) }
                for bpm in [40.0,60.0,90.0] { try ex.validateForPractice(instrument:tuning,bpm:bpm) }
            }
        } }
    }
}
