import SwiftUI

/// Keeps the value, unit and apply action together inside a grouped Form.
struct ManualDelayField: View {
    @Binding var value: String
    let identifier: String
    let enabled: Bool
    let canApply: Bool
    let applyLabel: LocalizedStringKey
    let applyIdentifier: String
    let onApply: () -> Void
    var bundle: Bundle = .main

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("sync.manual.value", bundle: bundle).font(.subheadline.weight(.medium))
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    TextField("", text: $value)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 112)
                        .accessibilityLabel(Text("sync.manual.milliseconds", bundle: bundle))
                        .accessibilityIdentifier(identifier)
                        .disabled(!enabled)
                    Text("sync.manual.unit", bundle: bundle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Button(action: onApply) {
                    Text("sync.manual.apply", bundle: bundle)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Text(applyLabel, bundle: bundle))
                .accessibilityIdentifier(applyIdentifier)
                .help(Text(applyLabel, bundle: bundle))
                .disabled(!enabled || !canApply)
            }.controlSize(.large)
            Text("sync.manual.placeholder", bundle: bundle)
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
