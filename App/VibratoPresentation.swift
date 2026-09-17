import SwiftUI
import Domain

enum VibratoPresentation {
    static func spoken(_ vibrato: PitchVibrato, pulseTicks: Int64, locale: Locale, localized: (String) -> String) -> String {
        func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2)).locale(locale)) }
        let rate = Double(pulseTicks) / Double(vibrato.periodTicks)
        return String(format: localized("vibrato.spoken %lld %@ %@ %@"), locale: locale, Int64(vibrato.extentCents), number(rate),
            number(Double(vibrato.startTick) / Double(pulseTicks) + 1), number(Double(vibrato.endTick) / Double(pulseTicks) + 1))
    }
    static func span(_ segment: TimelineSegment) -> Range<Int64>? {
        guard let vibrato = segment.resolved.event.vibrato else { return nil }
        let lower = max(segment.startTick, segment.resolved.event.startTick + vibrato.startTick)
        let upper = min(segment.endTick, segment.resolved.event.startTick + vibrato.endTick)
        return lower < upper ? lower..<upper : nil
    }
    /// Conventional wavy technique mark; the detailed curve shows the authored width/rate.
    static func draw(context: inout GraphicsContext, start: Double, end: Double, y: Double) {
        guard end > start else { return }
        let count = min(1000, max(8, Int(end - start)))
        var path = Path()
        for index in 0...count {
            let x = start + (end - start) * Double(index) / Double(count)
            let point = CGPoint(x: x, y: y + 2.5 * sin((x - start) * .pi / 6))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(.primary), lineWidth: 1.5)
    }
}

struct VibratoTabMark: View {
    let segment: TimelineSegment
    let width: Double
    let y: Double
    var body: some View {
        Canvas { context, _ in
            guard let span = VibratoPresentation.span(segment) else { return }
            let scale = width / Double(segment.endTick - segment.startTick)
            VibratoPresentation.draw(context: &context, start: Double(span.lowerBound - segment.startTick) * scale,
                end: Double(span.upperBound - segment.startTick) * scale, y: y)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
