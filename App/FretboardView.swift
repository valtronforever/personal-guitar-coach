import SwiftUI
import Domain

/// Canvas is decorative; native buttons provide hit targets, focus and VoiceOver for every position.
struct FretboardView: View {
    let model: FretboardModel
    @Binding var selected: FretPosition?
    var detectedPitch: Pitch? = nil
    @FocusState private var focused: FretPosition?
    @State private var hovered: FretPosition?
    @State private var jumpFret = 0
    private let columnWidth: CGFloat = 68
    private let rowHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("fretboard.title").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                TuningName(profile: model.tuning).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label("fretboard.expected", systemImage: "circle")
                Label("fretboard.selected", systemImage: "square")
                Text("fretboard.openMuted")
            }.font(.caption)
            ScrollViewReader { proxy in
                HStack {
                    Picker("fretboard.jump", selection: $jumpFret) {
                        ForEach(0...24, id: \.self) { fret in Text("fretboard.fret \(fret)").tag(fret) }
                    }.frame(maxWidth: 230).accessibilityIdentifier("fretboard.jump")
                    Button("fretboard.show") { proxy.scrollTo(jumpFret, anchor: .center) }
                    Spacer()
                    Button("fretboard.clear") { selected = nil }.disabled(selected == nil)
                }
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 28)
                        ForEach(1...6, id: \.self) { string in
                            Text(verbatim: String(string)).font(.caption.monospacedDigit())
                                .frame(width: 24, height: rowHeight).accessibilityHidden(true)
                        }
                    }.frame(width: 24)
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(model.frets, id: \.self) { fret in
                                VStack(spacing: 0) {
                                    Text(verbatim: String(fret)).font(.caption.monospacedDigit())
                                        .frame(height: 24).accessibilityHidden(true)
                                    ZStack {
                                        fretBackground(fret: fret)
                                        VStack(spacing: 0) {
                                            ForEach(model.positions(fret: fret), id: \.self) { position in
                                                positionButton(position)
                                            }
                                        }
                                    }
                                    Text(verbatim: [12, 24].contains(fret) ? "••" : ([3, 5, 7, 9, 15, 17, 19, 21].contains(fret) ? "•" : " "))
                                        .frame(height: 20).accessibilityHidden(true)
                                }.frame(width: columnWidth).id(fret)
                            }
                        }.padding(.vertical, 4)
                    }
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("fretboard.grid")
                    .onAppear { proxy.scrollTo(selected?.fret ?? model.expected.map(\.fret).min() ?? 0, anchor: .center) }
                    .onChange(of: model.orientation) { _, _ in proxy.scrollTo(selected?.fret ?? model.expected.map(\.fret).min() ?? 0, anchor: .center) }
                    .onChange(of: model.expected) { _, positions in
                        if let first = positions.sorted(by: { $0.fret == $1.fret ? $0.string < $1.string : $0.fret < $1.fret }).first {
                            proxy.scrollTo(first.fret, anchor: .center)
                        }
                    }
                    .onChange(of: selected) { _, position in if let position { proxy.scrollTo(position.fret, anchor: .center) } }
                    .onChange(of: focused) { _, position in if let position { proxy.scrollTo(position.fret, anchor: .center) } }
                    .onMoveCommand { direction in
                        guard let current = focused else { return }
                        switch direction {
                        case .left: focused = model.neighbor(of: current, horizontal: -1)
                        case .right: focused = model.neighbor(of: current, horizontal: 1)
                        case .up: focused = model.neighbor(of: current, vertical: -1)
                        case .down: focused = model.neighbor(of: current, vertical: 1)
                        default: break
                        }
                    }
                }
            }
            if let position = hovered ?? focused ?? selected {
                description(position).font(.callout).accessibilityIdentifier("fretboard.description")
            } else { Text("fretboard.instructions").font(.callout).foregroundStyle(.secondary) }
            if let detectedPitch {
                Label { Text("fretboard.detected \(detectedPitch.name())") } icon: { Image(systemName: "waveform") }
                Text("fretboard.detectedExplanation").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func positionButton(_ position: FretPosition) -> some View {
        let expected = model.expected.contains(position)
        let chosen = selected == position
        let muted = model.isMuted(position)
        let visible = expected || chosen || focused == position || hovered == position || muted
        return Button {
            selected = position
            focused = position
        } label: {
            ZStack {
                if chosen { RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.primary, lineWidth: 2)) }
                if expected { Circle().fill(.background).overlay(Circle().strokeBorder(.primary, lineWidth: 2)).padding(.horizontal, 11) }
                VStack(spacing: 0) {
                    if muted { Text(verbatim: "×").font(.title2.bold()) }
                    else if visible {
                        Text(verbatim: model.pitch(at: position)?.name() ?? "—").font(.caption.bold().monospaced())
                        if position.fret == 0 { Text(verbatim: "○").font(.caption2) }
                        else if let finger = model.finger(at: position) { Text("fretboard.finger \(finger)").font(.system(size: 9)) }
                    }
                }
            }.frame(width: columnWidth - 4, height: rowHeight - 4).contentShape(Rectangle())
                .frame(width: columnWidth, height: rowHeight)
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focused, equals: position)
        .onKeyPress(keys: [.space, .return]) { _ in selected = position; return .handled }
        .onHover { active in if active { hovered = position } else if hovered == position { hovered = nil } }
        .help(description(position))
        .accessibilityLabel(description(position))
        .accessibilityValue(Text(LocalizedStringKey(stateKey(expected: expected, selected: chosen))))
        .accessibilityHint(fingerHint(position))
        .accessibilityIdentifier("fretboard.string.\(position.string).fret.\(position.fret)")
    }

    private func description(_ position: FretPosition) -> Text {
        if model.isMuted(position) { return Text("fretboard.mutedPosition \(position.string)") }
        let name = model.pitch(at: position)?.name() ?? "—"
        if position.fret == 0 { return Text("fretboard.openPosition \(position.string) \(name)") }
        return Text("fretboard.position \(position.string) \(position.fret) \(name)")
    }
    private func fingerHint(_ position: FretPosition) -> Text {
        if let finger = model.finger(at: position) { Text("fretboard.fingerHint \(finger)") }
        else { Text("fretboard.selectHint") }
    }
    private func stateKey(expected: Bool, selected: Bool) -> String {
        if expected && selected { return "fretboard.expectedSelected" }
        if expected { return "fretboard.expected" }
        return selected ? "fretboard.selected" : "fretboard.unmarked"
    }

    private func fretBackground(fret: Int) -> some View {
        Canvas { context, size in
            for string in 1...6 {
                let y = (CGFloat(string) - 0.5) * rowHeight
                var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.secondary.opacity(0.55)), lineWidth: 0.6 + CGFloat(string) * 0.18)
            }
            let right = model.orientation == .rightHanded
            // Nut lies between the open-string column and fret one.
            let x: CGFloat = right ? size.width - 1 : 1
            var boundary = Path(); boundary.move(to: CGPoint(x: x, y: 0)); boundary.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(boundary, with: .color(.secondary), lineWidth: fret == 0 ? 5 : 1)
        }.frame(height: rowHeight * 6).accessibilityHidden(true)
    }
}
