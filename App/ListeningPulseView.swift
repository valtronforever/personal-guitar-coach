import SwiftUI
import Domain

/// Only the metronome pulse is visible: no event positions, note counts, durations or rests.
struct ListeningPulseView: View {
    let exercise: Exercise
    let displayTick: Double?
    var localizationBundle: Bundle? = nil
    var pulse: Int? {
        guard let displayTick, displayTick.isFinite else { return nil }
        let beats = exercise.timeSignature.beatsPerBar
        let raw = Int(floor(displayTick / Double(exercise.timeSignature.pulseTicks)).truncatingRemainder(dividingBy: Double(beats)))
        return ((raw % beats) + beats) % beats
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label { Text("listening.hidden", bundle: localizationBundle) } icon: { Image(systemName: "ear") }
            HStack(spacing: 12) {
                ForEach(0..<exercise.timeSignature.beatsPerBar, id: \.self) { index in
                    Text(index + 1, format: .number).font(.title2.monospacedDigit())
                        .frame(width: 42, height: 42)
                        .background(pulse == index ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08), in: Circle())
                        .overlay(Circle().strokeBorder(pulse == index ? Color.primary : Color.clear, lineWidth: 2))
                }
            }.accessibilityHidden(true)
            Text("listening.pulseOnly", bundle: localizationBundle).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .accessibilityElement(children: .combine).accessibilityIdentifier("listening.hiddenTargets")
    }
}
