import Foundation
import Testing
@testable import Domain

struct ListeningConditionsTests {
    @Test func attemptSnapshotRequiresPreparationExactlyForListeningActivities() throws {
        let exercise = try Exercise(id: "phrase", events: [MusicalEvent(id: "note", startTick: 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 1, fret: 0)])])
        let endpoint = try CalibrationEndpoint(uid: "listening", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        func configuration(listening: Bool, conditions: PracticeListeningConditions?) throws -> PracticeConfiguration {
            let activity = try PracticeActivityReference(activityID: "listen", materialID: "private", entryID: "respond", choice: .original,
                positioning: .disabled, requiredChoice: nil, resolverVersion: "lesson-activity-1",
                source: ExerciseSourceMapping(exerciseID: "phrase", exerciseVersion: 1, startTick: 0, eventIDs: ["note"]),
                lessonTitles: ["en": "Listen", "uk": "Послухайте"], activityTitles: ["en": "Example", "uk": "Приклад"],
                presentation: listening ? .listenAndRepeat : nil)
            return try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60, route: route,
                lesson: PracticeLessonReference(id: "lesson", version: 1, activity: activity), listeningConditions: conditions)
        }
        let hidden = try PracticeListeningConditions(referencePlaybackCompleted: true, targetsRevealed: false)
        #expect(throws: PracticeError.invalidEvidence) { try configuration(listening: true, conditions: nil) }
        #expect(throws: PracticeError.invalidEvidence) { try configuration(listening: false, conditions: hidden) }
        let old = try configuration(listening: false, conditions: nil)
        #expect(!String(decoding: try JSONEncoder().encode(old), as: UTF8.self).contains("listeningConditions"))
        let frozen = try configuration(listening: true, conditions: hidden)
        #expect(try JSONDecoder().decode(PracticeConfiguration.self, from: JSONEncoder().encode(frozen)) == frozen)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(frozen)) as? [String: Any])
        json.removeValue(forKey: "listeningConditions")
        #expect(throws: PracticeError.invalidEvidence) { try JSONDecoder().decode(PracticeConfiguration.self, from: JSONSerialization.data(withJSONObject: json)) }
    }
    @Test func presentationVersionIsFrozenAndSurvivesRetryWithoutChangingLegacyEncoding() throws {
        func reference(_ presentation: PracticePresentation?) throws -> PracticeActivityReference {
            try PracticeActivityReference(activityID: "listen", materialID: "private", entryID: "respond", choice: .original,
                positioning: .disabled, requiredChoice: nil, resolverVersion: "lesson-activity-1",
                source: ExerciseSourceMapping(exerciseID: "phrase", exerciseVersion: 1, startTick: 0, eventIDs: ["note"]),
                lessonTitles: ["en": "Listen", "uk": "Послухайте"], activityTitles: ["en": "Example", "uk": "Приклад"], presentation: presentation)
        }
        let shown = try reference(nil), hidden = try reference(.listenAndRepeat)
        #expect(shown.schemaVersion == 1 && hidden.schemaVersion == 2 && !hidden.hasSameConditions(as: shown))
        #expect(try hidden.withoutSelfConfirmation().presentation == .listenAndRepeat)
        #expect(!String(decoding: try JSONEncoder().encode(shown), as: UTF8.self).contains("presentation"))
        for value in [shown, hidden] { #expect(try JSONDecoder().decode(PracticeActivityReference.self, from: JSONEncoder().encode(value)) == value) }
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(hidden)) as? [String: Any])
        object["schemaVersion"] = 1
        #expect(throws: PracticeError.invalidEvidence) { try JSONDecoder().decode(PracticeActivityReference.self, from: JSONSerialization.data(withJSONObject: object)) }
    }
    @Test func listeningPreparationCannotClaimHiddenTargetsAfterReveal() throws {
        let hidden = try PracticeListeningConditions(referencePlaybackCompleted: true, targetsRevealed: false)
        let guidedWithoutReference = try PracticeListeningConditions(referencePlaybackCompleted: false, targetsRevealed: true)
        let guidedAfterReference = try PracticeListeningConditions(referencePlaybackCompleted: true, targetsRevealed: true)
        #expect(hidden.usedHiddenTargets && !guidedWithoutReference.usedHiddenTargets && !guidedAfterReference.usedHiddenTargets)
        for value in [hidden, guidedWithoutReference, guidedAfterReference] {
            #expect(try JSONDecoder().decode(PracticeListeningConditions.self, from: JSONEncoder().encode(value)) == value)
        }
        #expect(throws: PracticeError.invalidEvidence) { try PracticeListeningConditions(referencePlaybackCompleted: false, targetsRevealed: false) }
        let invalid = Data(#"{"version":2,"referencePlaybackCompleted":true,"targetsRevealed":false}"#.utf8)
        #expect(throws: PracticeError.invalidEvidence) { try JSONDecoder().decode(PracticeListeningConditions.self, from: invalid) }
    }
}
