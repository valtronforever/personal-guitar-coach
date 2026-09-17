import SwiftUI
import AppKit
import Domain

/// One bounded bar of written guitar notation, selected through canonical event IDs.
struct StaffView: View {
    let timeline: TimelineModel
    let selectedIDs: Set<String>
    var cursorTick: Int64?
    let onSelect: (String, Bool) -> Void
    @Environment(AppSettings.self) private var settings
    @State private var key: StaffKey = .neutral
    @State private var bar: Int64 = 0
    @FocusState private var focusedID: NotationFragmentID?
    @State private var requestedFocus: NotationFragmentID?
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
            if timeline.exercise.events.contains(where: { $0.mutedAttack != nil }) { Text("mutedAttack.legend").font(.caption).foregroundStyle(.secondary) }
            if timeline.exercise.durationTicks % timeline.ticksPerBar != 0 { Text("staff.fragment").font(.caption).foregroundStyle(.secondary) }
            if let symbols {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            Canvas { context, _ in
                                StaffDrawing(model: model, bar: currentBar, selectedIDs: selectedIDs, focusedID: focusedID, cursorTick: cursorTick).draw(symbols, context: &context)
                            }.accessibilityHidden(true)
                            ForEach(symbols) { symbol in
                                Button { onSelect(symbol.eventID, NSEvent.modifierFlags.contains(.shift)) } label: {
                                    Rectangle().fill(.clear).frame(width: 44, height: StaffModel.canvasHeight).contentShape(Rectangle())
                                }.buttonStyle(.plain).offset(x: x(symbol) - 22)
                                    .focusable()
                                    // Canvas draws focus at the note; the native ring uses the unoffset button frame.
                                    .focusEffectDisabled()
                                    .focused($focusedID, equals: symbol.id)
                                    .onAppear { if requestedFocus == symbol.id { focusedID = symbol.id } }
                                    .onKeyPress(keys: [.space, .return]) { event in
                                        onSelect((requestedFocus ?? symbol.id).eventID, event.modifiers.contains(.shift)); return .handled
                                    }
                                    .accessibilityIdentifier("staff.event.\(symbol.eventID).tick.\(symbol.startTick)")
                                    .accessibilityLabel(accessibility(symbol))
                                    .accessibilityValue(Text(LocalizedStringKey(selectedIDs.contains(symbol.eventID) ? "fretboard.selected" : "fretboard.unmarked")))
                                    .accessibilityHint(Text(LocalizedStringKey(symbol.hintKey)))
                                    .id(symbol.id)
                            }
                            // Real layout frames give ScrollViewReader distinct beat targets.
                            HStack(spacing: 0) {
                                Color.clear.frame(width: leading + 24, height: 1)
                                ForEach(0..<timeline.exercise.timeSignature.beatsPerBar * 2, id: \.self) { half in
                                    Color.clear.frame(width: timeline.beatWidth / 2, height: 1)
                                        .id(TimelineFollowTarget(bar: currentBar, halfBeat: half))
                                }
                                Color.clear.frame(width: 1, height: 1)
                                    .id(TimelineFollowTarget(bar: currentBar, halfBeat: timeline.exercise.timeSignature.beatsPerBar * 2))
                            }.allowsHitTesting(false).accessibilityHidden(true)
                        }.frame(width: width, height: StaffModel.canvasHeight)
                    }.frame(height: StaffModel.canvasHeight + 12).background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
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
                                  let next = model.adjacent(to: focusedID, offset: direction == .left ? -1 : 1) else { return }
                            requestedFocus = next.id
                            bar = timeline.bar(containing: next.startTick)
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
        leading + timeline.x(tick: symbol.startTick, bar: currentBar, zoom: 1) + 24
    }
    private func followSelection() {
        if let cursor = timeline.cursorBar(cursorTick) { bar = cursor }
        else if symbols?.contains(where: { selectedIDs.contains($0.eventID) }) != true,
                let first = timeline.events.first(where: { selectedIDs.contains($0.id) }) { bar = timeline.bar(containing: first.event.startTick) }
    }
    private func reveal(using proxy: ScrollViewProxy) {
        if let target = timeline.followTarget(cursorTick), target.bar == currentBar {
            proxy.scrollTo(target, anchor: .center)
        } else if let first = symbols?.first(where: { selectedIDs.contains($0.eventID) }) { revealEvent(first.id, using: proxy) }
    }
    private func revealEvent(_ id: NotationFragmentID, using proxy: ScrollViewProxy) {
        if let target = timeline.followTarget(id.startTick) {
            proxy.scrollTo(target, anchor: .center)
        }
    }
    private func accessibility(_ symbol: StaffSymbol) -> Text {
        let written = TimelineModel.durationLabel(symbol.fragment.duration.triplet ? symbol.fragment.duration.baseTicks : symbol.fragment.duration.ticks)
        let duration = symbol.fragment.tripletID == nil ? written : String(format: settings.localized("rhythm.tripletDuration %@"), locale: settings.locale, written)
        if let attack = symbol.resolved.event.mutedAttack {
            var description = MutedAttackPresentation.spoken(attack, locale: settings.locale, localized: settings.localized)
            if let stroke = attack.direction, symbol.startTick == symbol.resolved.event.startTick {
                description = String(format: settings.localized("tab.pickedNotes %@ %@"), locale: settings.locale, settings.localized(stroke == .down ? "tab.strumDown" : "tab.strumUp"), description)
            }
            if symbol.accentedAttack { return Text("mutedAttack.staffAccent \(description) \(duration)") }
            return Text("mutedAttack.staff \(description) \(duration)")
        }
        if let pitch = symbol.pitch {
            var sounding = (try! Pitch(midi: symbol.resolved.pitches[0].midi + symbol.fragment.pitchOffset)).name(spelling: timeline.tuning.preferredSpelling)
            if let stroke = symbol.resolved.event.pickingDirection, symbol.startTick == symbol.resolved.event.startTick {
                let direction = settings.localized(stroke == .down ? "tab.strumDown" : "tab.strumUp")
                sounding = String(format: settings.localized("tab.pickedNotes %@ %@"), locale: settings.locale, direction, sounding)
            }
            if symbol.resolved.event.harmonic != nil { sounding += "; " + HarmonicPresentation.spoken(event: symbol.resolved.event, tuning: model.timeline.tuning, locale: settings.locale, localized: settings.localized) }
            if let finger = symbol.resolved.event.pluckFinger, symbol.startTick == symbol.resolved.event.startTick { sounding += "; " + settings.localized(finger.instructionKey) }
            if let bend = symbol.resolved.event.bend { sounding = String(format: settings.localized(bend.releaseEndTick == nil ? "bend.spoken %@ %lld" : "bend.spokenRelease %@ %lld"), locale: settings.locale, sounding, bend.semitones * 100) }
            if let vibrato = symbol.resolved.event.vibrato { sounding += "; " + VibratoPresentation.spoken(vibrato, pulseTicks: timeline.exercise.timeSignature.pulseTicks, locale: settings.locale, localized: settings.localized) }
            if symbol.resolved.event.pitchTransition != nil || symbol.resolved.event.legatoChain != nil {
                sounding += "; " + PitchTransitionPresentation.spoken(event: symbol.resolved, pulseTicks: timeline.pulseTicks,
                    tuning: timeline.tuning, locale: settings.locale, localized: settings.localized)
            }
            if symbol.resolved.event.palmMuted { sounding = String(format: settings.localized("tab.palmMutedNotes %@"), locale: settings.locale, sounding) }
            if symbol.accentedAttack {
                return symbol.fragment.duration.dotted
                    ? Text("staff.accentedDottedNote \(pitch.name) \(sounding) \(duration)")
                    : Text("staff.accentedNote \(pitch.name) \(sounding) \(duration)")
            }
            if symbol.fragment.duration.dotted { return Text("staff.dottedNote \(pitch.name) \(sounding) \(duration)") }
            return Text("staff.note \(pitch.name) \(sounding) \(duration)")
        }
        if symbol.fragment.duration.dotted { return Text("staff.dottedRest \(duration)") }
        return Text("staff.rest \(duration)")
    }
}

/// Immutable notation drawing shared by the view and offline render fixtures.
struct StaffDrawing {
    let model: StaffModel
    let bar: Int64
    let selectedIDs: Set<String>
    var focusedID: NotationFragmentID? = nil
    var cursorTick: Int64? = nil
    private let leading = 96.0
    private var timeline: TimelineModel { model.timeline }
    private var key: StaffKey { model.key }
    private var currentBar: Int64 { bar }
    var width: Double { leading + timeline.barWidth(zoom: 1) + 36 }
    private func x(_ symbol: StaffSymbol) -> Double {
        leading + timeline.x(tick: symbol.startTick, bar: currentBar, zoom: 1) + 24
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
        context.draw(Text(verbatim: String(timeline.exercise.timeSignature.numerator)).font(.system(size: 24, weight: .bold)), at: CGPoint(x: 78, y: 124))
        context.draw(Text(verbatim: String(timeline.exercise.timeSignature.denominator)).font(.system(size: 24, weight: .bold)), at: CGPoint(x: 78, y: 149))
        if key != .neutral {
            context.draw(Text(verbatim: key == .gMajor ? "♯" : "♭").font(.custom("Apple Symbols", size: 29)),
                at: CGPoint(x: 53, y: StaffModel.y(step: key == .gMajor ? 38 : 34)))
        }
        line(CGPoint(x: lineEnd, y: 112), CGPoint(x: lineEnd, y: 160))
        if let grouping = timeline.groupingLabel {
            context.draw(Text(verbatim: grouping).font(.caption.bold()), at: CGPoint(x: 78, y: 82))
        }
        let beams = model.beams(symbols)
        for symbol in symbols {
            let position = x(symbol), duration = symbol.fragment.duration
            let selected = selectedIDs.contains(symbol.eventID), focused = focusedID == symbol.id
            if selected || focused {
                let rect = CGRect(x: position - 21, y: 8, width: 42, height: StaffModel.canvasHeight - 22)
                context.stroke(Path(roundedRect: rect, cornerRadius: 5), with: .color(selected ? .accentColor : .primary),
                               style: StrokeStyle(lineWidth: 2, dash: focused ? [3, 3] : []))
            }
            if let step = symbol.engravingStep {
                let y = StaffModel.y(step: step)
                for ledger in StaffModel.ledgerSteps(for: step) { line(CGPoint(x: position - 13, y: StaffModel.y(step: ledger)), CGPoint(x: position + 13, y: StaffModel.y(step: ledger))) }
                var head = Path()
                if symbol.resolved.event.mutedAttack != nil {
                    head.move(to: CGPoint(x: position - 5, y: y - 5)); head.addLine(to: CGPoint(x: position + 5, y: y + 5))
                    head.move(to: CGPoint(x: position - 5, y: y + 5)); head.addLine(to: CGPoint(x: position + 5, y: y - 5))
                } else if symbol.resolved.event.harmonic != nil {
                    head.move(to: CGPoint(x: position - 7.5, y: y)); head.addLine(to: CGPoint(x: position, y: y - 6))
                    head.addLine(to: CGPoint(x: position + 7.5, y: y)); head.addLine(to: CGPoint(x: position, y: y + 6)); head.closeSubpath()
                } else { head = Path(ellipseIn: CGRect(x: position - 7.5, y: y - 5, width: 15, height: 10)) }
                if symbol.resolved.event.mutedAttack != nil { context.stroke(head, with: .color(ink), lineWidth: 2) }
                else if symbol.hollow {
                    var erase = context; erase.blendMode = .destinationOut
                    erase.fill(head, with: .color(.white)); context.stroke(head, with: .color(ink), lineWidth: 1.7)
                } else { context.fill(head, with: .color(ink)) }
                if let accidental = symbol.accidental { context.draw(Text(verbatim: accidental).font(.custom("Apple Symbols", size: 24)), at: CGPoint(x: position - 18, y: y)) }
                let beam = beams.first { $0.ids.contains(symbol.id) }
                let up = beam?.stemsUp ?? (step < 34)
                let stemX = position + (up ? 7 : -7)
                let groupY = symbols.filter { beam?.ids.contains($0.id) == true }.compactMap { $0.engravingStep.map { StaffModel.y(step: $0) } }
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
                if duration.baseTicks >= 1920 {
                    // Whole rest hangs from D5; half rest sits on B4.
                    let y = duration.baseTicks == 3840 ? 124.0 : 130.0
                    context.fill(Path(CGRect(x: position - 8, y: y, width: 16, height: 6)), with: .color(ink))
                } else {
                    let y = 136.0
                    if duration.baseTicks == 960 {
                        var rest = Path()
                        rest.move(to: CGPoint(x: position - 4, y: y - 19))
                        rest.addLine(to: CGPoint(x: position + 5, y: y - 10))
                        rest.addLine(to: CGPoint(x: position - 3, y: y - 1))
                        rest.addLine(to: CGPoint(x: position + 5, y: y + 8))
                        rest.addQuadCurve(to: CGPoint(x: position - 5, y: y + 17), control: CGPoint(x: position - 10, y: y + 5))
                        context.stroke(rest, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    } else {
                        let hooks = duration.baseTicks == 240 ? 2 : 1
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
            if let stroke = symbol.resolved.event.pickingDirection, symbol.startTick == symbol.resolved.event.startTick {
                context.draw(Text(verbatim: stroke == .down ? "↓" : "↑").font(.system(size: 12, weight: .bold)),
                    at: CGPoint(x: position, y: StaffModel.canvasHeight - 42))
            }
            if let finger = symbol.resolved.event.pluckFinger, symbol.startTick == symbol.resolved.event.startTick {
                context.draw(Text(verbatim: finger.symbol).font(.system(size: 12, weight: .bold)),
                    at: CGPoint(x: position, y: StaffModel.canvasHeight - 42))
            }
            if let harmonic = symbol.resolved.event.harmonic {
                context.draw(Text(verbatim: harmonic.notationLabel).font(.system(size: 10, weight: .bold)), at: CGPoint(x: position, y: StaffModel.canvasHeight - 26))
            }
            if let bend = symbol.resolved.event.bend {
                context.draw(Text(verbatim: "b\(bend.semitones)" + (bend.releaseEndTick == nil ? "" : "r")).font(.system(size: 10, weight: .bold)),
                    at: CGPoint(x: position, y: StaffModel.canvasHeight - 26))
            }
            if symbol.resolved.event.palmMuted {
                context.draw(Text(verbatim: "P.M.").font(.system(size: 10, weight: .bold)),
                    at: CGPoint(x: position, y: StaffModel.canvasHeight - 26))
            }
            if symbol.accentedAttack, let step = symbol.engravingStep {
                context.draw(Text(verbatim: ">").font(.system(size: 18, weight: .bold)),
                    at: CGPoint(x: position, y: max(12, min(98, StaffModel.y(step: step) - 44))))
            }
            if duration.dotted {
                let step = symbol.engravingStep
                let y = step.map { StaffModel.y(step: $0.isMultiple(of: 2) ? $0 + 1 : $0) } ?? 136
                context.fill(Path(ellipseIn: CGRect(x: position + 13, y: y - 2, width: 4, height: 4)), with: .color(ink))
            }
            context.draw(Text(verbatim: duration.label).font(.system(size: 10)), at: CGPoint(x: position, y: StaffModel.canvasHeight - 10))
        }
        for group in timeline.triplets(in: currentBar) {
            TripletBracket.draw(context: &context,
                start: leading + timeline.x(tick: group.startTick, bar: currentBar, zoom: 1) + 12,
                end: leading + timeline.x(tick: group.endTick, bar: currentBar, zoom: 1) - 2,
                y: 36)
        }
        for beam in beams {
            let members = symbols.filter { beam.ids.contains($0.id) }
            guard let first = members.first, let last = members.last else { continue }
            let heights = members.compactMap { $0.engravingStep.map { StaffModel.y(step: $0) } }
            let y = (beam.stemsUp ? heights.min() ?? 136 : heights.max() ?? 136) + (beam.stemsUp ? -32 : 32)
            for flag in 0..<beam.flags {
                let offset = Double(flag) * (beam.stemsUp ? 7 : -7), stemOffset = beam.stemsUp ? 7.0 : -7.0
                line(CGPoint(x: x(first) + stemOffset, y: y + offset), CGPoint(x: x(last) + stemOffset, y: y + offset), thickness: 4)
            }
        }
        for segment in timeline.segments(in: currentBar) {
            guard let span = VibratoPresentation.span(segment) else { continue }
            VibratoPresentation.draw(context: &context, start: leading + timeline.x(tick: span.lowerBound, bar: currentBar, zoom: 1),
                end: leading + timeline.x(tick: span.upperBound, bar: currentBar, zoom: 1), y: StaffModel.canvasHeight - 46)
        }
        for segment in timeline.segments(in: currentBar) {
            for link in PitchTransitionPresentation.links(segment.resolved.event) {
            let targetTick = link.endTick, linkStart = link.startTick
            let low = max(segment.startTick, linkStart), high = min(segment.endTick, targetTick)
            guard low < high else { continue }
            let a = leading + timeline.x(tick: low, bar: currentBar, zoom: 1) + (low == linkStart ? 32 : 0)
            let b = leading + timeline.x(tick: high, bar: currentBar, zoom: 1) + (high == targetTick ? 16 : 0)
            let y = StaffModel.canvasHeight - 46
            var path = Path(); path.move(to: CGPoint(x: a, y: y))
            if link.slide { path.addLine(to: CGPoint(x: b, y: y - (link.ascending ? 10 : -10))) }
            else { path.addQuadCurve(to: CGPoint(x: b, y: y), control: CGPoint(x: (a + b) / 2, y: y - 18)) }
            context.stroke(path, with: .color(ink), lineWidth: 1.5)
            context.draw(Text(verbatim: link.mark).font(.system(size: 10, weight: .bold)),
                at: CGPoint(x: (a + b) / 2, y: y - 18))
            }
        }
        for (index, symbol) in symbols.enumerated() {
            guard let step = symbol.engravingStep else { continue }
            let noteY = StaffModel.y(step: step)
            let direction = step < 34 ? 1.0 : -1.0
            let y = noteY + direction * 9
            func tie(from start: Double, to end: Double) {
                guard end > start else { return }
                var path = Path(); path.move(to: CGPoint(x: start, y: y))
                path.addQuadCurve(to: CGPoint(x: end, y: y), control: CGPoint(x: (start + end) / 2, y: y + direction * min(16, (end - start) * 0.2)))
                context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            if symbol.fragment.tieFromPrevious && (index == 0 || symbols[index - 1].eventID != symbol.eventID) {
                tie(from: leading - 5, to: x(symbol) - 8)
            }
            if symbol.fragment.tieToNext {
                let next = symbols.dropFirst(index + 1).first { $0.eventID == symbol.eventID }
                tie(from: x(symbol) + 8, to: next.map { x($0) - 8 } ?? lineEnd - 4)
            }
        }
        if let tick = cursorTick, timeline.cursorBar(tick) == currentBar {
            let cursorX = leading + timeline.x(tick: tick, bar: currentBar, zoom: 1) + 24
            line(CGPoint(x: cursorX, y: 8), CGPoint(x: cursorX, y: StaffModel.canvasHeight - 20), thickness: 2, color: .accentColor)
        }
    }
}
