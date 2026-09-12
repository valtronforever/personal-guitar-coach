import SwiftUI
import Domain
import Learning
import Persistence

struct LessonPreviewContext: Equatable { let id: UUID; let exercise: Exercise? }

@MainActor @Observable
final class LessonSelection {
    let sourceLesson: LoadedLesson
    private(set) var stepID: String?
    private(set) var exerciseID: String?
    private(set) var snapshot: ResolvedLessonActivity?
    private(set) var failure: PositioningError?
    private(set) var range = TimelineSelection()
    private(set) var activityChoices: [String: PositionChoice] = [:]
    private(set) var activityConfirmations: [String: PositionSelfConfirmation] = [:]
    private(set) var availableChoices: [PositionChoice] = []
    private(set) var previewContextID = UUID()
    var selectedPosition: FretPosition?
    private var instrument: InstrumentProfile
    @ObservationIgnored private var cached: [String: Result<ResolvedLessonActivity, PositioningError>] = [:]
    @ObservationIgnored private var choiceCache: [String: [PositionChoice]] = [:]

    init(lesson: LoadedLesson, bookmark: LessonBookmark? = nil, tuning: TuningProfile = .standard, frets: GuitarFretCount = .twentyFour) {
        sourceLesson = lesson; instrument = InstrumentProfile(tuning: tuning, frets: frets)
        if bookmark?.lessonVersion == lesson.manifest.version {
            activityChoices = bookmark?.activityChoices.filter { id, _ in lesson.manifest.activities.contains { $0.id == id && $0.positionSelection?.mode == .learner } } ?? [:]
            activityConfirmations = bookmark?.activityConfirmations.filter { id, _ in lesson.manifest.activities.contains { $0.id == id } } ?? [:]
        }
        let restored = bookmark?.lessonVersion == lesson.manifest.version ? bookmark?.stepID : nil
        selectStep(restored.flatMap { id in lesson.manifest.steps.contains { $0.id == id } ? id : nil } ?? lesson.manifest.steps[0].id)
    }
    var previewContext: LessonPreviewContext { LessonPreviewContext(id: previewContextID, exercise: exercise) }
    var activityID: String? { sourceLesson.manifest.steps.first { $0.id == stepID }?.activityID }
    var activity: LessonActivity? { sourceLesson.manifest.activities.first { $0.id == activityID } }
    var policy: PositioningPolicy? { activityID.flatMap { sourceLesson.positioningPolicy(activityID: $0) } }
    var choice: PositionChoice { activityID.flatMap { activityChoices[$0] } ?? activity?.positionSelection?.choice ?? .original }
    var canChoosePosition: Bool { policy?.enabled == true && activity?.positionSelection?.mode == .learner }
    var exercise: Exercise? { snapshot?.exercises.first { $0.id == exerciseID } }
    var practiceEntries: [LessonPracticeEntry] { sourceLesson.manifest.practiceEntries.filter { $0.activityID == activityID } }
    var selfConfirmed: Bool {
        guard let snapshot, let saved = activityConfirmations[snapshot.activity.id] else { return false }
        return saved.choice == snapshot.choice && saved.frets == instrument.frets && saved.tuning.hasSamePitches(as: snapshot.exercises.first?.requiredTuning ?? instrument.tuning)
    }
    func setSelfConfirmed(_ value: Bool) {
        guard let snapshot else { return }
        activityConfirmations[snapshot.activity.id] = value ? PositionSelfConfirmation(choice: snapshot.choice,
            tuning: snapshot.exercises.first?.requiredTuning ?? instrument.tuning, frets: instrument.frets) : nil
    }
    func updateInstrument(_ instrument: InstrumentProfile) {
        guard self.instrument != instrument else { return }
        self.instrument = instrument; cached.removeAll(); choiceCache.removeAll(); previewContextID = UUID(); refresh()
    }
    func selectChoice(_ choice: PositionChoice) {
        guard canChoosePosition, let activityID, policy?.permits(choice) == true else { return }
        activityChoices[activityID] = choice; cached[activityID] = nil; previewContextID = UUID(); refresh()
    }
    private func resolved(_ activityID: String) -> Result<ResolvedLessonActivity, PositioningError> {
        if let existing = cached[activityID] { return existing }
        let result: Result<ResolvedLessonActivity, PositioningError>
        do { result = .success(try sourceLesson.resolveActivity(id: activityID, instrument: instrument, choice: activityChoices[activityID])) }
        catch let error as PositioningError { result = .failure(error) }
        catch { result = .failure(.regionUnplayable) }
        cached[activityID] = result; return result
    }
    private func refresh() {
        selectedPosition = nil
        guard let activityID else { snapshot = nil; failure = nil; availableChoices = []; return }
        if choiceCache[activityID] == nil { choiceCache[activityID] = sourceLesson.availableChoices(activityID: activityID, instrument: instrument) }
        availableChoices = choiceCache[activityID] ?? []
        switch resolved(activityID) {
        case let .success(value): snapshot = value; failure = nil
        case let .failure(error): snapshot = nil; failure = error
        }
    }
    func text(stepID: String, language: LessonLanguage) -> LessonStepText? {
        // Register the actual inputs with Observation; the pure resolver cache itself is not view state.
        _ = instrument; _ = activityChoices
        guard let step = sourceLesson.manifest.steps.first(where: { $0.id == stepID }) else { return nil }
        guard let activityID = step.activityID else { return sourceLesson.text(for: language).steps[stepID] }
        guard case let .success(value) = resolved(activityID) else { return nil }
        return value.text(for: language).steps[stepID]
    }
    var selectedIDs: Set<String> {
        if !range.ids.isEmpty { return range.ids }
        return Set(sourceLesson.manifest.steps.first { $0.id == stepID }?.eventIDs ?? [])
    }
    func selectStep(_ id: String) {
        guard let step = sourceLesson.manifest.steps.first(where: { $0.id == id }) else { return }
        if activityID != step.activityID { previewContextID = UUID() }
        stepID = id; exerciseID = step.exerciseID; range.clear(); refresh()
    }
    func selectEvent(_ id: String, exerciseID: String, extending: Bool) {
        guard let exercise = snapshot?.exercises.first(where: { $0.id == exerciseID }), exercise.events.contains(where: { $0.id == id }) else { return }
        if self.exerciseID != exerciseID { range.clear() }
        if extending && range.ids.isEmpty && self.exerciseID == exerciseID, let first = exercise.events.first(where: { selectedIDs.contains($0.id) }) {
            range.select(first.id, extending: false, events: exercise.events)
        }
        range.select(id, extending: extending, events: exercise.events)
        let matching = snapshot?.steps.filter { $0.exerciseID == exerciseID && $0.eventIDs.contains(id) } ?? []
        if !matching.contains(where: { $0.id == stepID }), let next = matching.first { stepID = next.id }
        self.exerciseID = exerciseID; selectedPosition = nil
    }
    func fretboard(instrument: InstrumentProfile) -> FretboardModel {
        if !range.ids.isEmpty, let exercise {
            return FretboardModel(tuning: exercise.requiredTuning ?? instrument.tuning, orientation: instrument.orientation, frets: instrument.frets,
                positions: exercise.events.filter { range.ids.contains($0.id) }.flatMap(\.positions))
        }
        if let stepID, let visual = try? snapshot?.visual(stepID: stepID) {
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
    let activityReference: PracticeActivityReference?
    let historicalPosition: LessonPosition?
    let exercise: Exercise
    init?(lesson: LoadedLesson, snapshot: ResolvedLessonActivity, entryID: String, selfConfirmation: PositionSelfConfirmation? = nil) {
        guard lesson.id == snapshot.lessonID, lesson.manifest.version == snapshot.lessonVersion,
              lesson.manifest.activities.contains(snapshot.activity), lesson.manifest.materials.contains(snapshot.material),
              snapshot.sourceMappings.allSatisfy({ mapping in
                  lesson.manifest.exercises.contains { $0.id == mapping.exerciseID && $0.version == mapping.exerciseVersion }
              }),
              let entry = lesson.manifest.practiceEntries.first(where: { $0.id == entryID && $0.activityID == snapshot.activity.id }),
              let exercise = snapshot.exercises.first(where: { $0.id == entry.exerciseID }), exercise.assessmentMode == .monophonic,
              let source = snapshot.sourceMappings.first(where: { $0.exerciseID == exercise.id }) else { return nil }
        guard let reference = try? PracticeActivityReference(activityID: snapshot.activity.id, materialID: snapshot.material.id,
            entryID: entryID, choice: snapshot.choice, positioning: snapshot.material.policy,
            requiredChoice: snapshot.activity.positionSelection?.mode == .fixed ? snapshot.choice : nil,
            resolverVersion: ResolvedLessonActivity.resolverVersion, source: source,
            lessonTitles: ["en": lesson.english.title, "uk": lesson.ukrainian.title],
            activityTitles: ["en": snapshot.english.activities[snapshot.activity.id]?.title ?? lesson.english.title,
                             "uk": snapshot.ukrainian.activities[snapshot.activity.id]?.title ?? lesson.ukrainian.title], selfConfirmation: selfConfirmation),
              (try? reference.validate(exercise: exercise)) != nil else { return nil }
        lessonID = lesson.id; lessonVersion = lesson.manifest.version; self.exercise = exercise
        adaptsWithInstrument = true; frets = snapshot.instrument.frets; activityReference = reference; historicalPosition = nil
        initialRange = nil; initialBPM = nil; archivedTuning = nil
    }
    func freshSelection() -> PracticeRequest { PracticeRequest(copying: self) }
    private init(copying request: PracticeRequest) {
        lessonID = request.lessonID; lessonVersion = request.lessonVersion; exercise = request.exercise
        adaptsWithInstrument = request.adaptsWithInstrument; frets = request.frets; activityReference = request.activityReference; historicalPosition = request.historicalPosition
        initialRange = request.initialRange; initialBPM = request.initialBPM; archivedTuning = request.archivedTuning
    }
    init?(result: AssessedPractice, recommendation: PracticeRecommendation) {
        guard recommendation.sourceAttemptID == result.id, FeedbackEngine.recommendations(for: result).contains(recommendation),
              recommendation.action == .repeatFragment, let lesson = result.evidence.configuration.lesson else { return nil }
        let config = result.evidence.configuration
        lessonID = lesson.id; lessonVersion = lesson.version; exercise = config.exercise
        adaptsWithInstrument = false; frets = config.instrument.frets; historicalPosition = lesson.position
        activityReference = try? lesson.activity?.withoutSelfConfirmation()
        initialBPM = recommendation.bpm
        let bar = exercise.timeSignature.ticksPerBar
        initialRange = Int64(recommendation.firstBar - 1) * bar..<min(Int64(recommendation.lastBar) * bar, exercise.durationTicks)
        archivedTuning = exercise.requiredTuning ?? config.instrument.tuning
    }
    func retryInstrument(from current: InstrumentProfile) throws -> InstrumentProfile {
        guard let archivedTuning else { return current }
        guard current.tuning.hasSamePitches(as: archivedTuning) else { throw MusicError.tuningMismatch }
        return InstrumentProfile(tuning: archivedTuning, orientation: current.orientation, source: current.source, frets: current.frets)
    }
}
