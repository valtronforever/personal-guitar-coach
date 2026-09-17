import Foundation
import Testing
@testable import Domain

struct PitchTransitionTests {
    @Test func techniqueDirectionEndpointsAndMusicalBoundsAreValidated() throws {
        let start = try FretPosition(string:3,fret:5)
        let slide = try PitchTransition(kind:.slide,semitones:2,startTick:960,travelTicks:960)
        #expect(try slide.targetPosition(from:start) == FretPosition(string:3,fret:7))
        try slide.validate(durationTicks:2880,position:start)
        let pull = try PitchTransition(kind:.pullOff,semitones:-2,startTick:960)
        #expect(try pull.targetPosition(from:FretPosition(string:1,fret:2)) == FretPosition(string:1,fret:0))
        #expect(throws:MusicError.invalidEvent) { try PitchTransition(kind:.hammerOn,semitones:-2,startTick:960) }
        #expect(throws:MusicError.invalidEvent) { try PitchTransition(kind:.pullOff,semitones:2,startTick:960) }
        #expect(throws:MusicError.invalidEvent) { try PitchTransition(kind:.slide,semitones:2,startTick:960) }
        #expect(throws:MusicError.invalidEvent) { try PitchTransition(kind:.hammerOn,semitones:2,startTick:960,travelTicks:1) }
        #expect(throws:MusicError.invalidEvent) { try PitchTransition(kind:.slide,semitones:0,startTick:960,travelTicks:960) }
        #expect(throws:MusicError.invalidEvent) { try PitchTransition(kind:.slide,semitones:Int.min,startTick:960,travelTicks:960) }
        #expect(throws:MusicError.invalidEvent) { try PitchTransition(kind:.slide,semitones:2,startTick:Int64.max,travelTicks:1) }
        #expect(throws:MusicError.invalidTime) { try slide.validate(durationTicks:1920,position:start) }
        #expect(throws:MusicError.invalidFret) { try pull.validate(durationTicks:1920,position:FretPosition(string:1,fret:1)) }
        #expect(throws:MusicError.invalidFret) { try slide.validate(durationTicks:2880,position:FretPosition(string:1,fret:24)) }
        for transition in [slide,pull,try PitchTransition(kind:.hammerOn,semitones:2,startTick:960)] {
            #expect(try JSONDecoder().decode(PitchTransition.self,from:JSONEncoder().encode(transition)) == transition)
        }
        #expect(!String(decoding:try JSONEncoder().encode(pull),as:UTF8.self).contains("travelTicks"))
    }
    @Test func referenceStepAndSlideHaveExactBoundaryPitchesAndIntegratedPhase() throws {
        let step = try PitchTransition(kind:.hammerOn,semitones:12,startTick:960)
        #expect(step.cents(at:959.99) == 0 && step.cents(at:960) == 1200)
        #expect(step.integratedMultiplier(to:1440,durationTicks:1920) == 1920)
        #expect(step.integratedMultiplier(to:3000,durationTicks:1920) == 2880)
        let down = try PitchTransition(kind:.pullOff,semitones:-12,startTick:960)
        #expect(down.cents(at:960) == -1200)
        #expect(down.integratedMultiplier(to:1440,durationTicks:1920) == 1200)
        for semitones in [-4,2,7] {
            let slide = try PitchTransition(kind:.slide,semitones:semitones,startTick:960,travelTicks:960)
            #expect(slide.cents(at:960) == 0 && slide.cents(at:1440) == Double(semitones*50))
            #expect(slide.cents(at:1920) == Double(semitones*100))
            // Independent midpoint integration of the frequency multiplier, including both plateaus.
            let count = 28800, width = 0.1
            let numerical = (0..<count).reduce(0.0) { sum,index in
                let tick = (Double(index)+0.5)*width
                let cents = tick < 960 ? 0 : tick < 1920 ? Double(semitones*100)*(tick-960)/960 : Double(semitones*100)
                return sum + pow(2,cents/1200)*width
            }
            #expect(abs(slide.integratedMultiplier(to:2880,durationTicks:2880)-numerical) < 1e-6)
            #expect(slide.integratedMultiplier(to:-1,durationTicks:2880) == 0)
        }
    }
    @Test func oneInitialAttackCarriesBothReachabilityEndpointsAndPreservesOldEncoding() throws {
        let transition = try PitchTransition(kind:.slide,semitones:2,startTick:960,travelTicks:960)
        let start = try FretPosition(string:6,fret:18)
        let note = try MusicalEvent(id:"slide",startTick:0,durationTicks:2880,kind:.note,positions:[start],pitchTransition:transition)
        #expect(note.techniquePositions == [start,try FretPosition(string:6,fret:20)])
        let exercise = try Exercise(id:"slide",events:[note])
        #expect(try exercise.resolvedEvents(instrument:.standard).first?.pitches == [Pitch(midi:58)])
        #expect(try JSONDecoder().decode(MusicalEvent.self,from:JSONEncoder().encode(note)) == note)
        let ordinary = try MusicalEvent(id:"plain",startTick:0,durationTicks:960,kind:.note,positions:[start])
        #expect(!String(decoding:try JSONEncoder().encode(ordinary),as:UTF8.self).contains("pitchTransition"))
        #expect(throws:MusicError.invalidEvent) { try MusicalEvent(id:"bad",startTick:0,durationTicks:2880,kind:.rest,pitchTransition:transition) }
        #expect(throws:MusicError.invalidEvent) { try MusicalEvent(id:"bad",startTick:0,durationTicks:2880,kind:.note,positions:[start],assessSustain:true,pitchTransition:transition) }
        let endpoint = try CalibrationEndpoint(uid:"geometry",channel:1,sampleRate:48000,bufferFrames:512,deviceLatencyFrames:0,streamLatencyFrames:0)
        let route = try CalibrationRoute(input:endpoint,output:endpoint,backendVersion:"fixture")
        #expect(throws:MusicError.invalidFret) { try PracticeConfiguration(exercise:exercise,instrument:InstrumentProfile(frets:.nineteen),bpm:60,route:route) }
        _ = try PracticeConfiguration(exercise:exercise,instrument:InstrumentProfile(frets:.twentyFour),bpm:60,route:route)
        let openSlide = try PitchTransition(kind:.slide,semitones:2,startTick:960,travelTicks:960)
        #expect(throws:MusicError.invalidFret) { try openSlide.validate(durationTicks:2880,position:FretPosition(string:1,fret:0)) }
    }

    @Test func capabilityBoundsUseTheExplicitPulseAndBothEndpointFrequencies() throws {
        for meter in TimeSignature.allCases {
            let half = meter.pulseTicks / 2
            let slide = try PitchTransition(kind: .slide, semitones: 1, startTick: half, travelTicks: half)
            #expect(PitchTransitionCapability.supports(transition: slide, durationTicks: half * 3, bpm: 60, frequency: 220, pulseTicks: meter.pulseTicks))
            #expect(!PitchTransitionCapability.supports(transition: slide, durationTicks: half * 3, bpm: 61, frequency: 220, pulseTicks: meter.pulseTicks))
            let tooWide = try PitchTransition(kind: .slide, semitones: 2, startTick: half, travelTicks: half)
            #expect(!PitchTransitionCapability.supports(transition: tooWide, durationTicks: half * 3, bpm: 60, frequency: 220, pulseTicks: meter.pulseTicks))
        }
        let up = try PitchTransition(kind: .hammerOn, semitones: 2, startTick: 384)
        #expect(PitchTransitionCapability.supports(transition: up, durationTicks: 768, bpm: 60, frequency: 220, pulseTicks: 960))
        #expect(!PitchTransitionCapability.supports(transition: up, durationTicks: 767, bpm: 60, frequency: 220, pulseTicks: 960))
        #expect(!PitchTransitionCapability.supportsFrequencies(up, frequency: 195))
        let down = try PitchTransition(kind: .pullOff, semitones: -2, startTick: 960)
        #expect(!PitchTransitionCapability.supportsFrequencies(down, frequency: 196))
        let octave = try PitchTransition(kind: .hammerOn, semitones: 12, startTick: 960)
        #expect(!PitchTransitionCapability.supportsFrequencies(octave, frequency: 880))
        for bpm in [0.0, -1, Double.nan, Double.infinity] {
            #expect(!PitchTransitionCapability.supports(transition: up, durationTicks: 768, bpm: bpm, frequency: 220, pulseTicks: 960))
        }
    }

}
