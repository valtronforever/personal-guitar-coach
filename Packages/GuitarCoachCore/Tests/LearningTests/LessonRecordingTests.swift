import Foundation
import Testing
import Yams
import Domain
@testable import Learning

struct LessonRecordingTests {
    private func manifest(mode: AssessmentMode = .displayOnly, kind: LessonMaterialSource.Kind = .exercise,
                          entries: Bool = false, privateStimulus: Bool = false, duration: Int64 = 3840,
                          meter: TimeSignature = .fourFour, bpm: Double = 60) throws -> LessonManifest {
        let event = try MusicalEvent(id: "note", startTick: 0, durationTicks: duration, kind: .note, positions: [FretPosition(string: 3, fret: 5)])
        let exercise = try Exercise(id: "example", events: [event], timeSignature: meter, defaultBPM: bpm, minimumBPM: bpm, maximumBPM: bpm, assessmentMode: mode)
        let material = LessonMaterial(id: "material", source: LessonMaterialSource(kind: kind,
            exerciseID: kind == .lesson ? nil : exercise.id, eventIDs: kind == .events ? [event.id] : nil))
        let activity = LessonActivity(id: "record", materialID: material.id, recording: .selfPractice)
        let tasks: [LessonLearningTask]? = privateStimulus ? [.init(id: "listen", stepID: "listen-step", kind: .quiz, itemIDs: ["a", "b"], correctOptionID: "a", stimulusExerciseID: exercise.id)] : nil
        return LessonManifest(id: "recording", steps: [], exercises: [exercise], materials: [material], activities: [activity],
            practiceEntries: entries ? [LessonPracticeEntry(id: "grade", activityID: activity.id, exerciseID: exercise.id)] : [], learningTasks: tasks)
    }
    @Test func recordingIsExplicitOptInAndRoundTripsInYAMLWithoutChangingOrdinaryActivityEncoding() throws {
        let ordinary = LessonActivity(id: "ordinary", materialID: "music")
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ordinary)) as? [String: Any])
        #expect(object["recording"] == nil)
        let manifest = try manifest()
        try LessonCatalogLoader().validateActivities(manifest)
        let text = try YAMLEncoder().encode(manifest)
        #expect(text.contains("recording: selfPractice"))
        let decoded = try YAMLDecoder().decode(LessonManifest.self, from: text)
        #expect(decoded == manifest && decoded.activities[0].recording == .selfPractice)
        #expect(throws: (any Error).self) { try YAMLDecoder().decode(LessonManifest.self, from: text.replacingOccurrences(of: "selfPractice", with: "automaticGrading")) }
    }
    @Test func recordingRejectsGradingFragmentsPrivateAnswersAndExcessiveDuration() throws {
        for manifest in try [manifest(mode: .monophonic), manifest(kind: .events), manifest(kind: .lesson), manifest(entries: true),
                             manifest(privateStimulus: true), manifest(duration: 121 * 960),
                             manifest(duration: 80 * 480, meter: .sevenEight, bpm: 40)] {
            #expect(throws: (any Error).self) { try LessonCatalogLoader().validateActivities(manifest) }
        }
        // 6/8 uses a dotted-quarter pulse: this is 120 s, not 180 s.
        try LessonCatalogLoader().validateActivities(manifest(duration: 120 * 1440, meter: .sixEight))
        // A seven-eighths bar at 40 BPM adds 10.5 s; reserve enough room for the final capture tail.
        try LessonCatalogLoader().validateActivities(manifest(duration: 79 * 480, meter: .sevenEight, bpm: 40))
    }
}
