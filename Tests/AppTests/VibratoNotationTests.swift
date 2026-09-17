import Foundation
import Testing
import Domain
@testable import PersonalGuitarCoach

struct VibratoNotationTests {
    @Test func modulationSpanCrossesBarsWithoutInventingNotesAndSpeaksInSelectedLanguage() throws {
        let vibrato = try PitchVibrato(extentCents: 80, startTick: 960, endTick: 4800, periodTicks: 480)
        let event = try MusicalEvent(id: "v", startTick: 0, durationTicks: 5760, kind: .note, positions: [FretPosition(string: 3, fret: 9)], vibrato: vibrato)
        let timeline = try TimelineModel(exercise: Exercise(id: "v", events: [event]), instrument: .cStandard)
        #expect(timeline.events.count == 1)
        let first = try #require(timeline.segments(in: 0).first), second = try #require(timeline.segments(in: 1).first)
        #expect(VibratoPresentation.span(first) == 960..<3840 && VibratoPresentation.span(second) == 3840..<4800)
        let staff = StaffModel(timeline: timeline, key: .neutral)
        let symbols = try staff.symbols(in: 0) + staff.symbols(in: 1)
        #expect(symbols.allSatisfy { $0.pitch?.soundingMIDI == 60 && $0.eventID == "v" })
        #expect(symbols.last?.fragment.tieFromPrevious == true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        for language in ["en", "uk"] {
            let spoken = VibratoPresentation.spoken(vibrato, pulseTicks: 960, locale: Locale(identifier: language)) { key in
                let locales = strings[key]?["localizations"] as? [String: [String: Any]]
                let unit = locales?[language]?["stringUnit"] as? [String: String]
                return unit?["value"] ?? key
            }
            #expect(spoken.contains(language == "en" ? "2 cycles per beat" : "2 коливань за долю"))
            #expect(spoken.contains(language == "en" ? "beat 2 to beat 6" : "долі 2 до долі 6"))
            #expect(spoken.contains("80"))
        }
    }
}
