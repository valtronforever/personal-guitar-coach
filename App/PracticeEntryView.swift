import SwiftUI
import Learning

/// Concrete lesson handoff. Transport and assessed sessions are supplied by tasks 14–16.
struct PracticeEntryView: View {
    @Environment(AppNavigation.self) private var navigation
    @Environment(LocalDataStore.self) private var data
    @Environment(LessonLibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings
    private var language: LessonLanguage { LessonLanguage(rawValue: settings.language.resolvedCode()) ?? .en }
    var body: some View {
        if let request = navigation.practiceRequest {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("navigation.practice").font(.largeTitle.bold())
                    if let lesson = library.lessons.first(where: { $0.id == request.lessonID }) {
                        Text(verbatim: lesson.text(for: language).title).font(.title2)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey(request.exercise.requiredTuning == nil ? "practice.followsTuning" : "practice.fixedTuning")).font(.headline)
                        TuningName(profile: request.exercise.requiredTuning ?? data.preferences.instrument.tuning)
                        Text(verbatim: (request.exercise.requiredTuning ?? data.preferences.instrument.tuning).strings.reversed().map { $0.openPitch.name() }.joined(separator: " · "))
                        Text("practice.stringOrder").font(.caption).foregroundStyle(.secondary)
                    }
                    TuningRequirementView(exercise: request.exercise, instrument: data.preferences.instrument.tuning)
                    Text("practice.selectedTempo \(Int(request.exercise.defaultBPM))")
                    Text("practice.prepared").foregroundStyle(.secondary)
                    Button("practice.backToLesson") { navigation.lessonPath = [request.lessonID]; navigation.destination = .lessons }
                }.padding(CoachLayout.padding).frame(maxWidth: 740, alignment: .leading)
            }.accessibilityIdentifier("practice.selectedExercise")
        } else {
            FeatureStateView(title: "practice.emptyTitle", message: "practice.empty", symbol: "play.circle") {
                Button("navigation.lessons") { navigation.destination = .lessons }
            }
        }
    }
}
