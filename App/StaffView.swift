import SwiftUI
import AppKit
import Domain

/// One bounded bar of written guitar notation, selected through canonical event IDs.
struct StaffView: View {
    let timeline: TimelineModel
    let selectedIDs: Set<String>
    var cursorTick: Int64?
    let onSelect: (String, Bool) -> Void
    @State private var key: StaffKey = .neutral
    @State private var bar: Int64 = 0
    @FocusState private var focusedID: String?
    @State private var requestedFocus: String?
    private let leading = 96.0
    private var model: StaffModel { StaffModel(timeline: timeline, key: key) }
    private var currentBar: Int64 { min(max(0, bar), timeline.barCount - 1) }
    private var symbols: [StaffSymbol]? { try? model.symbols(in: currentBar) }
    private var width: Double { leading + timeline.barWidth(zoom: 1) + 36 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("staff.title").font(.headline)
                Spacer()
                Picker("staff.key", selection: $key) {
                    ForEach(StaffKey.allCases) { value in Text(LocalizedStringKey(value.titleKey)).tag(value) }
                }.frame(maxWidth: 250).accessibilityIdentifier("staff.key")
            }
            HStack {
                Button("tab.previous") { bar = max(0, currentBar - 1) }.disabled(currentBar == 0)
                Text("staff.bar \(currentBar + 1) \(timeline.barCount)").font(.caption).monospacedDigit()
                Button("tab.next") { bar = min(timeline.barCount - 1, currentBar + 1) }.disabled(currentBar + 1 >= timeline.barCount)
                Spacer()
            }
            if let symbols {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            Canvas { context, _ in
                                StaffDrawing(model: model, bar: currentBar, selectedIDs: selectedIDs, focusedID: focusedID, cursorTick: cursorTick).draw(symbols, context: &context)
                            }.accessibilityHidden(true)
                            ForEach(symbols) { symbol in
                                Button { onSelect(symbol.id, NSEvent.modifierFlags.contains(.shift)) } label: {
                                    Rectangle().fill(.clear).frame(width: 44, height: 248).contentShape(Rectangle())
                                }.buttonStyle(.plain).offset(x: x(symbol) - 22)
                                    .focusable()
                                    // Canvas draws focus at the note; the native ring uses the unoffset button frame.
                                    .focusEffectDisabled()
                                    .focused($focusedID, equals: symbol.id)
                                    .onAppear { if requestedFocus == symbol.id { focusedID = symbol.id } }
                                    .onKeyPress(keys: [.space, .return]) { event in
                                        onSelect(requestedFocus ?? symbol.id, event.modifiers.contains(.shift)); return .handled
                                    }
                                    .accessibilityIdentifier("staff.event.\(symbol.id)")
                                    .accessibilityLabel(accessibility(symbol))
                                    .accessibilityValue(Text(LocalizedStringKey(selectedIDs.contains(symbol.id) ? "fretboard.selected" : "fretboard.unmarked")))
                                    .accessibilityHint(Text("staff.selectHint"))
                                    .id(symbol.id)
                            }
                            // Real layout frames give ScrollViewReader distinct beat targets.
                            HStack(spacing: 0) {
                                Color.clear.frame(width: leading + 24, height: 1)
                                ForEach(0..<timeline.exercise.timeSignature.beatsPerBar * 2, id: \.self) { half in
                                    Color.clear.frame(width: TimelineModel.baseBeatWidth / 2, height: 1)
                                        .id(TimelineFollowTarget(bar: currentBar, halfBeat: half))
                                }
                                Color.clear.frame(width: 1, height: 1)
                                    .id(TimelineFollowTarget(bar: currentBar, halfBeat: timeline.exercise.timeSignature.beatsPerBar * 2))
                            }.allowsHitTesting(false).accessibilityHidden(true)
                        }.frame(width: width, height: 248)
                    }.frame(height: 260).background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("staff.timeline")
                        .onChange(of: focusedID) { _, id in
                            if id == requestedFocus { requestedFocus = nil }
                            if let id { revealEvent(id, using: proxy) }
                        }
                        .onChange(of: selectedIDs) { _, _ in reveal(using: proxy) }
                        .onChange(of: timeline.followTarget(cursorTick)) { _, _ in reveal(using: proxy) }
                        .onChange(of: currentBar) { _, _ in Task { @MainActor in await Task.yield(); reveal(using: proxy) } }
                        .onAppear { reveal(using: proxy) }
                        .onMoveCommand { direction in
                            guard let focusedID = requestedFocus ?? focusedID, direction == .left || direction == .right,
                                  let next = timeline.adjacent(to: focusedID, offset: direction == .left ? -1 : 1) else { return }
                            requestedFocus = next.id
                            bar = timeline.bar(containing: next.event.startTick)
                            Task { @MainActor in await Task.yield(); self.focusedID = next.id }
                        }
                }
            } else {
                Label("staff.unsupported", systemImage: "info.circle").font(.callout).padding().frame(height: 120)
            }
            Text("staff.explanation").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { followSelection() }
        .onChange(of: selectedIDs) { _, _ in followSelection() }
        .onChange(of: timeline.exercise) { _, _ in bar = 0; focusedID = nil; requestedFocus = nil; followSelection() }
        .onChange(of: timeline.cursorBar(cursorTick)) { _, value in if let value { bar = value } }
    }
    private func x(_ symbol: StaffSymbol) -> Double {
        leading + timeline.x(tick: symbol.resolved.event.startTick, bar: currentBar, zoom: 1) + 24
    }
    private func followSelection() {
        if let cursor = timeline.cursorBar(cursorTick) { bar = cursor }
        else if let first = timeline.events.first(where: { selectedIDs.contains($0.id) }) { bar = timeline.bar(containing: first.event.startTick) }
    }
    private func reveal(using proxy: ScrollViewProxy) {
        if let target = timeline.followTarget(cursorTick), target.bar == currentBar {
            proxy.scrollTo(target, anchor: .center)
        } else if let first = symbols?.first(where: { selectedIDs.contains($0.id) }) { revealEvent(first.id, using: proxy) }
    }
    private func revealEvent(_ id: String, using proxy: ScrollViewProxy) {
        if let event = timeline.events.first(where: { $0.id == id }), let target = timeline.followTarget(event.event.startTick) {
            proxy.scrollTo(target, anchor: .center)
        }
    }
    private func accessibility(_ symbol: StaffSymbol) -> Text {
        let duration = TimelineModel.durationLabel(symbol.resolved.event.durationTicks)
        if let pitch = symbol.pitch {
            let sounding = symbol.resolved.pitches[0].name()
            return Text("staff.note \(pitch.name) \(sounding) \(duration)")
        }
        return Text("staff.rest \(duration)")
    }
}

/// Immutable notation drawing shared by the view and offline render fixtures.
struct StaffDrawing {
    let model: StaffModel
    let bar: Int64
    let selectedIDs: Set<String>
    var focusedID: String? = nil
    var cursorTick: Int64? = nil
    private let leading = 96.0
    private var timeline: TimelineModel { model.timeline }
    private var key: StaffKey { model.key }
    private var currentBar: Int64 { bar }
    var width: Double { leading + timeline.barWidth(zoom: 1) + 36 }
    private func x(_ symbol: StaffSymbol) -> Double {
        leading + timeline.x(tick: symbol.resolved.event.startTick, bar: currentBar, zoom: 1) + 24
    }
    func draw(_ symbols: [StaffSymbol], context: inout GraphicsContext) {
        let ink = Color.primary, lineEnd = width - 12
        func line(_ a: CGPoint, _ b: CGPoint, thickness: Double = 1, color: Color = .primary) {
            var path = Path(); path.move(to: a); path.addLine(to: b); context.stroke(path, with: .color(color), lineWidth: thickness)
        }
        for step in stride(from: 30, through: 38, by: 2) {
            let y = StaffModel.y(step: step); line(CGPoint(x: 4, y: y), CGPoint(x: lineEnd, y: y), color: .secondary)
        }
        context.draw(Text(verbatim: "𝄞").font(.custom("Apple Symbols", size: 88)), at: CGPoint(x: 24, y: 148))
        context.draw(Text(verbatim: "8").font(.system(size: 12)), at: CGPoint(x: 24, y: 184))
        context.draw(Text(verbatim: String(timeline.exercise.timeSignature.beatsPerBar)).font(.system(size: 24, weight: .bold)), at: CGPoint(x: 78, y: 124))
        context.draw(Text(verbatim: "4").font(.system(size: 24, weight: .bold)), at: CGPoint(x: 78, y: 149))
        if key != .neutral {
            context.draw(Text(verbatim: key == .gMajor ? "♯" : "♭").font(.custom("Apple Symbols", size: 29)),
                at: CGPoint(x: 53, y: StaffModel.y(step: key == .gMajor ? 38 : 34)))
        }
        line(CGPoint(x: lineEnd, y: 112), CGPoint(x: lineEnd, y: 160))
        let beams = model.beams(symbols)
        for symbol in symbols {
            let position = x(symbol), event = symbol.resolved.event
            let selected = selectedIDs.contains(symbol.id), focused = focusedID == symbol.id
            if selected || focused {
                let rect = CGRect(x: position - 21, y: 8, width: 42, height: 226)
                context.stroke(Path(roundedRect: rect, cornerRadius: 5), with: .color(selected ? .accentColor : .primary),
                               style: StrokeStyle(lineWidth: 2, dash: focused ? [3, 3] : []))
            }
            if let pitch = symbol.pitch {
                let y = StaffModel.y(step: pitch.step)
                for ledger in StaffModel.ledgerSteps(for: pitch.step) { line(CGPoint(x: position - 13, y: StaffModel.y(step: ledger)), CGPoint(x: position + 13, y: StaffModel.y(step: ledger))) }
                let head = Path(ellipseIn: CGRect(x: position - 7.5, y: y - 5, width: 15, height: 10))
                if symbol.hollow {
                    var erase = context; erase.blendMode = .destinationOut
                    erase.fill(head, with: .color(.white)); context.stroke(head, with: .color(ink), lineWidth: 1.7)
                } else { context.fill(head, with: .color(ink)) }
                if let accidental = symbol.accidental { context.draw(Text(verbatim: accidental).font(.custom("Apple Symbols", size: 24)), at: CGPoint(x: position - 18, y: y)) }
                let beam = beams.first { $0.ids.contains(symbol.id) }
                let up = beam?.stemsUp ?? (pitch.step < 34)
                let stemX = position + (up ? 7 : -7)
                let groupY = symbols.filter { beam?.ids.contains($0.id) == true }.compactMap { $0.pitch.map { StaffModel.y(step: $0.step) } }
                let stemEnd = (up ? groupY.min() ?? y : groupY.max() ?? y) + (up ? -32 : 32)
                if symbol.hasStem { line(CGPoint(x: stemX, y: y), CGPoint(x: stemX, y: stemEnd), thickness: 1.5) }
                if symbol.flags > 0 && beam == nil {
                    for flag in 0..<symbol.flags {
                        let flagY = stemEnd + Double(flag) * (up ? 7 : -7)
                        var path = Path(); path.move(to: CGPoint(x: stemX, y: flagY))
                        path.addQuadCurve(to: CGPoint(x: stemX + 9, y: flagY + (up ? 20 : -20)), control: CGPoint(x: stemX + 19, y: flagY + (up ? 9 : -9)))
                        context.stroke(path, with: .color(ink), lineWidth: 3)
                    }
                }
            } else {
                if event.durationTicks >= 1920 {
                    // Whole rest hangs from D5; half rest sits on B4.
                    let y = event.durationTicks == 3840 ? 124.0 : 130.0
                    context.fill(Path(CGRect(x: position - 8, y: y, width: 16, height: 6)), with: .color(ink))
                } else {
                    let y = 136.0
                    if event.durationTicks == 960 {
                        var rest = Path()
                        rest.move(to: CGPoint(x: position - 4, y: y - 19))
                        rest.addLine(to: CGPoint(x: position + 5, y: y - 10))
                        rest.addLine(to: CGPoint(x: position - 3, y: y - 1))
                        rest.addLine(to: CGPoint(x: position + 5, y: y + 8))
                        rest.addQuadCurve(to: CGPoint(x: position - 5, y: y + 17), control: CGPoint(x: position - 10, y: y + 5))
                        context.stroke(rest, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    } else {
                        let hooks = event.durationTicks == 240 ? 2 : 1
                        var stem = Path(); stem.move(to: CGPoint(x: position + 7, y: y - 14))
                        stem.addQuadCurve(to: CGPoint(x: position - 3, y: y + (hooks == 2 ? 22 : 14)), control: CGPoint(x: position + 3, y: y + 6))
                        context.stroke(stem, with: .color(ink), lineWidth: 2)
                        for hook in 0..<hooks {
                            let hookY = y - 12 + Double(hook) * 9
                            var curve = Path(); curve.move(to: CGPoint(x: position + 6 - Double(hook) * 2, y: hookY - 2))
                            curve.addQuadCurve(to: CGPoint(x: position - 4, y: hookY), control: CGPoint(x: position + 1, y: hookY + 6))
                            context.stroke(curve, with: .color(ink), lineWidth: 2)
                            context.fill(Path(ellipseIn: CGRect(x: position - 8, y: hookY - 4, width: 7, height: 7)), with: .color(ink))
                        }
                    }
                }
            }
            context.draw(Text(verbatim: TimelineModel.durationLabel(event.durationTicks)).font(.system(size: 10)), at: CGPoint(x: position, y: 238))
        }
        for beam in beams {
            let members = symbols.filter { beam.ids.contains($0.id) }
            guard let first = members.first, let last = members.last else { continue }
            let heights = members.compactMap { $0.pitch.map { StaffModel.y(step: $0.step) } }
            let y = (beam.stemsUp ? heights.min() ?? 136 : heights.max() ?? 136) + (beam.stemsUp ? -32 : 32)
            for flag in 0..<beam.flags {
                let offset = Double(flag) * (beam.stemsUp ? 7 : -7), stemOffset = beam.stemsUp ? 7.0 : -7.0
                line(CGPoint(x: x(first) + stemOffset, y: y + offset), CGPoint(x: x(last) + stemOffset, y: y + offset), thickness: 4)
            }
        }
        if let tick = cursorTick, timeline.cursorBar(tick) == currentBar {
            let cursorX = leading + timeline.x(tick: tick, bar: currentBar, zoom: 1) + 24
            line(CGPoint(x: cursorX, y: 8), CGPoint(x: cursorX, y: 228), thickness: 2, color: .accentColor)
        }
    }
}
