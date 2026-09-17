import Foundation
import Testing
import Domain
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct HarmonicPresentationTests {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    @Test func lessonSelectionAndPreparedPracticeCarryTouchRolesInsteadOfOrdinaryFretLabels() throws {
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        let source = try #require(report.lessons.first { $0.id == "harmonics" })
        let instrument = InstrumentProfile(tuning: .cStandard, frets: .nineteen)
        let selection = LessonSelection(lesson: source, tuning: .cStandard)
        selection.selectStep("artificial-octave"); selection.updateInstrument(instrument)
        let board = selection.fretboard(instrument: instrument)
        let base = try FretPosition(string: 3, fret: 5), touch = try FretPosition(string: 3, fret: 17)
        #expect(board.hasHarmonics && board.hasTouch(at: touch) && !board.hasTouch(at: base))
        #expect(board.expected == [base,touch])
        #expect(board.displayName(at: base) == "A♭3" && board.displayName(at: touch) == "A♭4")
        selection.selectStep("natural-partials")
        let natural = selection.fretboard(instrument: instrument), node = try FretPosition(string: 4, fret: 7)
        #expect(natural.hasTouch(at: node) && natural.displayName(at: node) == "F4")
        #expect(natural.pitch(at: node)?.midi == 53) // The ordinary board map remains F3; selected harmonic sound is F4.
        let snapshot = try source.resolveActivity(id: "artificial-region", instrument: instrument)
        let request = try #require(PracticeRequest(lesson: source, snapshot: snapshot, entryID: "artificial-region"))
        let model = PracticeModel(audio: AudioSessionStore(repository: nil), calibration: CalibrationStore(repository: nil))
        model.configure(request)
        #expect(model.expectedPositions == [base,touch])
        #expect(model.expectedFretTargets(in: .cStandard).map(\.role) == [.harmonicBase,.harmonicTouch])
        #expect(model.expectedFretTargets(in: .cStandard).map(\.pitch.midi) == [56,68])
    }
    @Test func tabStaffAndBilingualSpokenInstructionsShareSoundingTargetsAndPhysicalNodes() throws {
        let events = try [
            MusicalEvent(id: "natural", startTick: 0, durationTicks: 1920, kind: .note, positions: [FretPosition(string: 3, fret: 7)], harmonic: HarmonicNote(kind: .natural, partial: 3)),
            MusicalEvent(id: "artificial", startTick: 1920, durationTicks: 1920, kind: .note, positions: [FretPosition(string: 3, fret: 5)], harmonic: HarmonicNote(kind: .artificial))]
        let timeline = try TimelineModel(exercise: Exercise(id: "notation", events: events), instrument: .cStandard)
        #expect(timeline.events.flatMap(\.pitches).map(\.midi) == [70,68])
        #expect(timeline.segments(in: 0).flatMap(\.displayPitches).map(\.midi) == [70,68])
        let staff = try StaffModel(timeline: timeline, key: .neutral).symbols(in: 0)
        #expect(staff.compactMap(\.pitch).count == 2 && staff.map(\.eventID) == ["natural","artificial"])
        #expect(staff.map { $0.resolved.pitches[0].midi } == [70,68])
        let data = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let entries = try #require(data["strings"] as? [String: [String: Any]])
        for language in ["en","uk"] {
            func localized(_ key: String) -> String {
                let locales = entries[key]?["localizations"] as? [String: [String: Any]]
                let unit = locales?[language]?["stringUnit"] as? [String: String]
                return unit?["value"] ?? key
            }
            let natural = HarmonicPresentation.spoken(event: events[0], tuning: .cStandard, locale: Locale(identifier: language), localized: localized)
            let artificial = HarmonicPresentation.spoken(event: events[1], tuning: .cStandard, locale: Locale(identifier: language), localized: localized)
            #expect(natural.contains("7") && natural.contains("B♭4"))
            #expect(artificial.contains("5") && artificial.contains("17") && artificial.contains("A♭4"))
            #expect(!natural.contains("%@") && !artificial.contains("%lld"))
        }
    }
}
