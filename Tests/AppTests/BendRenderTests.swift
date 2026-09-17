import AppKit
import SwiftUI
import Testing
import Domain
@testable import PersonalGuitarCoach

@MainActor struct BendRenderTests {
    @Test func renderBendCurveWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_BEND_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        let bend = try PitchBend(semitones: 2, riseStartTick: 480, riseEndTick: 960, releaseStartTick: 1920, releaseEndTick: 2400)
        let event = try MusicalEvent(id: "bend", startTick: 0, durationTicks: 2880, kind: .note, positions: [FretPosition(string: 3, fret: 9)], bend: bend)
        let frames = try (0...150).map { index -> SustainFrame in
            let time = Double(index) * 0.02
            let cents = bend.cents(at: time * 960, durationTicks: 2880) + (time > 1 && time < 2 ? 40 : 8) + 3 * sin(time * 5)
            let unknown = (1.4...1.54).contains(time)
            return try SustainFrame(id: UInt64(index + 1), normalizedTime: 100 + time,
                state: unknown ? .uncertain : .pitched, frequency: unknown ? nil : 330 * pow(2, cents / 1200))
        }
        for language in ["en", "uk"] {
            let resources = root.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            var strings: [String: String] = [:]
            for (key, entry) in entries {
                if let locales = entry["localizations"] as? [String: [String: Any]], let unit = locales[language]?["stringUnit"] as? [String: String] { strings[key] = unit["value"] }
            }
            try PropertyListSerialization.data(fromPropertyList: strings, format: .xml, options: 0).write(to: resources.appendingPathComponent("Localizable.strings"))
            let bundle = try #require(Bundle(url: resources))
            for dark in [false, true] {
                let view = BendCurveView(event: event, frames: frames, normalizedStart: 100, baseFrequency: 330, localizationBundle: bundle)
                    .padding(20).frame(width: 600).background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light).environment(\.locale, Locale(identifier: language))
                let renderer = ImageRenderer(content: view); renderer.scale = 2
                let image = try #require(renderer.nsImage), tiff = try #require(image.tiffRepresentation), bitmap = try #require(NSBitmapImageRep(data: tiff))
                try #require(bitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent("bend-\(language)-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
