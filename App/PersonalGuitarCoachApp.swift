import SwiftUI

@main
struct PersonalGuitarCoachApp: App {
    @State private var settings = AppSettings()
    @State private var navigation = AppNavigation()

    var body: some Scene {
        Window(settings.localized("app.name"), id: "main") {
            AppRootView(navigation: navigation)
                .environment(settings)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink { Text(verbatim: settings.localized("settings.title")) }
                    .keyboardShortcut(",")
            }
            CommandMenu(settings.localized("navigation.title")) {
                ForEach(Array(AppDestination.allCases.enumerated()), id: \.element) { index, destination in
                    Button(settings.localized(destination.titleKey)) { navigation.destination = destination }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
                }
            }
        }
        Settings {
            CoachSettingsView()
                .environment(settings)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
