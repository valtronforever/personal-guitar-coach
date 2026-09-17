import SwiftUI
import AppKit
import Domain

/// Compact score reader for practice. Animations interpolate incoming audio positions only.
struct PracticeTablatureView: View {
    let model: TimelineModel
    let selectedIDs: Set<String>
    let firstBar: Int
    let lastBar: Int
    let displayTick: Double?
    let attemptID: UUID?
    let playing: Bool
    var localizationBundle: Bundle = .main
    let onSelect: (String, Bool) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoom = 1.0
    @State private var followsPlayback = true
    @State private var requestedFocus: TimelineFocus?
    @FocusState private var focus: TimelineFocus?
    private var endTick: Int64 { min(model.exercise.durationTicks, Int64(lastBar) * model.ticksPerBar) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.exercise.hasHeldVoices { text("heldVoice.legend").font(.caption).foregroundStyle(.secondary) }
            HStack {
                text("tab.title").font(.headline)
                Text(verbatim: model.exercise.timeSignature.rawValue).monospacedDigit()
                Spacer()
                Toggle(isOn: $followsPlayback) { text("practice.score.follow") }.toggleStyle(.checkbox)
                    .accessibilityIdentifier("practice.score.follow")
                text("tab.zoom")
                Slider(value: $zoom, in: 0.8...1.5).frame(width: 90)
                    .accessibilityLabel(text("tab.zoom"))
            }
            GeometryReader { geometry in
                let layout = PracticeScoreLayout(timeline: model, firstBar: firstBar, width: geometry.size.width, zoom: zoom)
                let cursor = layout.cursor(displayTick, endTick: endTick)
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: PracticeScoreLayout.rowSpacing * zoom) {
                            ForEach(0..<layout.rowCount, id: \.self) { row in
                                PracticeScoreRow(model: model, layout: layout, row: row, cursor: cursor,
                                    selectedIDs: selectedIDs, firstBar: firstBar, lastBar: lastBar,
                                    zoom: zoom, playing: playing, localizationBundle: localizationBundle,
                                    focus: $focus, requestedFocus: requestedFocus, onSelect: onSelect).id(row)
                            }
                        }.padding(.vertical, 8)
                    }
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("practice.score.timeline")
                    .task {
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        reveal(cursor?.row ?? layout.countInSlot / layout.barsPerRow, proxy: proxy, animated: false)
                    }
                    .onChange(of: firstBar) { _, _ in revealStart(layout, proxy: proxy) }
                    .onChange(of: model.exercise) { _, _ in focus = nil; revealStart(layout, proxy: proxy) }
                    .onChange(of: attemptID) { _, _ in if followsPlayback { revealStart(layout, proxy: proxy) } }
                    .onChange(of: cursor?.row) { _, row in
                        if followsPlayback, let row { reveal(row, proxy: proxy, animated: true) }
                    }
                    .onChange(of: followsPlayback) { _, follow in
                        if follow { reveal(cursor?.row ?? layout.countInSlot / layout.barsPerRow, proxy: proxy, animated: true) }
                    }
                    .onChange(of: layout.barsPerRow) { _, _ in
                        if followsPlayback { reveal(cursor?.row ?? layout.countInSlot / layout.barsPerRow, proxy: proxy, animated: false) }
                    }
                    .onChange(of: zoom) { _, _ in
                        if followsPlayback { reveal(cursor?.row ?? layout.countInSlot / layout.barsPerRow, proxy: proxy, animated: false) }
                    }
                    .onChange(of: focus) { _, target in
                        if target == requestedFocus { requestedFocus = nil }
                        if !playing, let target { reveal(layout.slot(for: target.bar) / layout.barsPerRow, proxy: proxy, animated: true) }
                    }
                    .onMoveCommand { direction in
                        guard let focus, direction == .left || direction == .right,
                              let next = model.adjacent(to: focus.eventID, offset: direction == .left ? -1 : 1) else { return }
                        let target = TimelineFocus(eventID: next.id, bar: model.bar(containing: next.event.startTick))
                        requestedFocus = target
                        reveal(layout.slot(for: target.bar) / layout.barsPerRow, proxy: proxy, animated: false)
                        Task { @MainActor in await Task.yield(); self.focus = target }
                    }
                }
            }.frame(height: 390)
            text("practice.score.instructions").font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func revealStart(_ layout: PracticeScoreLayout, proxy: ScrollViewProxy) {
        reveal(layout.countInSlot / layout.barsPerRow, proxy: proxy, animated: false)
    }
    private func reveal(_ row: Int64, proxy: ScrollViewProxy, animated: Bool) {
        withAnimation(animated && !reduceMotion ? .easeInOut(duration: 0.4) : nil) {
            proxy.scrollTo(row, anchor: .top)
        }
    }

    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), bundle: localizationBundle) }
}
