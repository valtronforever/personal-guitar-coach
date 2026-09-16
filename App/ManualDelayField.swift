import SwiftUI

/// Explicit field chrome overrides the grouped Form's otherwise borderless presentation.
struct ManualDelayField: View {
    @Binding var value: String
    let identifier: String
    let enabled: Bool
    var bundle: Bundle = .main

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("", text: $value)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .font(.body.monospacedDigit())
                .accessibilityLabel(Text("sync.manual.milliseconds", bundle: bundle))
                .accessibilityIdentifier(identifier)
                .disabled(!enabled)
            Text("sync.manual.placeholder", bundle: bundle).font(.caption).foregroundStyle(.secondary)
        }.frame(width: 150, alignment: .leading)
    }
}
