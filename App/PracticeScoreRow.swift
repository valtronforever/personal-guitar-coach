import SwiftUI
import AppKit
import Domain

/// Shared row renderer used by the scrolling reader and offline visual fixtures.
struct PracticeScoreRow: View {
    let model: TimelineModel
    let layout: PracticeScoreLayout
    let row: Int64
    let cursor: (row: Int64, x: Double)?
    let selectedIDs: Set<String>
    let firstBar: Int
    let lastBar: Int
    let zoom: Double
    let playing: Bool
    let localizationBundle: Bundle
    @FocusState.Binding var focus: TimelineFocus?
    let requestedFocus: TimelineFocus?
    let onSelect: (String, Bool) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var gridTop: Double { 44 * zoom }
    private var stringSpacing: Double { 16 * zoom }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(1...6, id: \.self) { string in
                Text(verbatim: String(string)).font(.caption2.monospacedDigit())
                    .frame(width: PracticeScoreLayout.gutter, height: stringSpacing)
                    .offset(y: gridTop + Double(string - 1) * stringSpacing).accessibilityHidden(true)
            }
            ForEach(layout.slots(in: row), id: \.self) { slot in
                barView(layout.bar(for: slot), layout: layout)
                    .offset(x: PracticeScoreLayout.gutter + Double(slot % layout.barsPerRow) * layout.barWidth)
            }
            if let cursor, cursor.row == row {
                Rectangle().fill(Color.primary).frame(width: 2, height: 132 * zoom)
                    .overlay(alignment: .top) { Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)) }
                    .offset(x: cursor.x - 1, y: 18 * zoom)
                    .animation(playing && !reduceMotion ? .linear(duration: 0.055) : nil, value: cursor.x)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }.frame(maxWidth: .infinity, alignment: .topLeading).frame(height: PracticeScoreLayout.rowHeight * zoom)
    }

    private func barView(_ bar: Int64?, layout: PracticeScoreLayout) -> some View {
        ZStack(alignment: .topLeading) {
            if bar == nil { Color.accentColor.opacity(0.08) }
            Canvas { context, _ in
                for string in 1...6 {
                    let y = gridTop + (Double(string) - 0.5) * stringSpacing
                    var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: layout.barWidth, y: y))
                    context.stroke(line, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
                }
                for beat in 0...layout.beatsPerBar {
                    let x = Double(beat) / Double(layout.beatsPerBar) * layout.barWidth
                    var line = Path(); line.move(to: CGPoint(x: x, y: gridTop - 2)); line.addLine(to: CGPoint(x: x, y: gridTop + 6 * stringSpacing))
                    let boundary = beat == 0 || beat == layout.beatsPerBar
                    context.stroke(line, with: .color(.secondary), style: StrokeStyle(lineWidth: boundary ? 1.5 : 0.5, dash: boundary ? [] : [2, 4]))
                }
            }.accessibilityHidden(true)
            if let bar {
                Text("tab.bar \(bar + 1)", bundle: localizationBundle).font(.caption.bold()).padding(.leading, 4).accessibilityHidden(true)
                ForEach(model.segments(in: bar)) { segment in
                    let width = Double(segment.endTick - segment.startTick) / Double(layout.ticksPerBar) * layout.barWidth
                    eventButton(segment, layout: layout)
                        .offset(x: layout.x(tick: Double(segment.startTick), bar: bar) - min(8 * zoom, width / 2))
                }
            } else {
                text("practice.score.countIn").font(.caption.bold()).padding(.leading, 4)
                ForEach(0..<layout.beatsPerBar, id: \.self) { beat in
                    Text(verbatim: String(beat + 1)).font(.title3.bold().monospacedDigit())
                        .frame(width: layout.barWidth / Double(layout.beatsPerBar), height: 26 * zoom)
                        .background(.background, in: RoundedRectangle(cornerRadius: 4))
                        .offset(x: Double(beat) / Double(layout.beatsPerBar) * layout.barWidth, y: 80 * zoom)
                        .accessibilityLabel(Text("practice.countInBeat \(beat + 1)", bundle: localizationBundle))
                }
            }
        }
        .frame(width: layout.barWidth, height: PracticeScoreLayout.rowHeight * zoom)
        .opacity(bar.map { (Int64(firstBar - 1)..<Int64(lastBar)).contains($0) ? 1 : 0.45 } ?? 1)
    }

    private func eventButton(_ segment: TimelineSegment, layout: PracticeScoreLayout) -> some View {
        let event = segment.resolved.event
        let width = Double(segment.endTick - segment.startTick) / Double(layout.ticksPerBar) * layout.barWidth
        let target = TimelineFocus(eventID: event.id, bar: segment.bar)
        return Button {
            focus = target; onSelect(event.id, NSEvent.modifierFlags.contains(.shift))
        } label: {
            ZStack(alignment: .topLeading) {
                if selectedIDs.contains(event.id) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.primary.opacity(0.5), lineWidth: 1))
                }
                durationMark(event.durationTicks, continuation: segment.isContinuation)
                    .frame(width: width, height: 24 * zoom).offset(y: 16 * zoom)
                if event.kind == .rest {
                    Image(systemName: "pause.fill").font(.caption)
                        .frame(width: width, height: 6 * stringSpacing).offset(y: gridTop)
                } else {
                    ForEach(event.positions, id: \.self) { position in
                        Text(verbatim: String(position.fret)).font(.system(size: 12 * zoom, weight: .bold, design: .monospaced))
                            .frame(minWidth: 15 * zoom, minHeight: 16 * zoom).background(.background, in: RoundedRectangle(cornerRadius: 3))
                            .position(x: min(8 * zoom, width / 2), y: gridTop + (Double(position.string) - 0.5) * stringSpacing)
                    }
                }
            }.frame(width: width, height: 144 * zoom, alignment: .topLeading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusable().focused($focus, equals: target)
        .onAppear { if requestedFocus == target { focus = target } }
        .onKeyPress(keys: [.space, .return]) { key in onSelect(event.id, key.modifiers.contains(.shift)); return .handled }
        .accessibilityLabel(description(segment))
        .accessibilityValue(text(selectedIDs.contains(event.id) ? "fretboard.selected" : "fretboard.unmarked"))
        .accessibilityHint(text("practice.score.selectHint"))
        .help(description(segment))
        .accessibilityIdentifier("practice.score.event.\(event.id).bar.\(segment.bar + 1)")
    }

    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), bundle: localizationBundle) }
    private func durationMark(_ ticks: Int64, continuation: Bool) -> some View {
        let parts = TimelineModel.durationLabel(ticks).split(separator: "/").map(String.init)
        return HStack(spacing: 1) {
            if continuation { Image(systemName: "arrow.turn.down.right").font(.system(size: 7 * zoom)) }
            VStack(spacing: 0) {
                Text(verbatim: parts[0])
                if parts.count == 2 {
                    Rectangle().frame(width: 10 * zoom, height: 0.5)
                    Text(verbatim: parts[1])
                }
            }.font(.system(size: 8 * zoom).monospacedDigit())
        }.lineLimit(1).minimumScaleFactor(0.5)
    }
    private func description(_ segment: TimelineSegment) -> Text {
        let event = segment.resolved.event
        let beat = (Double(segment.startTick - model.startTick(of: segment.bar)) / Double(MusicalTime.ppq) + 1)
            .formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        let duration = TimelineModel.durationLabel(event.durationTicks)
        if event.kind == .rest { return Text("tab.restDescription \(segment.bar + 1) \(beat) \(duration)", bundle: localizationBundle) }
        let format = localizationBundle.localizedString(forKey: "tab.position %lld %lld %@", value: nil, table: nil)
        let notes = zip(event.positions, segment.resolved.pitches).map { position, pitch in
            String(format: format, locale: locale, Int64(position.string), Int64(position.fret), pitch.name(spelling: model.tuning.preferredSpelling))
        }.joined(separator: "; ")
        return Text("tab.noteDescription \(segment.bar + 1) \(beat) \(duration) \(notes)", bundle: localizationBundle)
    }
}
