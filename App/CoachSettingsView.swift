import SwiftUI

struct CoachSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var showsAudio = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("settings.general") {
                Picker("settings.language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.titleKey)).tag(language)
                    }
                }.accessibilityIdentifier("settings.language")
                Picker("settings.appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(LocalizedStringKey(appearance.titleKey)).tag(appearance)
                    }
                }.accessibilityIdentifier("settings.appearance")
                Text("settings.languageExplanation").font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("audio.title") {
                Text("source.electric")
                Text("welcome.acoustic").foregroundStyle(.secondary)
                Button("audio.title") { showsAudio = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 420)
        .background(NativeWindowTitle(title: settings.localized("settings.title")))
        .sheet(isPresented: $showsAudio) { AudioProbeView().environment(\.locale, settings.locale) }
    }
}

// The Settings scene doesn't apply navigationTitle to its native window.
private struct NativeWindowTitle: NSViewRepresentable {
    let title: String
    func makeNSView(context: Context) -> TitleView { TitleView() }
    func updateNSView(_ view: TitleView, context: Context) { view.title = title }

    final class TitleView: NSView {
        var title = "" { didSet { window?.title = title } }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.title = title
        }
    }
}
