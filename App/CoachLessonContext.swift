import Domain
import Learning

enum CoachLessonContext {
    static func make(request: PracticeRequest?, lessons: [LoadedLesson], instrument: InstrumentProfile, language: LessonLanguage) -> String {
        guard let request, let source = lessons.first(where: { $0.id == request.lessonID && $0.manifest.version == request.lessonVersion }),
              let target = try? request.retryInstrument(from: instrument) else { return "Archived lesson text unavailable; use the frozen exercise and activity titles in practice.configuration." }
        let resolved = request.activityReference.flatMap { try? source.resolveActivity(id: $0.activityID, instrument: target, choice: $0.choice) }
        let text = resolved?.text(for: language) ?? source.text(for: language)
        var parts = [text.title, text.goal, text.summary, text.body]
        if let activityID = request.activityReference?.activityID, let activity = text.activities[activityID] {
            parts += [activity.title, activity.body]
        }
        for step in resolved?.steps ?? [] {
            if let copy = text.steps[step.id] { parts += [copy.title, copy.body] }
        }
        return parts.joined(separator: "\n\n")
    }
}
