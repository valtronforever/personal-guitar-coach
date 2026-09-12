import Domain
import Learning
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", ukrainian = "uk"
    var id: String { rawValue }
    var titleKey: String { "language.\(rawValue)" }

    func resolvedCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "uk"], forPreferences: preferredLanguages).first ?? "en"
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var titleKey: String { "appearance.\(rawValue)" }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

@MainActor @Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults
    var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "app.language") } }
    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: "app.appearance") } }
    var locale: Locale { Locale(identifier: language.resolvedCode()) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: "app.language") ?? "") ?? .system
        appearance = AppAppearance(rawValue: defaults.string(forKey: "app.appearance") ?? "") ?? .system
    }

    // Scene/menu titles don't reliably inherit a view's locale environment.
    func localized(_ key: String) -> String {
        let code = language.resolvedCode()
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

enum AppDestination: String, CaseIterable, Identifiable {
    case lessons, practice, tuner, progress
    var id: String { rawValue }
    var titleKey: String { "navigation.\(rawValue)" }
    var symbol: String {
        switch self {
        case .lessons: "book.closed"
        case .practice: "play.circle"
        case .tuner: "tuningfork"
        case .progress: "chart.xyaxis.line"
        }
    }
}

@MainActor @Observable
final class AppNavigation {
    var destination: AppDestination? = .lessons
    var lessonPath: [String] = []
    var restoredReading = false
    private(set) var practiceRequest: PracticeRequest?
    private(set) var practiceAdaptationFailed = false
    func refreshPractice(tuning: TuningProfile, lessons: [LoadedLesson]) {
        refreshPractice(instrument: InstrumentProfile(tuning: tuning), lessons: lessons)
    }
    func refreshPractice(instrument: InstrumentProfile, lessons: [LoadedLesson]) {
        guard let request = practiceRequest, request.adaptsWithInstrument else { return }
        guard practiceAdaptationFailed || request.exercise.requiredTuning != instrument.tuning || request.frets != instrument.frets else { return }
        do {
            guard let source = lessons.first(where: { $0.id == request.lessonID }) else { return }
            let adapted = try source.adapted(to: instrument, position: request.position)
            guard let next = PracticeRequest(lesson: adapted, exerciseID: request.exercise.id, adaptsWithInstrument: true, frets: instrument.frets, position: request.position) else { return }
            practiceRequest = next; practiceAdaptationFailed = false
        } catch { practiceAdaptationFailed = true }
    }
    func openPractice(_ request: PracticeRequest) {
        practiceRequest = request; practiceAdaptationFailed = false; destination = .practice
    }
}
