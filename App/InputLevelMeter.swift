import SwiftUI
import Audio

/// One dBFS scale shared by setup, synchronization and practice preflight.
struct InputLevelMeter: View {
    @Environment(\.locale) private var locale
    let snapshot: CaptureSnapshot?
    let active: Bool
    var localizationBundle: Bundle = .main
    private var reading: InputLevelReading { InputLevelReading(snapshot: snapshot, active: active) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                text("audio.level").font(.headline)
                Spacer()
                text("audio.meter.peak")
                decibels(reading.peakDB)
            }.font(.caption)
            scale.accessibilityHidden(true)
            HStack {
                label("audio.meter.zone.weak", icon: "minus.circle")
                Spacer(minLength: 8)
                label("audio.meter.zone.good", icon: "checkmark.circle")
                Spacer(minLength: 8)
                label("audio.meter.zone.high", icon: "exclamationmark.triangle")
            }.font(.caption)
            HStack {
                label(reading.statusKey, icon: statusIcon)
                    .font(.callout.bold())
                Spacer()
                text("audio.rmsDB").font(.caption)
                decibels(reading.rmsDB).font(.caption)
            }
            text(reading.hintKey).font(.caption)
            text("audio.meter.guidance").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("audio.levelMeter")
    }

    private var scale: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let low = InputLevelReading.fraction(for: InputLevelReading.recommendedDB)
            let high = InputLevelReading.fraction(for: InputLevelReading.highDB)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    Color.secondary.opacity(0.25).frame(width: width * low)
                    Color.green.opacity(0.35).frame(width: width * (high - low))
                    Color.orange.opacity(0.45)
                }.frame(height: 14).clipShape(RoundedRectangle(cornerRadius: 3))
                // A contrasting fill and triangular cursor keep the reading legible without color.
                Rectangle().fill(Color.primary.opacity(0.65))
                    .frame(width: width * reading.fraction, height: 4).offset(y: 5)
                if reading.peakDB != nil {
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9))
                        .offset(x: min(width - 9, max(0, width * reading.fraction - 4.5)), y: -7)
                }
                ForEach([-60, -30, -6, 0], id: \.self) { value in
                    let fraction = InputLevelReading.fraction(for: Double(value))
                    Rectangle().fill(Color.primary).frame(width: 1, height: 17)
                        .offset(x: min(width - 1, width * fraction))
                    Text(verbatim: "\(value)").font(.caption2.monospacedDigit())
                        .frame(width: 30)
                        .offset(x: min(width - 30, max(0, width * fraction - 15)), y: 19)
                }
            }
        }.frame(height: 36).padding(.top, 7)
    }

    private func decibels(_ value: Double?) -> some View {
        Group {
            if let value { Text("audio.meter.db \(value.formatted(.number.locale(locale).precision(.fractionLength(1))))", bundle: localizationBundle) }
            else { Text(verbatim: reading.state == .silent ? "−∞ dBFS" : "—") }
        }.monospacedDigit()
    }

    private func text(_ key: String) -> Text {
        Text(LocalizedStringKey(key), bundle: localizationBundle)
    }

    private func label(_ key: String, icon: String) -> some View {
        Label { text(key) } icon: { Image(systemName: icon) }
    }

    private var statusIcon: String {
        switch reading.state {
        case .good: "checkmark.circle"
        case .high, .clipping, .unavailable: "exclamationmark.triangle"
        case .inactive: "pause.circle"
        case .silent, .weak: "minus.circle"
        }
    }
}
