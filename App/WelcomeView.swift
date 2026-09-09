import SwiftUI
import Domain

struct WelcomeView: View {
    let defaultSource: InputSource

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "guitars.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("app.name")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("app.title")
            Text("welcome.subtitle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Label(sourceTitle, systemImage: "cable.connector")
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            Text("welcome.acoustic")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .contain)
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 720, minHeight: 480)
    }

    private var sourceTitle: LocalizedStringKey {
        switch defaultSource {
        case .electricInterface: "source.electric"
        case .acousticMicrophone: "source.microphone"
        case .acousticPickup: "source.pickup"
        }
    }
}
