import AppKit
import SwiftUI
import Testing
import Domain
@testable import PersonalGuitarCoach

/// Offline render fixtures, not evidence of native interaction or real instrument support.
@MainActor struct MutedAttackRenderTests {
    @Test func renderMutedAttackNotationWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_MUTED_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        let events = try (0..<8).map { index -> MusicalEvent in
            if index == 2 || index == 5 { return try MusicalEvent(id: "rest-\(index)", startTick: Int64(index * 480), durationTicks: 480, kind: .rest) }
            if index == 0 || index == 6 { return try MusicalEvent(id: "note-\(index)", startTick: Int64(index * 480), durationTicks: 480, kind: .note, positions: [FretPosition(string: 3, fret: index == 0 ? 5 : 7)]) }
            return try MusicalEvent(id: "note-\(index)", startTick: Int64(index * 480), durationTicks: 480, kind: .note, accented: index == 4,
                mutedAttack: MutedStringAttack(strings: index == 4 ? [2] : [1,2,3], direction: index % 2 == 0 ? .down : .up))
        }
        let model = try TimelineModel(exercise: Exercise(id: "muted-render", events: events, assessmentMode: .displayOnly), instrument: .cStandard)
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
                let view = MutedAttackRenderFixture(model: model, bundle: bundle)
                    .padding(20).frame(width: 800).background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light).environment(\.locale, Locale(identifier: language))
                let renderer = ImageRenderer(content: view); renderer.scale = 2
                let image = try #require(renderer.nsImage), tiff = try #require(image.tiffRepresentation), bitmap = try #require(NSBitmapImageRep(data: tiff))
                try #require(bitmap.representation(using: .png, properties: [:])).write(to: root.appendingPathComponent("muted-\(language)-\(dark ? "dark" : "light").png"))
            }
        }
    }
}

private struct MutedAttackRenderFixture: View {
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
            Text("mutedAttack.legend", bundle: bundle).font(.caption).foregroundStyle(.secondary)

        }
    }
}
