import Foundation
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

@MainActor struct HeldVoicePresentationTests {
    @Test func tablatureDistinguishesFreshAndHeldFretsAndStaffDoesNotInventReattacks() throws {
        let bass = try FretPosition(string: 5,fret: 3), melody = try FretPosition(string: 2,fret: 5)
        let first = try MusicalEvent(id: "first",startTick: 0,durationTicks: 960,kind: .note,positions: [bass,melody])
        let held = try MusicalEvent(id: "next",startTick: 960,durationTicks: 2880,kind: .note,positions: [bass,melody],heldStrings: [5])
        #expect(HeldVoicePresentation.fret(bass,event: held,continuation: false) == "(3)")
        #expect(HeldVoicePresentation.fret(melody,event: held,continuation: false) == "5")
        #expect(HeldVoicePresentation.fret(melody,event: held,continuation: true) == "(5)")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String:Any])
        let strings = try #require(catalog["strings"] as? [String:[String:Any]])
        for language in ["en","uk"] {
            let locales = try #require(strings["heldVoice.spoken %@ %@"]?["localizations"] as? [String:[String:Any]])
            let unit = try #require(locales[language]?["stringUnit"] as? [String:String]), format = try #require(unit["value"])
            let spoken = HeldVoicePresentation.spoken(notes: "C3; E4",event: held,continuation: false,locale: Locale(identifier: language),localized: { _ in format })
            #expect(spoken.contains("C3; E4") && spoken.contains("5") && spoken.contains(language == "en" ? "without a new attack" : "без нової атаки"))
        }
        let model = try TimelineModel(exercise: Exercise(id: "held",events: [first,held],assessmentMode: .displayOnly),instrument: .standard)
        #expect(throws: StaffLimitation.polyphony) { try StaffModel(timeline: model,key: .neutral).symbols(in: 0) }
        #expect(model.segments(in: 0).last?.displayPositions == [bass,melody])
    }
}
