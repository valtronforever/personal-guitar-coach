import SwiftUI
import Domain

extension HarmonicNote {
    var notationLabel: String { kind == .natural ? "N.H." : "A.H." }
}

enum HarmonicPresentation {
    static func spoken(event: MusicalEvent, tuning: TuningProfile, locale: Locale, localized: (String) -> String) -> String {
        guard let harmonic = event.harmonic, let position = event.positions.first,
              let touch = try? harmonic.touchPosition(from: position),
              let pitch = try? event.soundingPitches(in: tuning).first else { return "" }
        let name = pitch.name(spelling: tuning.preferredSpelling)
        if harmonic.kind == .natural {
            return String(format: localized("harmonic.natural.spoken %lld %lld %@"), locale: locale, Int64(position.string), Int64(touch.fret), name)
        }
        return String(format: localized("harmonic.artificial.spoken %lld %lld %lld %@"), locale: locale, Int64(position.string), Int64(position.fret), Int64(touch.fret), name)
    }
}

struct HarmonicTabContent: View {
    let event: MusicalEvent
    let width: Double
    let gridTop: Double
    let stringSpacing: Double
    var zoom = 1.0
    var compact = false
    var body: some View {
        if let harmonic = event.harmonic, let position = event.positions.first,
           let touch = try? harmonic.touchPosition(from: position) {
            VStack(spacing: 0) {
                if harmonic.kind == .artificial {
                    Text(verbatim: "⟨\(touch.fret)⟩").font(.system(size: (compact ? 9 : 11) * zoom, weight: .semibold, design: .monospaced))
                }
                Text(verbatim: harmonic.kind == .natural ? "⟨\(touch.fret)⟩" : String(position.fret))
                    .font(.system(size: (compact ? 12 : 15) * zoom, weight: .bold, design: .monospaced))
            }
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(width: max(16, min(width - 2, 48 * zoom)))
            .background(.background, in: RoundedRectangle(cornerRadius: 3))
            .position(x: min(width / 2, (compact ? 19 : 26) * zoom), y: gridTop + (Double(position.string) - 0.5) * stringSpacing - (harmonic.kind == .artificial ? 5 * zoom : 0))
            .accessibilityHidden(true)
        }
    }
}
