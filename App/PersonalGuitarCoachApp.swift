import SwiftUI

@main
struct PersonalGuitarCoachApp: App {
    @State private var settings = AppSettings()
    @State private var navigation = AppNavigation()
    @State private var localData = LocalDataStore()
    @State private var library = LessonLibraryStore()

    var body: some Scene {
        Window(settings.localized("app.name"), id: "main") {
            AppRootView(navigation: navigation)
                .environment(settings)
                .environment(localData)
                .environment(library)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task { await localData.reload() }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            #if DEBUG
            VisualFixtureCommands(settings: settings)
            #endif
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
        #if DEBUG
        Window(settings.localized("debug.visualTitle"), id: "visual-fixtures") {
            VisualFixtureView().environment(settings).environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
        }.defaultSize(width: 800, height: 640)
        #endif
        Settings {
            CoachSettingsView()
                .environment(settings)
                .environment(localData)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
