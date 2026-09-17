import AppKit
import SwiftUI
import Foundation
import Testing
import Domain
@testable import PersonalGuitarCoach

@MainActor struct ListeningRenderTests {
    @Test func neutralPulseContainsNoEventDataAndHandlesCountInBoundaries() throws {
        let exercise = try Exercise(id: "hidden", events: [MusicalEvent(id: "secret", startTick: 960, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 7)])])
        for (tick, expected) in [(-3840.0,0),(-1.0,3),(0.0,0),(959.0,0),(960.0,1),(3840.0,0)] {
            #expect(ListeningPulseView(exercise: exercise, displayTick: tick).pulse == expected)
        }
        #expect(ListeningPulseView(exercise: exercise, displayTick: .infinity).pulse == nil)
        #expect(ListeningPulseView(exercise: exercise, displayTick: .greatestFiniteMagnitude).pulse != nil)
    }
    @Test func renderHiddenListeningPreparationWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_LISTEN_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        let exercise = try Exercise(id: "hidden", events: [MusicalEvent(id: "secret", startTick: 960, durationTicks: 960, kind: .note, positions: [FretPosition(string: 3, fret: 7)])])
        for language in ["en", "uk"] {
            let resources = root.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
            var strings: [String: String] = [:]
            for (key, entry) in entries {
                if let locales = entry["localizations"] as? [String: [String: Any]], let unit = locales[language]?["stringUnit"] as? [String: String] { strings[key] = unit["value"] }
            }
            try PropertyListSerialization.data(fromPropertyList: strings, format: .xml, options: 0).write(to: resources.appendingPathComponent("Localizable.strings"))
            let bundle = try #require(Bundle(url: resources))
            for dark in [false,true] {
                let view = VStack(spacing: 18) {
                    ListeningPreparationView(playing: false, busy: false, hidesTargets: true, referenceCompleted: false, outputAvailable: true, onListen: {}, onReveal: {}, localizationBundle: bundle)
                    ListeningPulseView(exercise: exercise, displayTick: 960, localizationBundle: bundle)
                    ListeningPreparationView(playing: false, busy: false, hidesTargets: false, referenceCompleted: true, outputAvailable: true, onListen: {}, onReveal: {}, localizationBundle: bundle)
                }.padding(20).frame(width: 600).background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light).environment(\.locale, Locale(identifier: language))
                let host = NSHostingView(rootView: view)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                host.layoutSubtreeIfNeeded()
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: root.appendingPathComponent("listening-\(language)-\(dark ? "dark" : "light").png"))
            }
        }
    }
}
