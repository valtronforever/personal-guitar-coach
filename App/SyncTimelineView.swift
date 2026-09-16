import SwiftUI

/// Two rows of ten audio-clock beats. Every captured event remains in the diagnostic detail list.
struct SyncTimelineView: View {
    let run: SyncTimelineRun
    var bundle: Bundle = .main
    private let rowHeight = 128.0
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                label("sync.setting." + run.source.rawValue).font(.headline)
                Spacer()
                label("sync.timeline.status." + run.status.rawValue).font(.caption)
            }
            if !run.context.isEmpty { Text(verbatim: run.context).font(.caption).foregroundStyle(.secondary) }
            if run.source == .guitar { Text("sync.timeline.alignment \(Int((run.alignment * 1000).rounded()))", bundle: bundle).font(.caption) }
            GeometryReader { geometry in
                let cell = max(1, (geometry.size.width - 20) / 10)
                Canvas { context, size in
                    for beat in 0..<20 {
                        let row = beat / 10, x = 10 + (Double(beat % 10) + 0.5) * cell, y = Double(row) * rowHeight
                        var line = Path(); line.move(to: CGPoint(x: x, y: y + 22)); line.addLine(to: CGPoint(x: x, y: y + 78))
                        context.stroke(line, with: .color(beat < 4 ? .secondary.opacity(0.4) : .primary.opacity(0.5)), lineWidth: 1)
                        let heading = beat < 4 ? "·\(beat + 1)" : "\(beat - 3)"
                        context.draw(Text(verbatim: heading).font(.system(size: 11, weight: .semibold)), at: CGPoint(x: x, y: y + 11))
                        let events = run.events.filter { run.position($0)?.beat == beat }
                        if events.isEmpty && beat >= 4 && run.status != .running {
                            context.stroke(Path(ellipseIn: CGRect(x: x - 4, y: y + 46, width: 8, height: 8)), with: .color(.secondary), lineWidth: 1)
                        }
                        for (index, event) in events.enumerated() {
                            let delta = run.position(event)!.delta
                            let markerX = x + delta * cell, markerY = y + 50 + Double(index % 3) * 8
                            let color: Color = event.kind == .wrong ? .red : event.kind == .uncertain ? .orange : event.kind == .tap ? .blue : .green
                            var distance = Path(); distance.move(to: CGPoint(x: x, y: markerY)); distance.addLine(to: CGPoint(x: markerX, y: markerY))
                            context.stroke(distance, with: .color(color), lineWidth: 2)
                            if event.kind == .uncertain || event.kind == .wrong {
                                context.draw(Text(verbatim: event.kind == .wrong ? "△" : "?").font(.system(size: 14, weight: .bold)).foregroundColor(color), at: CGPoint(x: markerX, y: markerY))
                            } else {
                                context.fill(Path(ellipseIn: CGRect(x: markerX - 4, y: markerY - 4, width: 8, height: 8)), with: .color(color))
                            }
                        }
                        if !events.isEmpty {
                            for (index, event) in events.prefix(3).enumerated() {
                                let value = Self.signedMilliseconds(run.position(event)!.delta) + (index == 2 && events.count > 3 ? "…" : "")
                                context.draw(Text(verbatim: value).font(.system(size: 10, design: .monospaced)), at: CGPoint(x: x, y: y + 87 + Double(index) * 12))
                            }
                        }
                    }
                    if let cursor = run.cursor, (0..<19.5).contains(cursor) {
                        let beat = min(19, max(0, Int(cursor.rounded()))), row = beat / 10
                        let x = 10 + (Double(beat % 10) + 0.5 + cursor - Double(beat)) * cell
                        var line = Path(); line.move(to: CGPoint(x: x, y: Double(row) * rowHeight + 20)); line.addLine(to: CGPoint(x: x, y: Double(row) * rowHeight + 80))
                        context.stroke(line, with: .color(.accentColor), lineWidth: 2)
                    }
                }
            }.frame(height: rowHeight * 2)
                .accessibilityLabel(label("sync.timeline.diagram"))
            label("sync.timeline.legend").font(.caption).fixedSize(horizontal: false, vertical: true)
            if run.outsideCount > 0 { Text("sync.timeline.outside \(run.outsideCount)", bundle: bundle).font(.caption) }
            DisclosureGroup { details } label: { label("sync.timeline.details") }
                .font(.caption)
        }.padding(12).background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(run.events) { event in
                if let position = run.position(event) {
                    HStack {
                        Text("sync.timeline.event \(Int(event.id)) \(position.beat < 4 ? position.beat + 1 : position.beat - 3) \(Self.signedMilliseconds(position.delta))", bundle: bundle)
                        label(position.beat < 4 ? "sync.timeline.warmup" : "sync.timeline.measured")
                        label("sync.timeline.kind." + event.kind.rawValue)
                    }
                } else if let origin = run.origin {
                    HStack {
                        Text("sync.timeline.outsideEvent \(Int(event.id)) \(Self.signedMilliseconds(event.time - origin - run.alignment))", bundle: bundle)
                        label("sync.timeline.kind." + event.kind.rawValue)
                    }
                } else { Text("sync.timeline.unknownTime \(Int(event.id))", bundle: bundle) }
            }
        }
    }
    private func label(_ key: String) -> Text { Text(LocalizedStringKey(key), bundle: bundle) }
    nonisolated static func signedMilliseconds(_ seconds: Double) -> String {
        guard seconds.isFinite, abs(seconds) < 86400 else { return "—" }
        let value = Int((seconds * 1000).rounded()); return value > 0 ? "+\(value)" : "\(value)"
    }
}
