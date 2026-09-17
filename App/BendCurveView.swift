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

    private var targetPoints: [(tick: Double, cents: Double)] {
        if let bend = event.bend { return bend.points(durationTicks: event.durationTicks).map { (Double($0.tick), $0.cents) } }
        if let transition = event.pitchTransition {
            return [(0, 0), (Double(transition.startTick), 0), (Double(transition.endTick), Double(transition.semitones * 100)), (Double(event.durationTicks), Double(transition.semitones * 100))]
        }
        if let chain = event.legatoChain {
            let offsets = chain.semitoneOffsets
            var points: [(Double, Double)] = [(0, 0)]
            for (index, target) in chain.targets.enumerated() {
                points += [(Double(target.startTick), Double(offsets[index] * 100)), (Double(target.startTick), Double(offsets[index + 1] * 100))]
            }
            points.append((Double(event.durationTicks), Double(offsets.last! * 100)))
            return points
        }
        if let vibrato = event.vibrato {
            let count = Int(min(2048, max(64, Double(vibrato.cycles) * 32)))
            return [(0, 0)] + (0...count).map { index in
                let tick = Double(vibrato.startTick) + Double(vibrato.endTick - vibrato.startTick) * Double(index) / Double(count)
                return (tick, vibrato.cents(at: tick))
            } + [(Double(event.durationTicks), 0)]
        }
        return []
    }
    private var targetCents: Double { Double(event.vibrato?.extentCents ?? ((event.bend?.semitones ?? event.pitchTransition?.semitones ?? 0) * 100)) }
    var body: some View {
        if !targetPoints.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey(event.legatoChain != nil ? "legato.curveTitle" : event.vibrato != nil ? "vibrato.curveTitle" : event.pitchTransition == nil ? "bend.curveTitle" : "transition.curveTitle"), bundle: localizationBundle).font(.headline)
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
                    let lower = floor(min(-50, (targetPoints.map(\.cents).min() ?? 0) - 50, observed.min() ?? 0) / 50) * 50
                    let upper = ceil(max(50, (targetPoints.map(\.cents).max() ?? 0) + 50, observed.max() ?? 0) / 50) * 50
                    func point(beat: Double, cents: Double) -> CGPoint {
                        CGPoint(x: left + min(duration, max(0, beat)) / duration * width,
                                y: top + (upper - min(upper, max(lower, cents))) / (upper - lower) * height)
                    }
                    for value in Set([lower, 0, targetCents, upper] + (event.legatoChain?.semitoneOffsets.map { Double($0 * 100) } ?? [])).sorted() {
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
                    for (index, p) in targetPoints.enumerated() {
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
                Text(LocalizedStringKey(event.pitchTransition == nil && event.legatoChain == nil ? "bend.axes" : "transition.axes"), bundle: localizationBundle).font(.caption).foregroundStyle(.secondary)
                if let bend = event.bend { Text("bend.targetSemitones \(bend.semitones)", bundle: localizationBundle).font(.caption) }
                if let transition = event.pitchTransition {
                    Text(LocalizedStringKey("transition.kind." + transition.kind.rawValue), bundle: localizationBundle).font(.caption)
                    Text("transition.curveExplanation", bundle: localizationBundle).font(.caption).foregroundStyle(.secondary)
                }
                if let vibrato = event.vibrato {
                    Text("vibrato.targetWidth \(vibrato.extentCents)", bundle: localizationBundle).font(.caption)
                    Text("vibrato.curveExplanation", bundle: localizationBundle).font(.caption).foregroundStyle(.secondary)
                }
                if event.legatoChain != nil { Text("legato.assessmentLimits", bundle: localizationBundle).font(.caption).foregroundStyle(.secondary) }
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

struct PitchTransitionResultView: View {
    let result: AssessedPractice
    let note: PitchTransitionNoteAssessment
    var body: some View {
        if let event = result.evidence.configuration.selectedEvents.first(where: { $0.id == note.id }),
           let assessed = result.notes.first(where: { $0.id == note.id }) {
            GroupBox("transition.resultTitle") {
                VStack(alignment: .leading, spacing: 12) {
                    BendCurveView(event: event, bpm: result.evidence.configuration.bpm, pulseTicks: result.evidence.configuration.exercise.timeSignature.pulseTicks,
                        frames: result.evidence.pitchContour?.frames ?? [], normalizedStart: note.normalizedStart, baseFrequency: assessed.targetFrequency)
                    ForEach(note.phases, id: \.kind) { phase in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("transition.phase." + phase.kind.rawValue)).font(.headline)
                            if let matched = phase.matchedFraction, result.pitchTransitionScore != nil {
                                Text("bend.matched \(Int((matched * 100).rounded()))")
                                if let cents = phase.medianErrorCents { Text("bend.error \(Int(cents.rounded()))") }
                            } else { Text("bend.unavailable") }
                            Text("bend.coverage \(Int((phase.silentFraction * 100).rounded())) \(Int((phase.unknownFraction * 100).rounded()))").font(.caption)
                        }.accessibilityElement(children: .combine)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("transition.result")
        }
    }
}

struct VibratoResultView: View {
    let result: AssessedPractice
    let note: VibratoNoteAssessment
    var body: some View {
        if let event = result.evidence.configuration.selectedEvents.first(where: { $0.id == note.id }),
           let assessed = result.notes.first(where: { $0.id == note.id }) {
            GroupBox("vibrato.resultTitle") {
                VStack(alignment: .leading, spacing: 12) {
                    BendCurveView(event: event, bpm: result.evidence.configuration.bpm, pulseTicks: result.evidence.configuration.exercise.timeSignature.pulseTicks,
                        frames: result.evidence.pitchContour?.frames ?? [], normalizedStart: note.normalizedStart, baseFrequency: assessed.targetFrequency)
                    if result.vibratoScore != nil {
                        if let width = note.modulation.widthCents { Text("vibrato.measuredWidth \(Int(width.rounded()))") }
                        if let rate = note.modulation.rateHz { Text("vibrato.measuredRate \(rate, format: .number.precision(.fractionLength(2)))") }
                        if let slowest = note.modulation.slowestRateHz, let fastest = note.modulation.fastestRateHz {
                            Text("vibrato.measuredRateRange \(slowest, format: .number.precision(.fractionLength(2))) \(fastest, format: .number.precision(.fractionLength(2)))")
                        }
                        if let variation = note.modulation.periodVariation { Text("vibrato.measuredVariation \(Int((variation * 100).rounded()))") }
                        Text("vibrato.measuredPeriods \(note.modulation.measuredPeriods)").font(.caption)
                    }
                    ForEach(note.phases, id: \.kind) { phase in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("vibrato.phase." + phase.kind.rawValue)).font(.headline)
                            if let matched = phase.matchedFraction, result.vibratoScore != nil {
                                Text("bend.matched \(Int((matched * 100).rounded()))")
                                if let cents = phase.medianErrorCents { Text("bend.error \(Int(cents.rounded()))") }
                            } else { Text("bend.unavailable") }
                            Text("bend.coverage \(Int((phase.silentFraction * 100).rounded())) \(Int((phase.unknownFraction * 100).rounded()))").font(.caption)
                        }.accessibilityElement(children: .combine)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("vibrato.result")
        }
    }
}

struct LegatoChainResultView: View {
    let result: AssessedPractice
    let note: LegatoChainNoteAssessment
    var body: some View {
        if let event = result.evidence.configuration.selectedEvents.first(where: { $0.id == note.id }),
           let assessed = result.notes.first(where: { $0.id == note.id }) {
            GroupBox("legato.resultTitle") {
                VStack(alignment: .leading, spacing: 12) {
                    BendCurveView(event: event, bpm: result.evidence.configuration.bpm, pulseTicks: result.evidence.configuration.exercise.timeSignature.pulseTicks,
                        frames: result.evidence.pitchContour?.frames ?? [], normalizedStart: note.normalizedStart, baseFrequency: assessed.targetFrequency)
                    ForEach(note.phases.indices, id: \.self) { index in
                        let phase = note.phases[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text("legato.phase \(index + 1)").font(.headline)
                            if let matched = phase.matchedFraction, result.legatoChainScore != nil {
                                Text("bend.matched \(Int((matched * 100).rounded()))")
                                if let cents = phase.medianErrorCents { Text("bend.error \(Int(cents.rounded()))") }
                            } else { Text("bend.unavailable") }
                            Text("bend.coverage \(Int((phase.silentFraction * 100).rounded())) \(Int((phase.unknownFraction * 100).rounded()))").font(.caption)
                        }.accessibilityElement(children: .combine)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("legato.result")
        }
    }
}
