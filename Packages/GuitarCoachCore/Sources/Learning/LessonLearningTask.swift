import Foundation
import Domain

public enum LessonLearningTaskKind: String, Codable, Sendable {
    case checklist, selfPractice, quiz
}

/// A step can combine reading, self-report, questions and existing scored practice entries.
public struct LessonLearningTask: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let stepID: String
    public let kind: LessonLearningTaskKind
    /// Ordered criteria (checklist/selfPractice) or answer options (quiz).
    public let itemIDs: [String]
    public let correctOptionID: String?
    /// A hidden audio example from the step's activity, never a new capture pipeline.
    public let stimulusExerciseID: String?
    public init(id: String, stepID: String, kind: LessonLearningTaskKind, itemIDs: [String],
                correctOptionID: String? = nil, stimulusExerciseID: String? = nil) {
        self.id = id; self.stepID = stepID; self.kind = kind; self.itemIDs = itemIDs
        self.correctOptionID = correctOptionID; self.stimulusExerciseID = stimulusExerciseID
    }
    public var usesInstrument: Bool { kind == .selfPractice || stimulusExerciseID != nil }
    public func isComplete(_ progress: LessonTaskProgress, context: LessonTaskContext) -> Bool {
        guard progress.context == context else { return false }
        if kind == .quiz { return progress.answerID != nil && progress.answerID == correctOptionID }
        return Set(itemIDs).isSubset(of: progress.checkedIDs)
    }
}

public struct LessonLearningTaskText: Codable, Equatable, Sendable {
    public let title: String
    public let body: String
    public let items: [String: String]
    public let explanation: String?
    public init(title: String, body: String, items: [String: String], explanation: String? = nil) {
        self.title = title; self.body = body; self.items = items; self.explanation = explanation
    }
}

extension LessonCatalogLoader {
    func validateLearningTasks(_ manifest: LessonManifest) throws {
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw ContentFailure(.invalidStep, message) }
        }
        try require(manifest.tasks.count <= 256, "Too many learning tasks")
        try uniqueIDs(manifest.tasks.map(\.id))
        for task in manifest.tasks {
            guard let step = manifest.steps.first(where: { $0.id == task.stepID }) else {
                throw ContentFailure(.unknownStep, "Unknown task step: \(task.id)")
            }
            try uniqueIDs(task.itemIDs)
            try require((1...32).contains(task.itemIDs.count), "A task needs 1–32 items")
            switch task.kind {
            case .checklist, .selfPractice:
                try require(task.correctOptionID == nil && task.stimulusExerciseID == nil, "Only quizzes have answers and hidden audio stimuli")
            case .quiz:
                try require((2...8).contains(task.itemIDs.count) && task.correctOptionID.map(task.itemIDs.contains) == true, "A quiz needs 2–8 choices and a valid answer")
            }
            if let id = task.stimulusExerciseID {
                // Keep the question audio private: no visual steps, positioning UI or graded entry can reveal it.
                guard let activityID = step.activityID,
                      let activity = manifest.activities.first(where: { $0.id == activityID }),
                      let material = manifest.materials.first(where: { $0.id == activity.materialID }),
                      let exercise = manifest.exercises.first(where: { $0.id == id }) else {
                    throw ContentFailure(.unknownExercise, "Listening task needs an activity and exercise")
                }
                try require(step.kind == .none && material.source.kind == .exercise && material.source.exerciseID == id && !material.policy.enabled,
                            "Listening task needs a dedicated, non-positionable exercise material and text-only step")
                try require(exercise.events.contains { $0.kind == .note } &&
                    manifest.steps.filter { $0.activityID == activityID }.count == 1 &&
                    !manifest.practiceEntries.contains { $0.activityID == activityID }, "Listening activity must be private to its question step")
                try require(manifest.tasks.filter { $0.stepID == step.id }.count == 1, "Listening step supports one question")
                // Fret patterns change intervals in drop tunings, invalidating a fixed interval answer.
                try require(manifest.adaptation?.policy == .transposeIntervals, "Listening examples must preserve intervals across tunings")
            }
        }
    }

    func validateLearningTaskText(_ text: LessonText, manifest: LessonManifest) throws {
        guard Set(text.taskTexts.keys) == Set(manifest.tasks.map(\.id)) else {
            throw ContentFailure(.translationMismatch, "Learning task translations differ")
        }
        for task in manifest.tasks {
            guard let copy = text.taskTexts[task.id], Set(copy.items.keys) == Set(task.itemIDs),
                  (copy.explanation != nil) == (task.kind == .quiz) else {
                throw ContentFailure(.translationMismatch, "Task options/criteria/explanation differ: \(task.id)")
            }
            let strings = [copy.title, copy.body] + Array(copy.items.values) + (copy.explanation.map { [$0] } ?? [])
            guard strings.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.contains("{{") && !$0.contains("}}") }) else {
                throw ContentFailure(.invalidText, "Task text must be nonblank and instrument-independent")
            }
            if task.stimulusExerciseID != nil, let step = text.steps[task.stepID],
               [step.title, step.body].contains(where: { $0.contains("{{") || $0.contains("}}") }) {
                throw ContentFailure(.invalidText, "Listening question cannot expose musical template tokens")
            }
        }
    }
}
