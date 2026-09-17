import SwiftUI

/// Bracket endpoints follow sounding tick geometry; the 3 describes three
/// written eighth-note slots in one quarter beat, including grouped rests.
enum TripletBracket {
    static func draw(context: inout GraphicsContext, start: Double, end: Double, y: Double, scale: Double = 1) {
        guard end > start else { return }
        let center = (start + end) / 2, gap = min(8 * scale, (end - start) / 5)
        var path = Path()
        path.move(to: CGPoint(x: start, y: y + 4 * scale))
        path.addLine(to: CGPoint(x: start, y: y))
        path.addLine(to: CGPoint(x: center - gap, y: y))
        path.move(to: CGPoint(x: center + gap, y: y))
        path.addLine(to: CGPoint(x: end, y: y))
        path.addLine(to: CGPoint(x: end, y: y + 4 * scale))
        context.stroke(path, with: .color(.primary), lineWidth: max(0.75, scale))
        context.draw(Text(verbatim: "3").font(.system(size: 10 * scale, weight: .semibold)), at: CGPoint(x: center, y: y))
    }
}
