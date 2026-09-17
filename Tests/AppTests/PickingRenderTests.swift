import AppKit
import SwiftUI
import Testing
import Domain
@testable import PersonalGuitarCoach

/// Offline render fixtures, not evidence of native interaction or real instrument support.
@MainActor struct PickingRenderTests {
    @Test func renderPickingNotationWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_PICKING_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        let positions = try [FretPosition(string: 4, fret: 7), FretPosition(string: 2, fret: 5), FretPosition(string: 1, fret: 5), FretPosition(string: 2, fret: 5)]
        let fingers: [PluckingFinger?] = [nil, .middle, .ring, .middle]
        let events = try (0..<4).map { index in
            try MusicalEvent(id: "note-\(index)", startTick: Int64(index) * 960, durationTicks: 960, kind: .note,
                positions: [positions[index]], pickStroke: index == 0 ? .down : nil, pluckFinger: fingers[index])
        }
        let model = try TimelineModel(exercise: Exercise(id: "picking-render", events: events), instrument: .cStandard)
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
                let view = PickingRenderFixture(model: model, bundle: bundle)
                    .padding(20).frame(width: 800).background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light).environment(\.locale, Locale(identifier: language))
                let renderer = ImageRenderer(content: view); renderer.scale = 2
                let image = try #require(renderer.nsImage), tiff = try #require(image.tiffRepresentation), bitmap = try #require(NSBitmapImageRep(data: tiff))
                try #require(bitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent("picking-\(language)-\(dark ? "dark" : "light").png"))
            }
        }
    }
}

private struct PickingRenderFixture: View {
    let model: TimelineModel
    let bundle: Bundle
    @FocusState private var focus: TimelineFocus?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = PracticeScoreLayout(timeline: model, firstBar: 1, width: 760)
            ForEach(0..<layout.rowCount, id: \.self) { row in
                PracticeScoreRow(model: model, layout: layout, row: row, cursor: nil, selectedIDs: ["note-1"],
                    firstBar: 1, lastBar: 1, zoom: 1, playing: false, localizationBundle: bundle,
                    focus: $focus, requestedFocus: nil, onSelect: { _, _ in })
            }
            ForEach(0..<model.barCount, id: \.self) { bar in
                let staff = StaffModel(timeline: model, key: .neutral)
                let drawing = StaffDrawing(model: staff, bar: bar, selectedIDs: [])
                Canvas { context, _ in
                    if let symbols = try? staff.symbols(in: bar) { drawing.draw(symbols, context: &context) }
                }.frame(width: drawing.width, height: StaffModel.canvasHeight)
                    .scaleEffect(760 / drawing.width, anchor: .topLeading)
                    .frame(width: 760, height: StaffModel.canvasHeight * 760 / drawing.width, alignment: .topLeading).clipped()
            }
            Text("pluck.instructions", bundle: bundle).font(.caption).foregroundStyle(.secondary)

        }
    }
}
