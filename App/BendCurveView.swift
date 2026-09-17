import SwiftUI
import Domain

/// Frozen target and optional measured input. Gaps remain gaps, never interpolated silence.
struct BendCurveView: View {
    let event: MusicalEvent
    var bpm: Double = 60
    var pulseTicks: Int64 = MusicalTime.ppq
    var frames: [SustainFrame] = []
    var normalizedStart: Double? = nil
    var baseFrequency: Double? = nil
    var localizationBundle: Bundle = .main

    var body: some View {
        if let bend = event.bend {
            VStack(alignment: .leading, spacing: 8) {
                Text("bend.curveTitle", bundle: localizationBundle).font(.headline)
                HStack(spacing: 20) {
                    Label { Text("bend.expected", bundle: localizationBundle) } icon: { Image(systemName: "line.diagonal") }.foregroundStyle(.secondary)
                    if normalizedStart != nil { Label { Text("bend.observed", bundle: localizationBundle) } icon: { Image(systemName: "waveform.path") }.foregroundStyle(Color.accentColor) }
                }.font(.caption)
                Canvas { context, size in
                    let left = 48.0, top = 16.0, width = max(1, size.width - left - 16), height = max(1, size.height - top - 32)
                    let duration = Double(event.durationTicks) / Double(pulseTicks)
                    let selected: [SustainFrame]
                    if let start = normalizedStart { selected = frames.filter { $0.normalizedTime >= start && $0.normalizedTime <= start + duration * 60 / bpm } }
                    else { selected = [] }
                    let observed = selected.compactMap { frame -> Double? in
                        guard let hz = frame.frequency, let base = baseFrequency else { return nil }
                        return 1200 * (log2(hz) - log2(base))
                    }
                    let lower = floor(min(-50, observed.min() ?? 0) / 50) * 50
                    let upper = ceil(max(Double(bend.semitones * 100 + 50), observed.max() ?? 0) / 50) * 50
                    func point(beat: Double, cents: Double) -> CGPoint {
                        CGPoint(x: left + min(duration, max(0, beat)) / duration * width,
                                y: top + (upper - min(upper, max(lower, cents))) / (upper - lower) * height)
                    }
                    for value in [lower, 0, Double(bend.semitones * 100), upper] {
                        var line = Path(); line.move(to: point(beat: 0, cents: value)); line.addLine(to: point(beat: duration, cents: value))
                        context.stroke(line, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
                        context.draw(Text(verbatim: String(Int(value))).font(.caption2.monospacedDigit()), at: CGPoint(x: left - 8, y: point(beat: 0, cents: value).y), anchor: .trailing)
                    }
                    let step = max(1, Int(ceil(duration / 6)))
                    for beat in stride(from: 0, through: Int(ceil(duration)), by: step) where Double(beat) <= duration {
                        let x = point(beat: Double(beat), cents: 0).x
                        var line = Path(); line.move(to: CGPoint(x: x, y: top)); line.addLine(to: CGPoint(x: x, y: top + height))
                        context.stroke(line, with: .color(.secondary.opacity(0.2)), lineWidth: 1)
                        context.draw(Text(verbatim: String(beat + 1)).font(.caption2.monospacedDigit()), at: CGPoint(x: x, y: top + height + 14))
                    }
                    var target = Path()
                    for (index, p) in bend.points(durationTicks: event.durationTicks).enumerated() {
                        let value = point(beat: Double(p.tick) / Double(pulseTicks), cents: p.cents)
                        if index == 0 { target.move(to: value) } else { target.addLine(to: value) }
                    }
                    context.stroke(target, with: .color(.primary), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    if let start = normalizedStart, let base = baseFrequency {
                        var path = Path(), previous: SustainFrame?
                        // Bounded drawing, preserving gaps even when a long note is downsampled.
                        let strideSize = max(1, selected.count / 2000)
                        var gap = true
                        for (index, frame) in selected.enumerated() {
                            guard frame.state == .pitched, let hz = frame.frequency else { gap = true; previous = nil; continue }
                            if index % strideSize != 0 && index != selected.count - 1 { continue }
                            let p = point(beat: (frame.normalizedTime - start) * bpm / 60, cents: 1200 * (log2(hz) - log2(base)))
                            if gap || previous == nil { path.move(to: p) } else { path.addLine(to: p) }
                            previous = frame; gap = false
                        }
                        context.stroke(path, with: .color(.accentColor), lineWidth: 2)
                    }
                }.frame(height: 210).accessibilityHidden(true)
                Text("bend.axes", bundle: localizationBundle).font(.caption).foregroundStyle(.secondary)
                Text("bend.targetSemitones \(bend.semitones)", bundle: localizationBundle).font(.caption)
                if normalizedStart != nil { Text("bend.traceGaps", bundle: localizationBundle).font(.caption).foregroundStyle(.secondary) }
            }.accessibilityElement(children: .contain)
        }
    }
}

struct BendResultView: View {
    let result: AssessedPractice
    let note: BendNoteAssessment
    var body: some View {
        if let event = result.evidence.configuration.selectedEvents.first(where: { $0.id == note.id }),
           let assessed = result.notes.first(where: { $0.id == note.id }) {
            GroupBox("bend.resultTitle") {
                VStack(alignment: .leading, spacing: 12) {
                    BendCurveView(event: event, bpm: result.evidence.configuration.bpm, pulseTicks: result.evidence.configuration.exercise.timeSignature.pulseTicks,
                        frames: result.evidence.pitchContour?.frames ?? [], normalizedStart: note.normalizedStart, baseFrequency: assessed.targetFrequency)
                    ForEach(note.phases, id: \.kind) { phase in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("bend.phase." + phase.kind.rawValue)).font(.headline)
                            if let matched = phase.matchedFraction, result.bendScore != nil {
                                Text("bend.matched \(Int((matched * 100).rounded()))")
                                if let cents = phase.medianErrorCents { Text("bend.error \(Int(cents.rounded()))") }
                            } else { Text("bend.unavailable") }
                            Text("bend.coverage \(Int((phase.silentFraction * 100).rounded())) \(Int((phase.unknownFraction * 100).rounded()))").font(.caption)
                        }.accessibilityElement(children: .combine)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("bend.result")
        }
    }
}
