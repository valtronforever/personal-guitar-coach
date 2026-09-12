import SwiftUI
import Domain
import Learning
import Persistence

@MainActor @Observable
final class LessonSelection {
    let sourceLesson: LoadedLesson
    private(set) var lesson: LoadedLesson
    private(set) var adaptationFailed = false
    private(set) var stepID: String?
    private(set) var exerciseID: String?
    private(set) var range = TimelineSelection()
    var selectedPosition: FretPosition?
    private(set) var position: LessonPosition?
    private(set) var availablePositions: [LessonPosition] = []
    @ObservationIgnored private var positionInstrument: InstrumentProfile?

    init(lesson: LoadedLesson, bookmark: LessonBookmark? = nil, tuning: TuningProfile? = nil, frets: GuitarFretCount = .twentyFour) {
        sourceLesson = lesson; self.lesson = lesson
        if sourceLesson.supportsPositionSelection,
           bookmark?.lessonVersion == sourceLesson.manifest.adaptation?.lessonVersion { position = bookmark?.position }
        if let tuning { adapt(to: tuning, frets: frets) }
        let restored = bookmark?.lessonVersion == (sourceLesson.manifest.adaptation?.lessonVersion ?? self.lesson.manifest.version) ? bookmark?.stepID : nil
        selectStep(restored.flatMap { id in lesson.manifest.steps.first { $0.id == id } }?.id ?? lesson.manifest.steps[0].id)
    }

    func adapt(to tuning: TuningProfile, frets: GuitarFretCount = .twentyFour) {
        let instrument = InstrumentProfile(tuning: tuning, frets: frets)
        if positionInstrument != instrument {
            availablePositions = sourceLesson.availablePositions(instrument: instrument); positionInstrument = instrument
        }
        do { lesson = try sourceLesson.adapted(to: tuning, frets: frets, position: position); adaptationFailed = false; selectedPosition = nil }
        catch { adaptationFailed = true }
    }
    func selectPosition(_ position: LessonPosition?, instrument: InstrumentProfile) {
        guard sourceLesson.supportsPositionSelection else { return }
        self.position = position
        adapt(to: instrument.tuning, frets: instrument.frets)
    }
    var exercise: Exercise? { adaptationFailed ? nil : lesson.manifest.exercises.first { $0.id == exerciseID } }
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
        guard !adaptationFailed else { return FretboardModel(tuning: instrument.tuning, orientation: instrument.orientation, frets: instrument.frets, positions: []) }
        if !range.ids.isEmpty, let exercise {
            return FretboardModel(tuning: exercise.requiredTuning ?? instrument.tuning, orientation: instrument.orientation, frets: instrument.frets,
                positions: exercise.events.filter { range.ids.contains($0.id) }.flatMap(\.positions))
        }
        if let stepID, let visual = try? lesson.visual(stepID: stepID, instrument: instrument.tuning) {
            return FretboardModel(tuning: visual.tuning, orientation: instrument.orientation, frets: instrument.frets, positions: visual.positions.map(\.position),
                mutedStrings: visual.mutedStrings,
                fingers: Dictionary(uniqueKeysWithValues: visual.positions.compactMap { item in item.finger.map { (item.position.string, $0) } }))
        }
        return FretboardModel(tuning: instrument.tuning, orientation: instrument.orientation, frets: instrument.frets, positions: [])
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
    let selectionID = UUID()
    let initialRange: Range<Int64>?
    let initialBPM: Double?
    let archivedTuning: TuningProfile?
    let lessonID: String
    let lessonVersion: Int
    let adaptsWithInstrument: Bool
    let frets: GuitarFretCount
    let position: LessonPosition?
    let exercise: Exercise
    init?(lesson: LoadedLesson, exerciseID: String, adaptsWithInstrument: Bool = false, frets: GuitarFretCount = .twentyFour, position: LessonPosition? = nil) {
        guard lesson.manifest.practiceExerciseIDs.contains(exerciseID),
              let exercise = lesson.manifest.exercises.first(where: { $0.id == exerciseID }),
              exercise.assessmentMode == .monophonic else { return nil }
        lessonID = lesson.id; lessonVersion = lesson.manifest.version; self.exercise = exercise
        self.adaptsWithInstrument = adaptsWithInstrument; self.frets = frets; self.position = position
        initialRange = nil; initialBPM = nil; archivedTuning = nil
    }
}

extension PracticeRequest {
    /// A cached recommendation can be pressed again after returning from practice.
    func freshSelection() -> PracticeRequest { PracticeRequest(copying: self) }
    private init(copying request: PracticeRequest) {
        lessonID = request.lessonID; lessonVersion = request.lessonVersion; exercise = request.exercise
        adaptsWithInstrument = request.adaptsWithInstrument; frets = request.frets; position = request.position
        initialRange = request.initialRange; initialBPM = request.initialBPM; archivedTuning = request.archivedTuning
    }
    init?(result: AssessedPractice, recommendation: PracticeRecommendation) {
        guard recommendation.sourceAttemptID == result.id,
              FeedbackEngine.recommendations(for: result).contains(recommendation),
              recommendation.action == .repeatFragment,
              let lesson = result.evidence.configuration.lesson else { return nil }
        let config = result.evidence.configuration
        lessonID = lesson.id; lessonVersion = lesson.version; exercise = config.exercise
        adaptsWithInstrument = false; frets = config.instrument.frets; position = config.lesson?.position
        initialBPM = recommendation.bpm
        let bar = exercise.timeSignature.ticksPerBar
        initialRange = Int64(recommendation.firstBar - 1) * bar..<min(Int64(recommendation.lastBar) * bar, exercise.durationTicks)
        archivedTuning = exercise.requiredTuning ?? config.instrument.tuning
    }

    /// Explicit archived target, after the currently selected physical pitches have been checked.
    func retryInstrument(from current: InstrumentProfile) throws -> InstrumentProfile {
        guard let archivedTuning else { return current }
        guard current.tuning.hasSamePitches(as: archivedTuning) else { throw MusicError.tuningMismatch }
        return InstrumentProfile(tuning: archivedTuning, orientation: current.orientation, source: current.source, frets: current.frets)
    }
}
