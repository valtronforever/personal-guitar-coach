import SwiftUI
import Persistence

@main
struct PersonalGuitarCoachApp: App {
    @State private var settings = AppSettings()
    @State private var navigation = AppNavigation()
    @State private var localData: LocalDataStore
    @State private var reading: ReadingProgressStore
    @State private var audio: AudioSessionStore
    @State private var calibration: CalibrationStore
    @State private var assessment: AssessmentStore
    @State private var practice: PracticeModel
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
        let data = LocalDataStore(repository: repository)
        let audio = AudioSessionStore(repository: repository)
        let calibration = CalibrationStore(repository: repository)
        let practice = PracticeModel(audio: audio, calibration: calibration)
        let assessment = AssessmentStore(repository: repository)
        practice.onAttemptFinished = { [weak practice, weak assessment, weak data] evidence in
            guard let assessment else { practice?.setRepeat(false); return }
            if await !assessment.receive(evidence) { practice?.setRepeat(false) }
            await data?.refreshHistory()
        }
        _assessment = State(initialValue: assessment)
        data.instrumentWillChange = { [weak practice] value in practice?.instrumentWillChange(value) }
        _localData = State(initialValue: data)
        _reading = State(initialValue: ReadingProgressStore(repository: repository))
        _audio = State(initialValue: audio)
        _calibration = State(initialValue: calibration)
        _practice = State(initialValue: practice)
    }

    var body: some Scene {
        Window(settings.localized("app.name"), id: "main") {
            AppRootView(navigation: navigation)
                .environment(settings)
                .environment(localData)
                .environment(library)
                .environment(reading)
                .environment(audio)
                .environment(calibration)
                .environment(practice)
                .environment(assessment)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task { await localData.reload() }
                .task { audio.activate() }
                .task { await calibration.load() }
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
        Window(settings.localized("debug.assessmentTitle"), id: "assessment-fixtures") {
            AssessmentFixtureView().environment(settings).environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
        }.defaultSize(width: 540, height: 620)
        Window(settings.localized("debug.tunerTitle"), id: "tuner-fixtures") {
            TunerFixtureView().environment(settings).environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
        }.defaultSize(width: 680, height: 500)
        #endif
        Settings {
            CoachSettingsView()
                .environment(settings)
                .environment(localData)
                .environment(audio)
                .environment(calibration)
                .environment(practice)
                .environment(assessment)
                .environment(\.locale, settings.locale)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}
