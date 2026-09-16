import AppKit
import SwiftUI
import Testing
import Audio
@testable import PersonalGuitarCoach

/// Opt-in offline layout review; does not capture audio or interact with the running app.
@MainActor struct InputLevelRenderTests {
    @Test func renderLocalizedMeterWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_INPUT_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf:
            repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        for language in ["en", "uk"] {
            let resources = root.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            var strings: [String: String] = [:]
            for (key, entry) in entries {
                if let locales = entry["localizations"] as? [String: [String: Any]],
                   let unit = locales[language]?["stringUnit"] as? [String: String] { strings[key] = unit["value"] }
            }
            try PropertyListSerialization.data(fromPropertyList: strings, format: .xml, options: 0)
                .write(to: resources.appendingPathComponent("Localizable.strings"))
            let bundle = try #require(Bundle(url: resources))
            for dark in [false, true] {
                let examples: [(String, Float)] = [("silent", 0), ("weak", 0.01), ("working", 0.2), ("high", 0.7), ("clipping", 1)]
                let view = VStack(alignment: .leading, spacing: 24) {
                    ForEach(examples, id: \.0) { example in
                        InputLevelMeter(snapshot: CaptureSnapshot(totalFrames: 480, totalPackets: 1,
                            droppedPackets: 0, peak: example.1, rms: example.1 / 3,
                            sampleRate: 48_000, lastHostTime: 1, hostTimeValid: true), active: true,
                            localizationBundle: bundle)
                    }
                }.padding(24).frame(width: 600)
                    .background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.locale, Locale(identifier: language))
                let renderer = ImageRenderer(content: view); renderer.scale = 2
                let image = try #require(renderer.nsImage)
                let bitmap = try #require(NSBitmapImageRep(data: #require(image.tiffRepresentation)))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: root.appendingPathComponent("meter-\(language)-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
