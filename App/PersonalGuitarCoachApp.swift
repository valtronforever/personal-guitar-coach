import SwiftUI
import Persistence

@main
struct PersonalGuitarCoachApp: App {
    @State private var settings = AppSettings()
    @State private var navigation = AppNavigation()
    @State private var localData: LocalDataStore
    @State private var reading: ReadingProgressStore
    @State private var library = LessonLibraryStore()

    init() {
        let repository: LocalRepository?
        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["COACH_UI_TEST_STORAGE"], let id = UUID(uuidString: token) {
            repository = LocalRepository(root: FileManager.default.temporaryDirectory.appendingPathComponent("coach-ui-tests-" + id.uuidString))
        } else { repository = try? LocalRepository.applicationSupport() }
        #else
        repository = try? LocalRepository.applicationSupport()
        #endif
        _localData = State(initialValue: LocalDataStore(repository: repository))
        _reading = State(initialValue: ReadingProgressStore(repository: repository))
    }

    var body: some Scene {
        Window(settings.localized("app.name"), id: "main") {
            AppRootView(navigation: navigation)
                .environment(settings)
                .environment(localData)
                .environment(library)
                .environment(reading)
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
