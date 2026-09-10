#if DEBUG
import SwiftUI
import AppKit
import Domain

/// Development-only fixtures exercise the real renderers without pretending to capture or play audio.
struct VisualFixtureView: View {
    @State private var fixture = "rhythm"
    @State private var view = "tablature"
    @State private var selection = TimelineSelection()
    @State private var position: FretPosition?
    @State private var cursor = 0.0
    @State private var showCursor = false
    @Environment(AppSettings.self) private var settings
    private let fixtures = ["rhythm", "scale", "em", "muted"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("debug.visualTitle").font(.title2.bold())
            Picker("debug.fixture", selection: $fixture) {
                ForEach(fixtures, id: \.self) { id in Text(LocalizedStringKey(fixtureKey(id))).tag(id) }
            }.accessibilityIdentifier("debug.fixture")
            Picker("tab.visualMode", selection: $view) {
                Text("tab.title").tag("tablature")
                Text("fretboard.title").tag("fretboard")
            }.pickerStyle(.segmented)
            if let exercise = try? makeExercise(), let model = try? TimelineModel(exercise: exercise, instrument: .standard) {
                if view == "tablature" {
                    Toggle("debug.cursor", isOn: $showCursor)
                    if showCursor {
                        Slider(value: $cursor, in: 0...Double(exercise.durationTicks), step: 240)
                            .accessibilityLabel(Text("debug.cursor")).accessibilityIdentifier("debug.cursor")
                    }
                    TablatureView(model: model, selectedIDs: selection.ids, cursorTick: showCursor ? Int64(cursor) : nil) { id, extending in
                        selection.select(id, extending: extending, events: exercise.events)
                    }.id(fixture)
                } else {
                    let chosen = selection.ids.isEmpty ? exercise.events : exercise.events.filter { selection.ids.contains($0.id) }
                    FretboardView(model: FretboardModel(tuning: .standard,
                        positions: chosen.flatMap(\.positions), mutedStrings: fixture == "muted" ? [5, 6] : [],
                        fingers: fixture == "em" ? [4: 3, 5: 2] : [:]), selected: $position,
                        detectedPitch: try? Pitch(midi: 40))
                }
            }
            Spacer(minLength: 0)
        }.padding(20).frame(minWidth: 680, minHeight: 620)
            .onChange(of: fixture) { _, _ in selection.clear(); position = nil; cursor = 0 }
    }

    private func fixtureKey(_ id: String) -> String { "debug.fixture.\(id)" }
    private func makeExercise() throws -> Exercise {
        if fixture == "em" || fixture == "muted" {
            let strings = fixture == "em" ? Array(1...6) : Array(1...4)
            let shape = try strings.map { try FretPosition(string: $0, fret: [4, 5].contains($0) ? 2 : 0) }
            return try Exercise(id: fixture, events: [MusicalEvent(id: "shape", startTick: 0, durationTicks: 3840, kind: .note, positions: shape)], assessmentMode: .displayOnly)
        }
        if fixture == "scale" {
            let events = try (0..<320).map { index in
                try MusicalEvent(id: "scale-\(index)", startTick: Int64(index) * 240, durationTicks: 240, kind: .note,
                    positions: [FretPosition(string: 1 + index / 25 % 6, fret: index % 25)])
            }
            return try Exercise(id: "scale", events: events)
        }
        return try Exercise(id: "rhythm", events: [
            MusicalEvent(id: "quarter", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 6, fret: 0)]),
            MusicalEvent(id: "rest", startTick: 960, durationTicks: 480, kind: .rest),
            MusicalEvent(id: "short", startTick: 1440, durationTicks: 240, kind: .note, positions: [FretPosition(string: 5, fret: 2)]),
            MusicalEvent(id: "held", startTick: 1680, durationTicks: 1920, kind: .note, positions: [FretPosition(string: 4, fret: 2)])
        ], timeSignature: .threeFour)
    }
}

struct VisualFixtureCommands: Commands {
    let settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandMenu(settings.localized("debug.tools")) {
            Button(settings.localized("debug.visualTitle")) { openWindow(id: "visual-fixtures") }
            Button(settings.localized("debug.tunerTitle")) { openWindow(id: "tuner-fixtures") }
            Button(settings.localized("debug.assessmentTitle")) { openWindow(id: "assessment-fixtures") }
            Button(settings.localized("debug.minimumWindow")) {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                    window.setContentSize(NSSize(width: CoachLayout.minimumWidth, height: CoachLayout.minimumHeight))
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}
#endif
