#if DEBUG
import SwiftUI
import Audio
import Domain

struct TunerFixtureView: View {
    @State private var state = "inTune"
    private let states = ["inTune", "flat", "sharp", "silence", "clipping", "chooseString"]
    private func key(_ state: String) -> String { "tuner.feedback.\(state)" }
    private var reading: TunerReading {
        var tracker = try! TunerTracker(mode: state == "chooseString" ? .automatic : .manual(string: 5))
        let hz = state == "chooseString" ? 329.62756 : 110 * pow(2, (state == "flat" ? -25.0 : state == "sharp" ? 25.0 : 0) / 1200)
        for index in 0...8 { tracker.update(frequency: hz, clarity: 0.99, quality: .reliable, streamTime: Double(index) * 0.05) }
        if state == "silence" || state == "clipping" {
            tracker.update(frequency: nil, clarity: nil, quality: state == "silence" ? .silence : .clipping, streamTime: 0.45)
        }
        return tracker.reading
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("debug.tunerExplanation").foregroundStyle(.secondary)
            Picker("debug.fixture", selection: $state) {
                ForEach(states, id: \.self) { state in Text(LocalizedStringKey(key(state))).tag(state) }
            }.accessibilityIdentifier("debug.tunerState")
            TunerReadingView(reading: reading)
        }.padding(24).frame(minWidth: 600, minHeight: 420)
    }
}
#endif
