import Foundation
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

struct StaffTests {
    private func note(_ id: String, _ tick: Int64, midi: Int, duration: Int64 = 960) throws -> MusicalEvent {
        // Use a custom first string so each fixture independently specifies sounding MIDI.
        try MusicalEvent(id: id, startTick: tick, durationTicks: duration, kind: .note, positions: [FretPosition(string: 6, fret: midi - 36)])
    }
    private var tuning: TuningProfile {
        get throws { try TuningProfile(id: "staff-test", name: "Staff test", strings: [
            TunedString(number: 1, openPitch: Pitch(midi: 64)), TunedString(number: 2, openPitch: Pitch(midi: 59)),
            TunedString(number: 3, openPitch: Pitch(midi: 55)), TunedString(number: 4, openPitch: Pitch(midi: 50)),
            TunedString(number: 5, openPitch: Pitch(midi: 45)), TunedString(number: 6, openPitch: Pitch(midi: 36))]) }
    }
    @Test func writtenOctaveAndLedgerLinesNeverChangeSoundingPitch() throws {
        let sounding = try Pitch(midi: 40)
        let pitch = StaffPitch(sounding: sounding, key: .neutral)
        #expect(pitch.soundingMIDI == 40 && pitch.writtenMIDI == 52 && pitch.name == "E3")
        #expect(pitch.step == 23 && StaffModel.ledgerSteps(for: pitch.step) == [28, 26, 24])
        let frequency = try sounding.frequency()
        #expect(sounding.midi == 40 && abs(frequency - 82.4068892282) < 0.0001)
        #expect(StaffModel.ledgerSteps(for: 38).isEmpty)
        #expect(StaffModel.ledgerSteps(for: 43) == [40, 42])
        #expect(StaffPitch(sounding: try Pitch(midi: 58), key: .fMajor).name == "B♭4")
        #expect(StaffPitch(sounding: try Pitch(midi: 58), key: .neutral).name == "A♯4")
    }
    @Test func keyAccidentalsPersistAtSameOctaveAndResetAtBarline() throws {
        let events = try [note("fSharp",0,midi:54), note("fNatural",960,midi:53), note("sameNatural",1920,midi:53),
                          note("sharpAgain",2880,midi:54), note("nextBar",3840,midi:54), MusicalEvent(id:"r1",startTick:4800,durationTicks:960,kind:.rest), MusicalEvent(id:"r2",startTick:5760,durationTicks:1920,kind:.rest)]
        let timeline = try TimelineModel(exercise: Exercise(id: "accidentals", events: events), instrument: tuning)
        let staff = StaffModel(timeline: timeline, key: .gMajor)
        #expect(try staff.symbols(in: 0).map(\.accidental) == [nil,"♮",nil,"♯"])
        #expect(try staff.symbols(in: 1).first?.accidental == nil)
        let plain = StaffModel(timeline: timeline, key: .neutral)
        #expect(try plain.symbols(in: 0).map(\.accidental) == ["♯","♮",nil,"♯"])
        #expect(try plain.symbols(in: 1).first?.accidental == "♯")
        #expect(try staff.symbols(in: 0).map { $0.resolved.pitches[0].midi } == [54,53,53,54])
    }
    @Test func accidentalMemoryIsOctaveSpecificAndFlatKeyCancelsCorrectly() throws {
        let upper = try MusicalEvent(id:"upper",startTick:1920,durationTicks:960,kind:.note,positions:[FretPosition(string:1,fret:2)])
        let timeline = try TimelineModel(exercise:Exercise(id:"octaves",events:[note("sharp",0,midi:54),note("natural",960,midi:53),upper,MusicalEvent(id:"rest",startTick:2880,durationTicks:960,kind:.rest)]),instrument:tuning)
        let symbols = try StaffModel(timeline:timeline,key:.gMajor).symbols(in:0)
        #expect(symbols.map(\.accidental) == [nil,"♮",nil,nil])
        let flats = try TimelineModel(exercise:Exercise(id:"flats",events:[note("flat",0,midi:58),note("natural",960,midi:59),note("flatAgain",1920,midi:58),MusicalEvent(id:"rest",startTick:2880,durationTicks:960,kind:.rest)]),instrument:tuning)
        #expect(try StaffModel(timeline:flats,key:.fMajor).symbols(in:0).map(\.accidental) == [nil,"♮","♭",nil])
    }
    @Test func beamsStayWithinBeatsAndNeverCrossRests() throws {
        let events = try [note("a",0,midi:48,duration:480),note("b",480,midi:50,duration:480),
            note("c",960,midi:52,duration:240),note("d",1200,midi:53,duration:240),
            MusicalEvent(id:"rest",startTick:1440,durationTicks:240,kind:.rest),note("e",1680,midi:55,duration:240), MusicalEvent(id:"ending-rest",startTick:1920,durationTicks:1920,kind:.rest)]
        let timeline = try TimelineModel(exercise: Exercise(id:"beams",events:events),instrument:tuning)
        let model = StaffModel(timeline:timeline,key:.neutral), symbols = try model.symbols(in:0)
        #expect(model.beams(symbols).map(\.ids) == [["a","b"],["c","d"]])
        #expect(model.beams(symbols).map(\.flags) == [1,2])
        #expect(symbols.first { $0.id == "rest" }?.pitch == nil)
        #expect(symbols.map { $0.resolved.event.durationTicks } == [480,480,240,240,240,240,1920])
    }
    @Test func unsupportedMusicFailsExplicitlyInsteadOfInventingNotation() throws {
        let partial = try TimelineModel(exercise: Exercise(id:"partial",events:[note("one",0,midi:40)]),instrument:tuning)
        #expect(throws: StaffLimitation.partialBar) { try StaffModel(timeline:partial,key:.neutral).symbols(in:0) }
        let across = try TimelineModel(exercise: Exercise(id:"tie",events:[note("long",0,midi:40,duration:4320)]),instrument:tuning)
        #expect(throws: StaffLimitation.crossBar) { try StaffModel(timeline:across,key:.neutral).symbols(in:0) }
        let dotted = try TimelineModel(exercise: Exercise(id:"dotted",events:[note("dot",0,midi:40,duration:1440)]),instrument:tuning)
        #expect(throws: StaffLimitation.duration) { try StaffModel(timeline:dotted,key:.neutral).symbols(in:0) }
        let gap = try TimelineModel(exercise: Exercise(id:"gap",events:[note("late",960,midi:40)]),instrument:tuning)
        #expect(throws: StaffLimitation.gaps) { try StaffModel(timeline:gap,key:.neutral).symbols(in:0) }
        let chord = try MusicalEvent(id:"chord",startTick:0,durationTicks:960,kind:.note,positions:[FretPosition(string:6,fret:0),FretPosition(string:5,fret:0)])
        let chords = try TimelineModel(exercise: Exercise(id:"chords",events:[chord],assessmentMode:.displayOnly),instrument:tuning)
        #expect(throws: StaffLimitation.polyphony) { try StaffModel(timeline:chords,key:.neutral).symbols(in:0) }
    }
    @MainActor @Test func allCoursePracticeBarsShareIDsPitchesAndSelectionWithTAB() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        #expect(library.lessons.count == 12)
        for lesson in library.lessons {
            let selection = LessonSelection(lesson:lesson)
            for exercise in lesson.manifest.exercises where exercise.assessmentMode == .monophonic {
                let timeline = try TimelineModel(exercise:exercise,instrument:.dropD)
                let staff = StaffModel(timeline:timeline,key:.neutral)
                let symbols = try (0..<timeline.barCount).flatMap { try staff.symbols(in:$0) }
                #expect(symbols.map(\.id) == timeline.events.map(\.id))
                if exercise.id == "c-major-practice" {
                    #expect(symbols.compactMap(\.pitch).map(\.name) == ["C4","D4","E4","F4","G4","A4","B4","C5","B4","A4","G4","F4","E4","D4","C4"])
                    #expect(symbols.allSatisfy { $0.accidental == nil && $0.resolved.event.durationTicks == 960 })
                }
                if exercise.id == "ab-major-c-standard-practice" {
                    #expect(symbols.compactMap(\.pitch).map(\.name) == ["A♭3","B♭3","C4","D♭4","E♭4","F4","G4","A♭4","G4","F4","E♭4","D♭4","C4","B♭3","A♭3"])
                    #expect(try staff.symbols(in: 0).map(\.accidental) == ["♭", "♭", nil, "♭"])
                }
                #expect(symbols.compactMap(\.pitch).map(\.writtenMIDI) == timeline.events.flatMap(\.pitches).map { $0.midi + 12 })
                for symbol in symbols {
                    selection.selectEvent(symbol.id,exerciseID:exercise.id,extending:false)
                    #expect(selection.selectedIDs == [symbol.id])
                    #expect(selection.exercise?.id == exercise.id)
                }
            }
        }
    }
}
