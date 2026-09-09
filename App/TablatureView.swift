import SwiftUI
import AppKit
import Domain

struct TimelineFocus: Hashable { let eventID: String; let bar: Int64 }

/// Receives a transport tick; it owns no playback timer or audio clock.
struct TablatureView: View {
    let model: TimelineModel
    let selectedIDs: Set<String>
    var cursorTick: Int64? = nil
    let onSelect: (String, Bool) -> Void
    @Environment(AppSettings.self) private var settings
    @State private var zoom = 1.0
    @State private var pageBar: Int64 = 0
    @State private var jumpText = "1"
    @State private var followedTarget: TimelineFollowTarget?
    @State private var requestedFocus: TimelineFocus?
    @FocusState private var focus: TimelineFocus?
    private let rowHeight: CGFloat = 26
    private let gridTop: CGFloat = 48
    private var height: CGFloat { gridTop + rowHeight * 6 + 24 }
    private var page: Range<Int64> { model.page(containing: pageBar) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("tab.title").font(.headline).accessibilityAddTraits(.isHeader)
                Text(verbatim: model.exercise.timeSignature.rawValue).monospacedDigit()
                Spacer()
                Text("tab.zoom")
                Slider(value: $zoom, in: 1...2).frame(width: 120).accessibilityLabel(Text("tab.zoom"))
                    .accessibilityIdentifier("tab.zoom")
            }
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button("tab.previous") { pageBar = max(0, page.lowerBound - TimelineModel.barsPerPage) }
                            .disabled(page.lowerBound == 0)
                        Button("tab.next") { pageBar = page.upperBound }.disabled(page.upperBound == model.barCount)
                        Spacer()
                        TextField("tab.jump", text: $jumpText).textFieldStyle(.roundedBorder).frame(width: 90)
                            .accessibilityLabel(Text("tab.jump")).accessibilityIdentifier("tab.jump")
                        Button("tab.show") {
                            if let value = Int64(jumpText), (1...model.barCount).contains(value) {
                                pageBar = value - 1
                                // The destination page is inserted before the scroll request is applied.
                                Task { @MainActor in await Task.yield(); proxy.scrollTo(value - 1, anchor: .leading) }
                            }
                        }.disabled(Int64(jumpText).map { !(1...model.barCount).contains($0) } ?? true)
                    }
                    Text("tab.bars \(page.lowerBound + 1) \(page.upperBound) \(model.barCount)").font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: gridTop)
                            ForEach(1...6, id: \.self) { string in
                                Text(verbatim: String(string)).font(.caption.monospacedDigit())
                                    .frame(width: 24, height: rowHeight).accessibilityHidden(true)
                            }
                        }.frame(width: 24)
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 0) {
                                ForEach(page, id: \.self) { bar in barView(bar).id(bar) }
                            }.frame(height: height)
                        }.frame(height: height + 12).accessibilityIdentifier("tab.timeline")
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                            .onAppear { revealSelection(using: proxy) }
                            .onChange(of: model.exercise) { _, _ in
                                pageBar = 0; jumpText = "1"; focus = nil; requestedFocus = nil; followedTarget = nil
                                revealSelection(using: proxy)
                            }
                            .onChange(of: selectedIDs) { _, _ in revealSelection(using: proxy) }
                            .onChange(of: focus) { _, target in
                                if let target {
                                    if requestedFocus == target { requestedFocus = nil }
                                    reveal(bar: target.bar, using: proxy)
                                }
                            }
                            .onChange(of: cursorTick) { _, tick in
                                if let target = model.followTarget(tick), target != followedTarget {
                                    revealCursor(target, using: proxy)
                                } else if model.followTarget(tick) == nil { followedTarget = nil }
                            }
                            .onChange(of: zoom) { _, _ in
                                if let target = model.followTarget(cursorTick) { revealCursor(target, using: proxy) }
                                else { revealSelection(using: proxy) }
                            }
                            .onMoveCommand { direction in
                                guard let focus, direction == .left || direction == .right,
                                      let next = model.adjacent(to: focus.eventID, offset: direction == .left ? -1 : 1) else { return }
                                let target = TimelineFocus(eventID: next.id, bar: model.bar(containing: next.event.startTick))
                                requestedFocus = target
                                reveal(bar: target.bar, using: proxy)
                                Task { @MainActor in await Task.yield(); self.focus = target }
                            }
                    }
                }
            }
            Text("tab.instructions").font(.caption).foregroundStyle(.secondary)
                .lineLimit(3).frame(minHeight: 44, alignment: .topLeading)
            if let tick = cursorTick, let bar = model.cursorBar(tick) {
                Group {
                    if tick == model.exercise.durationTicks { Text("tab.cursorEnd") }
                    else { Text("tab.cursor \(bar + 1) \(beatText(tick, bar: bar))") }
                }.font(.caption).accessibilityIdentifier("tab.cursor")
            }
        }
        .onKeyPress(keys: [.space, .return]) { key in
            guard let requestedFocus else { return .ignored }
            onSelect(requestedFocus.eventID, key.modifiers.contains(.shift)); return .handled
        }
    }

    private func revealSelection(using proxy: ScrollViewProxy) {
        if let target = model.followTarget(cursorTick) { revealCursor(target, using: proxy) }
        else if let first = model.events.first(where: { selectedIDs.contains($0.id) }) {
            reveal(bar: model.bar(containing: first.event.startTick), using: proxy)
        }
    }
    private func revealCursor(_ target: TimelineFollowTarget, using proxy: ScrollViewProxy) {
        let changesBar = followedTarget?.bar != target.bar || !page.contains(target.bar)
        followedTarget = target
        pageBar = target.bar
        Task { @MainActor in
            await Task.yield()
            if changesBar { proxy.scrollTo(target.bar, anchor: .leading); await Task.yield() }
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func reveal(bar: Int64, using proxy: ScrollViewProxy) {
        pageBar = bar
        Task { @MainActor in await Task.yield(); proxy.scrollTo(bar, anchor: .leading) }
    }

    private func barView(_ bar: Int64) -> some View {
        let width = model.barWidth(zoom: zoom)
        return ZStack(alignment: .topLeading) {
            Canvas { context, size in
                for string in 1...6 {
                    let y = gridTop + (CGFloat(string) - 0.5) * rowHeight
                    var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
                }
                for beat in 0...model.exercise.timeSignature.beatsPerBar {
                    let x = Double(beat) * TimelineModel.baseBeatWidth * zoom
                    var line = Path(); line.move(to: CGPoint(x: x, y: gridTop - 6)); line.addLine(to: CGPoint(x: x, y: gridTop + rowHeight * 6))
                    context.stroke(line, with: .color(.secondary.opacity(beat == 0 ? 1 : 0.35)), style: StrokeStyle(lineWidth: beat == 0 ? 2 : 1, dash: beat == 0 ? [] : [3, 4]))
                }
            }.accessibilityHidden(true)
            Text("tab.bar \(bar + 1)").font(.caption.bold()).padding(.leading, 6).accessibilityHidden(true)
            ForEach(model.segments(in: bar)) { segment in
                eventButton(segment)
                    .offset(x: model.x(tick: segment.startTick, bar: bar, zoom: zoom))
            }
            // These transparent layout cells have real frames for ScrollViewReader, independent of the drawing offsets.
            HStack(spacing: 0) {
                ForEach(0..<(model.exercise.timeSignature.beatsPerBar * 2), id: \.self) { slot in
                    Color.clear.frame(width: TimelineModel.baseBeatWidth * zoom / 2, height: 1)
                        .id(TimelineFollowTarget(bar: bar, halfBeat: slot))
                }
                Color.clear.frame(width: 1, height: 1)
                    .id(TimelineFollowTarget(bar: bar, halfBeat: model.exercise.timeSignature.beatsPerBar * 2))
            }.allowsHitTesting(false).accessibilityHidden(true)
            if let tick = cursorTick, model.cursorBar(tick) == bar {
                Rectangle().fill(.primary).frame(width: 2, height: height - 16)
                    .overlay(alignment: .top) { Image(systemName: "arrowtriangle.down.fill").font(.caption) }
                    .offset(x: model.x(tick: tick, bar: bar, zoom: zoom) - 1, y: 16)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }.frame(width: width, height: height)
    }

    private func eventButton(_ segment: TimelineSegment) -> some View {
        let event = segment.resolved.event
        let width = model.x(tick: segment.endTick, bar: segment.bar, zoom: zoom) - model.x(tick: segment.startTick, bar: segment.bar, zoom: zoom)
        let target = TimelineFocus(eventID: event.id, bar: segment.bar)
        return Button {
            requestedFocus = nil; focus = target; onSelect(event.id, NSEvent.modifierFlags.contains(.shift))
        } label: {
            ZStack(alignment: .topLeading) {
                if selectedIDs.contains(event.id) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary, lineWidth: 2))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        if segment.isContinuation { Image(systemName: "arrow.turn.down.right") }
                        if event.kind == .rest { Image(systemName: "pause.fill") }
                        Text(verbatim: TimelineModel.durationLabel(event.durationTicks)).monospacedDigit()
                    }.font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                    Rectangle().fill(.secondary).frame(height: 2)
                }.padding(.horizontal, 4).offset(y: 23)
                if event.kind == .rest {
                    Image(systemName: "pause.circle").font(.title2).frame(width: width, height: rowHeight * 6).offset(y: gridTop)
                } else {
                    ForEach(event.positions, id: \.self) { position in
                        Text(verbatim: String(position.fret)).font(.body.bold().monospacedDigit())
                            .frame(minWidth: 24, minHeight: 24).background(.background, in: RoundedRectangle(cornerRadius: 4))
                            .position(x: min(22, width / 2), y: gridTop + (CGFloat(position.string) - 0.5) * rowHeight)
                    }
                }
            }.frame(width: width, height: height - 2, alignment: .topLeading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).focusable().focused($focus, equals: target)
        .onAppear {
            if requestedFocus == target { focus = target }
        }
        .onKeyPress(keys: [.space, .return]) { key in
            onSelect(requestedFocus?.eventID ?? event.id, key.modifiers.contains(.shift)); return .handled
        }
        .accessibilityLabel(description(segment))
        .accessibilityValue(Text(LocalizedStringKey(segment.isContinuation
            ? (selectedIDs.contains(event.id) ? "tab.continuationSelected" : "tab.continuation")
            : (selectedIDs.contains(event.id) ? "fretboard.selected" : "fretboard.unmarked"))))
        .accessibilityHint(Text(LocalizedStringKey(segment.isContinuation ? "tab.continuationHint" : "tab.selectHint")))
        .help(description(segment))
        .accessibilityIdentifier("tab.event.\(event.id).bar.\(segment.bar + 1)")
    }

    private func beatText(_ tick: Int64, bar: Int64) -> String {
        (Double(tick - model.startTick(of: bar)) / Double(MusicalTime.ppq) + 1)
            .formatted(.number.precision(.fractionLength(0...2)).locale(settings.locale))
    }
    private func description(_ segment: TimelineSegment) -> Text {
        let event = segment.resolved.event
        let duration = TimelineModel.durationLabel(event.durationTicks)
        let beat = beatText(segment.startTick, bar: segment.bar)
        if event.kind == .rest { return Text("tab.restDescription \(segment.bar + 1) \(beat) \(duration)") }
        let notes = zip(event.positions, segment.resolved.pitches).map { position, pitch in
            String(format: settings.localized("tab.position %lld %lld %@"), locale: settings.locale,
                   Int64(position.string), Int64(position.fret), pitch.name())
        }.joined(separator: "; ")
        return Text("tab.noteDescription \(segment.bar + 1) \(beat) \(duration) \(notes)")
    }
}
