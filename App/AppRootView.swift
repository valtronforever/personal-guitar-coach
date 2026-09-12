import SwiftUI
import Persistence

enum CoachLayout {
    static let spacing: CGFloat = 16
    static let padding: CGFloat = 24
    static let minimumWidth: CGFloat = 900
    static let minimumHeight: CGFloat = 620
}

struct AppRootView: View {
    @Bindable var navigation: AppNavigation
    @Environment(AppSettings.self) private var settings
    @State private var showsAudio = false
    @Environment(LocalDataStore.self) private var data
    @Environment(LessonLibraryStore.self) private var library
    @Environment(PracticeModel.self) private var practice

    var body: some View {
        NavigationSplitView {
            List(AppDestination.allCases, selection: $navigation.destination) { destination in
                Label(LocalizedStringKey(destination.titleKey), systemImage: destination.symbol)
                    .tag(destination)
                    .accessibilityIdentifier("navigation.\(destination.rawValue)")
                    .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) {
                SettingsLink { Label("settings.title", systemImage: "gearshape") }
                    .accessibilityIdentifier("navigation.settings")
                    .padding(CoachLayout.spacing)
            }
        } detail: {
            destinationView(navigation.destination ?? .lessons)
                .navigationTitle(settings.localized((navigation.destination ?? .lessons).titleKey))
                .toolbar {
                    Button { showsAudio = true } label: { Label("audio.title", systemImage: "waveform") }
                        .accessibilityIdentifier("toolbar.audio")
                }
        }
        .frame(minWidth: CoachLayout.minimumWidth, minHeight: CoachLayout.minimumHeight)
        .environment(navigation)
        .onChange(of: data.preferences.instrument) { _, _ in refreshPractice() }
        .onChange(of: library.hasLoaded) { _, _ in refreshPractice() }
        .onChange(of: navigation.practiceRequest) { _, _ in refreshPractice() }
        .sheet(isPresented: $showsAudio) { AudioProbeView().environment(\.locale, settings.locale) }
    }

    private func refreshPractice() {
        navigation.refreshPractice(instrument: data.preferences.instrument, lessons: library.lessons)
        practice.configure(navigation.practiceAdaptationFailed ? nil : navigation.practiceRequest)
    }

    @ViewBuilder private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .lessons:
            LessonLibraryView()
        case .practice:
            PracticeEntryView()
        case .tuner:
            TunerView()
        case .progress:
            HistoryView()
        }
    }
}

/// Shared empty/error/loading presentation; feature state remains owned by its screen.
struct FeatureStateView<Actions: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbol: String
    var loading = false
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        ScrollView {
            VStack(spacing: CoachLayout.spacing) {
                Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(.tint).accessibilityHidden(true)
                Text(title).font(.title.bold()).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("screen.title")
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if loading { ProgressView().accessibilityLabel("common.loading") }
                actions()
            }
            .frame(maxWidth: 520)
            .padding(40)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
    }
}

struct AppShellPreviews: PreviewProvider {
    private static func settings(_ language: AppLanguage) -> AppSettings {
        let value = AppSettings(defaults: UserDefaults(suiteName: "coach.preview.\(language.rawValue)")!)
        value.language = language
        return value
    }

    static var previews: some View {
        let audio = AudioSessionStore(repository: nil)
        let calibration = CalibrationStore(repository: nil)
        let practice = PracticeModel(audio: audio, calibration: calibration)
        return Group {
            AppRootView(navigation: AppNavigation())
                .environment(settings(.english))
                .environment(\.locale, Locale(identifier: "en"))
                .preferredColorScheme(.light).previewDisplayName("English • library")
            AppRootView(navigation: AppNavigation())
                .environment(settings(.ukrainian))
                .environment(\.locale, Locale(identifier: "uk"))
                .preferredColorScheme(.dark).previewDisplayName("Українська • бібліотека")
            FeatureStateView(title: "common.loading", message: "lessons.loading", symbol: "book", loading: true) { EmptyView() }
                .environment(\.locale, Locale(identifier: "uk")).previewDisplayName("Loading")
            FeatureStateView(title: "common.error", message: "lessons.error", symbol: "exclamationmark.triangle") { EmptyView() }
                .environment(\.locale, Locale(identifier: "en")).previewDisplayName("Error")
        }
        .environment(LocalDataStore(repository: LocalRepository(root: FileManager.default.temporaryDirectory.appendingPathComponent("coach-previews"))))
        .environment(LessonLibraryStore())
        .environment(audio)
        .environment(calibration)
        .environment(practice)
        .environment(AssessmentStore(repository: LocalRepository(root: FileManager.default.temporaryDirectory.appendingPathComponent("coach-previews"))))
        .environment(ReadingProgressStore(repository: LocalRepository(root: FileManager.default.temporaryDirectory.appendingPathComponent("coach-previews"))))
    }
}
