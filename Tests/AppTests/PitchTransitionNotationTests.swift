import Foundation
import Testing
import Domain
@testable import PersonalGuitarCoach

struct PitchTransitionNotationTests {
    @Test func targetHeadsAndTabFretsHaveTheirOwnTimeWithoutNewAttacksOrFalseTies() throws {
        for kind in PitchTransition.Kind.allCases {
            let transition = try PitchTransition(kind: kind, semitones: kind == .pullOff ? -2 : 2, startTick: 960, travelTicks: kind == .slide ? 960 : 0)
            let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: 2880, kind: .note,
                positions: [FretPosition(string: 3, fret: 7)], accented: true, pickStroke: .down, pitchTransition: transition)
            let timeline = try TimelineModel(exercise: Exercise(id: "motion", events: [event]), instrument: .standard)
            let segment = try #require(timeline.segments(in: 0).first)
            let markers = PitchTransitionPresentation.markers(segment)
            #expect(markers.map(\.tick) == [0, kind == .slide ? 1920 : 960])
            #expect(markers.map(\.position.fret) == [7, kind == .pullOff ? 5 : 9])
            #expect(markers.map(\.durationTicks) == (kind == .slide ? [1920, 960] : [960, 1920]))
            let symbols = try StaffModel(timeline: timeline, key: .neutral).symbols(in: 0)
            #expect(symbols.map(\.startTick) == markers.map(\.tick))
            #expect(symbols.map(\.pitch?.soundingMIDI) == [62, kind == .pullOff ? 60 : 64])
            #expect(symbols.map(\.accentedAttack) == [true, false])
            #expect(symbols.allSatisfy { !$0.fragment.tieFromPrevious && !$0.fragment.tieToNext })
            #expect(symbols.map(\.eventID) == ["motion", "motion"] && timeline.events.count == 1)
            #expect(symbols.last?.hintKey == "staff.transitionTarget")
        }
    }
    @Test func targetAtBarlineChangesPitchInsteadOfTyingTwoDifferentNotes() throws {
        let transition = try PitchTransition(kind: .hammerOn, semitones: 1, startTick: 3840)
        let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: 5760, kind: .note,
            positions: [FretPosition(string: 2, fret: 1)], pitchTransition: transition)
        let timeline = try TimelineModel(exercise: Exercise(id: "motion", events: [event]), instrument: .standard)
        let staff = StaffModel(timeline: timeline, key: .neutral)
        let first = try #require(staff.symbols(in: 0).first), second = try #require(staff.symbols(in: 1).first)
        #expect(first.pitch?.soundingMIDI == 60 && !first.fragment.tieToNext)
        #expect(second.pitch?.soundingMIDI == 61 && second.accidental == "♯" && !second.fragment.tieFromPrevious)
        #expect(second.fragment.isTechniqueTarget && second.fragment.duration.ticks == 1920)
        let segment = try #require(timeline.segments(in: 1).first)
        let marker = try #require(PitchTransitionPresentation.markers(segment).first)
        #expect(marker.tick == 3840 && marker.position.fret == 2 && !marker.continuation)
        #expect(segment.displayPositions == [try FretPosition(string: 2, fret: 2)] && segment.displayPitches.map(\.midi) == [61])
    }
    @Test func unrepresentableTargetTimingIsExplicitAndTripletChangeRemainsOneEvent() throws {
        let transition = try PitchTransition(kind: .hammerOn, semitones: 2, startTick: 333)
        let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: 1920, kind: .note,
            positions: [FretPosition(string: 3, fret: 5)], pitchTransition: transition)
        let timeline = try TimelineModel(exercise: Exercise(id: "motion", events: [event]), instrument: .standard)
        #expect(throws: StaffLimitation.duration) { try StaffModel(timeline: timeline, key: .neutral).symbols(in: 0) }
        let tripletNote = try MusicalEvent(id: "legato", startTick: 0, durationTicks: 640, kind: .note,
            positions: [FretPosition(string: 3, fret: 5)], pitchTransition: PitchTransition(kind: .hammerOn, semitones: 2, startTick: 320))
        let rest = try MusicalEvent(id: "rest", startTick: 640, durationTicks: 320, kind: .rest)
        let triplet = try TimelineModel(exercise: Exercise(id: "triplet", events: [tripletNote, rest], triplets: [TripletGroup(id: "t", eventIDs: ["legato", "rest"])]), instrument: .standard)
        let symbols = try StaffModel(timeline: triplet, key: .neutral).symbols(in: 0)
        #expect(symbols.map(\.startTick) == [0, 320, 640])
        #expect(symbols.map { $0.fragment.duration.baseTicks } == [480, 480, 480])
        #expect(symbols.map(\.eventID) == ["legato", "legato", "rest"])
        #expect(symbols.allSatisfy { $0.fragment.tripletID == "t" && !$0.fragment.tieFromPrevious && !$0.fragment.tieToNext })
    }
    @Test func spokenTargetsUseTheSuppliedLanguageAndSignedDirection() throws {
        let event = try MusicalEvent(id: "motion", startTick: 0, durationTicks: 2880, kind: .note,
            positions: [FretPosition(string: 3, fret: 5)], pitchTransition: PitchTransition(kind: .slide, semitones: 2, startTick: 960, travelTicks: 960))
        let timeline = try TimelineModel(exercise: Exercise(id: "spoken", events: [event]), instrument: .standard)
        let resolved = try #require(timeline.events.first)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        for language in ["en", "uk"] {
            func localized(_ key: String) -> String {
                let locales = entries[key]?["localizations"] as? [String: [String: Any]]
                let unit = locales?[language]?["stringUnit"] as? [String: String]
                return unit?["value"] ?? key
            }
            let spoken = PitchTransitionPresentation.spoken(event: resolved, pulseTicks: 960, tuning: .standard,
                locale: Locale(identifier: language), localized: localized)
            #expect(spoken.hasPrefix(language == "en" ? "Slide." : "Слайд."))
            #expect(spoken.contains(language == "en" ? "beat 2" : "долі 2"))
            #expect(spoken.contains(language == "en" ? "beat 3" : "долі 3"))
            #expect(spoken.contains(language == "en" ? "fret 7, D4" : "лад 7, D4"))
        }
    }

}
