import AppKit
import SwiftUI
import Testing
import Domain
@testable import PersonalGuitarCoach

/// Opt-in offline layout review; does not capture audio or interact with the running app.
@MainActor struct SyncTimelineRenderTests {
    @Test func renderTimelineWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_SYNC_RENDER_DIR"] else { return }
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
            for dark in [false, true] { for width in [600.0, 940.0] {
                var taps = SyncTimelineRun(source: .taps, status: .completed, context: "MOMENTUM 4", origin: 100, alignment: 0)
                taps.events = (4..<20).map { .init(id: UInt64($0), time: 100 + Double($0) + 0.12 + Double($0 % 3) * 0.01, kind: .tap) }
                var guitar = SyncTimelineRun(source: .guitar, status: .failed, context: "Scarlett 2i2 · Input 1 → MOMENTUM 4 · C2", origin: 100, alignment: 0.13)
                for beat in 4..<20 where beat != 9 {
                    let time = 100.17 + Double(beat) + Double(beat % 3) * 0.01
                    let kind: SyncTimelineEvent.Kind = beat == 12 ? .uncertain : beat == 7 ? .wrong : .matching
                    guitar.events.append(SyncTimelineEvent(id: UInt64(beat), time: time, kind: kind))
                }
                guitar.events.append(.init(id: 30, time: 106.4, kind: .uncertain))
                guitar.events.append(.init(id: 31, time: 123, kind: .wrong))
                let view = VStack(spacing: 16) {
                    SyncTimelineView(run: taps, bundle: bundle)
                    SyncTimelineView(run: guitar, bundle: bundle)
                }.padding(20).frame(width: width)
                    .background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.locale, Locale(identifier: language))
                let renderer = ImageRenderer(content: view); renderer.scale = 2
                let image = try #require(renderer.nsImage)
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: tiff))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: root.appendingPathComponent("sync-\(language)-\(Int(width))-\(dark ? "dark" : "light").png"))
            } }
        }
    }
}
