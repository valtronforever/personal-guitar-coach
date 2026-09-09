import SwiftUI
import Domain
import Learning
import Persistence

@MainActor @Observable
final class LessonSelection {
    let lesson: LoadedLesson
    private(set) var stepID: String?
    private(set) var exerciseID: String?
    private(set) var range = TimelineSelection()
    var selectedPosition: FretPosition?

    init(lesson: LoadedLesson, bookmark: LessonBookmark? = nil) {
        self.lesson = lesson
        let restored = bookmark?.lessonVersion == lesson.manifest.version ? bookmark?.stepID : nil
        selectStep(restored.flatMap { id in lesson.manifest.steps.first { $0.id == id } }?.id ?? lesson.manifest.steps[0].id)
    }

    var exercise: Exercise? { lesson.manifest.exercises.first { $0.id == exerciseID } }
    var selectedIDs: Set<String> {
        if !range.ids.isEmpty { return range.ids }
        return Set(lesson.manifest.steps.first { $0.id == stepID }?.eventIDs ?? [])
    }

    func selectStep(_ id: String) {
        guard let step = lesson.manifest.steps.first(where: { $0.id == id }) else { return }
        stepID = id; exerciseID = step.exerciseID
        range.clear(); selectedPosition = nil
    }

    func selectEvent(_ id: String, exerciseID: String, extending: Bool) {
        guard let exercise = lesson.manifest.exercises.first(where: { $0.id == exerciseID }),
              exercise.events.contains(where: { $0.id == id }) else { return }
        if self.exerciseID != exerciseID { range.clear() }
        if extending && range.ids.isEmpty && self.exerciseID == exerciseID,
           let first = exercise.events.first(where: { selectedIDs.contains($0.id) }) {
            range.select(first.id, extending: false, events: exercise.events)
        }
        range.select(id, extending: extending, events: exercise.events)
        let matching = lesson.manifest.steps.filter { $0.exerciseID == exerciseID && $0.eventIDs.contains(id) }
        if !matching.contains(where: { $0.id == stepID }) { stepID = matching.first?.id }
        self.exerciseID = exerciseID; selectedPosition = nil
    }

    func fretboard(instrument: InstrumentProfile) -> FretboardModel {
        if !range.ids.isEmpty, let exercise {
            return FretboardModel(tuning: exercise.requiredTuning ?? instrument.tuning, orientation: instrument.orientation,
                positions: exercise.events.filter { range.ids.contains($0.id) }.flatMap(\.positions))
        }
        if let stepID, let visual = try? lesson.visual(stepID: stepID, instrument: instrument.tuning) {
            return FretboardModel(tuning: visual.tuning, orientation: instrument.orientation, positions: visual.positions.map(\.position),
                mutedStrings: visual.mutedStrings,
                fingers: Dictionary(uniqueKeysWithValues: visual.positions.compactMap { item in item.finger.map { (item.position.string, $0) } }))
        }
        return FretboardModel(tuning: instrument.tuning, orientation: instrument.orientation, positions: [])
    }
}

struct LessonFilter {
    var query = ""
    var difficulty: LessonDifficulty?
    var topic: LessonTopic?
    func matches(_ lesson: LoadedLesson, language: LessonLanguage) -> Bool {
        guard difficulty == nil || lesson.manifest.difficulty == difficulty,
              topic == nil || lesson.manifest.topic == topic else { return false }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = lesson.text(for: language)
        return query.isEmpty || [text.title, text.summary].contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: language.rawValue)) != nil
        }
    }
}

struct PracticeRequest: Equatable, Sendable {
    let lessonID: String
    let lessonVersion: Int
    let exercise: Exercise
    init?(lesson: LoadedLesson, exerciseID: String) {
        guard lesson.manifest.practiceExerciseIDs.contains(exerciseID),
              let exercise = lesson.manifest.exercises.first(where: { $0.id == exerciseID }),
              exercise.assessmentMode == .monophonic else { return nil }
        lessonID = lesson.id; lessonVersion = lesson.manifest.version; self.exercise = exercise
    }
}
