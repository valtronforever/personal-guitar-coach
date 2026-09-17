import SwiftUI
import Domain

enum MutedAttackPresentation {
    static func spoken(_ attack: MutedStringAttack, locale: Locale, localized: (String) -> String) -> String {
        String(format: localized("mutedAttack.spoken %@"), locale: locale, attack.strings.map(String.init).joined(separator: ", "))
    }
}

struct MutedAttackTabContent: View {
    let attack: MutedStringAttack
    let width: Double
    let gridTop: Double
    let stringSpacing: Double
    var zoom = 1.0
    var compact = false
    var body: some View {
        ForEach(attack.strings, id: \.self) { string in
            Text(verbatim: "×").font(.system(size: (compact ? 14 : 17) * zoom, weight: .bold, design: .monospaced))
                .frame(width: max(1, min(width, 20 * zoom)), height: 18 * zoom)
                .background(.background, in: RoundedRectangle(cornerRadius: 3))
                .position(x: min(width / 2, (compact ? 8 : 22) * zoom), y: gridTop + (Double(string) - 0.5) * stringSpacing)
                .accessibilityHidden(true)
        }
    }
}
