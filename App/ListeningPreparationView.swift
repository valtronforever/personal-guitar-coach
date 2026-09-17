import SwiftUI

struct ListeningPreparationView: View {
    let playing: Bool
    let busy: Bool
    let hidesTargets: Bool
    let referenceCompleted: Bool
    let outputAvailable: Bool
    let onListen: () -> Void
    let onReveal: () -> Void
    var localizationBundle: Bundle? = nil
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("listening.instructions", bundle: localizationBundle).fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack { listenButton; revealButton }
                    VStack(alignment: .leading, spacing: 8) { listenButton; revealButton }
                }
                if playing { ProgressView { Text("listening.playing", bundle: localizationBundle) } }
                else if !hidesTargets { Label { Text("listening.guided", bundle: localizationBundle) } icon: { Image(systemName: "eye") } }
                else if referenceCompleted { Label { Text("listening.ready", bundle: localizationBundle) } icon: { Image(systemName: "checkmark.circle") } }
                else { Text("listening.prepareFirst", bundle: localizationBundle).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
        } label: { Text("listening.title", bundle: localizationBundle).font(.headline) }
    }
    private var listenButton: some View {
        Button(action: onListen) { Label { Text("listening.playReference", bundle: localizationBundle) } icon: { Image(systemName: "play.fill") } }
            .disabled(busy || playing || !outputAvailable).accessibilityIdentifier("listening.playReference")
    }
    private var revealButton: some View {
        Button(action: onReveal) { Text("listening.reveal", bundle: localizationBundle) }
            .disabled(busy || playing || !hidesTargets).accessibilityIdentifier("listening.reveal")
    }
}
