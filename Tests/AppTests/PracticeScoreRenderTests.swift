import AppKit
import SwiftUI
import Testing
import Domain
@testable import PersonalGuitarCoach

/// Opt-in offline layout review; does not capture audio or interact with the running app.
@MainActor struct PracticeScoreRenderTests {
    @Test func renderPracticeScoreWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_SCORE_RENDER_DIR"] else { return }
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
            var tick: Int64 = 0
            var events: [MusicalEvent] = []
            for i in 0..<32 {
                let duration: Int64 = [240, 240, 480, 960, 1920, 480, 480, 960][i % 8]
                events.append(try MusicalEvent(id: "n\(i)", startTick: tick, durationTicks: duration,
                    kind: i % 7 == 6 ? .rest : .note,
                    positions: i % 7 == 6 ? [] : i % 4 == 0
                        ? [FretPosition(string: 3, fret: 2), FretPosition(string: 2, fret: 1), FretPosition(string: 1, fret: 0)]
                        : [FretPosition(string: i % 6 + 1, fret: i % 20)], accented: i % 4 == 0 && i % 7 != 6,
                    strum: i % 4 == 0 && i % 7 != 6 ? StrumPattern(direction: i % 8 == 0 ? .down : .up) : nil, palmMuted: i % 3 == 0 && i % 7 != 6,
                    pickStroke: i % 4 != 0 && i % 7 != 6 ? (i.isMultiple(of: 2) ? .down : .up) : nil))
                tick += duration
            }
            let model = try TimelineModel(exercise: Exercise(id: "score-render", events: events, assessmentMode: .displayOnly), instrument: .cStandard)
            for dark in [false, true] { for width in [600.0, 980.0] {
                let view = PracticeScoreFixture(model: model, width: width - 40, bundle: bundle,
                    tick: width == 600 ? -480 : 1200)
                    .padding(20).frame(width: width)
                    .background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.locale, Locale(identifier: language))
                let renderer = ImageRenderer(content: view); renderer.scale = 2
                let image = try #require(renderer.nsImage)
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: tiff))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: root.appendingPathComponent("score-\(language)-\(Int(width))-\(dark ? "dark" : "light").png"))
            } }
        }
    }
}

private struct PracticeScoreFixture: View {
    let model: TimelineModel
    let width: Double
    let bundle: Bundle
    let tick: Double
    @FocusState private var focus: TimelineFocus?
    var body: some View {
        let layout = PracticeScoreLayout(timeline: model, firstBar: 1, width: width)
        VStack(spacing: PracticeScoreLayout.rowSpacing) {
            ForEach(0..<min(3, layout.rowCount), id: \.self) { row in
                PracticeScoreRow(model: model, layout: layout, row: row,
                    cursor: layout.cursor(tick, endTick: model.exercise.durationTicks), selectedIDs: ["n3"],
                    firstBar: 1, lastBar: Int(model.barCount), zoom: 1, playing: false,
                    localizationBundle: bundle, focus: $focus, requestedFocus: nil, onSelect: { _, _ in })
            }
        }.frame(width: width)
    }
}
