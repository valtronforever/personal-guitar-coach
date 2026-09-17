import Foundation
import Domain

enum HeldVoicePresentation {
    static func fret(_ position: FretPosition, event: MusicalEvent, continuation: Bool) -> String {
        event.heldStrings.contains(position.string) || continuation ? "(\(position.fret))" : String(position.fret)
    }

    static func spoken(notes: String, event: MusicalEvent, continuation: Bool, locale: Locale, localized: (String) -> String) -> String {
        let held = continuation ? event.positions.map(\.string).sorted() : event.heldStrings
        guard !held.isEmpty else { return notes }
        return String(format: localized("heldVoice.spoken %@ %@"), locale: locale, notes, held.map(String.init).joined(separator: ", "))
    }
}
