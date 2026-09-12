import Foundation
import Testing
@testable import Domain

struct PositioningPolicyTests {
    @Test func permittedChoicesAndRegionsHaveIndependentBounds() throws {
        let policy = try PositioningPolicy(windowFrets: 6, allowedStarts: .range(minimum: 3, maximum: 8, step: 2), allowOriginal: false)
        #expect(policy.choices == [.region(firstFret: 3), .region(firstFret: 5), .region(firstFret: 7)])
        #expect(throws: PositioningError.forbiddenChoice) { try policy.region(for: .original) }
        let region = try #require(try policy.region(for: .region(firstFret: 7)))
        #expect(region.contains(try FretPosition(string: 6, fret: 12), maximumFret: 19))
        #expect(!region.contains(try FretPosition(string: 6, fret: 13), maximumFret: 19))
        #expect(!region.contains(try FretPosition(string: 6, fret: 7), maximumFret: 6))
        let upper = try FretRegion(firstFret: 19, windowFrets: 6)
        #expect(upper.contains(try FretPosition(string: 1, fret: 19), maximumFret: 19))
        #expect(!upper.contains(try FretPosition(string: 1, fret: 20), maximumFret: 19))
        #expect(try JSONDecoder().decode(PositioningPolicy.self, from: JSONEncoder().encode(policy)) == policy)
        #expect(try JSONDecoder().decode(FretRegion.self, from: JSONEncoder().encode(region)) == region)
    }
    @Test func corruptTagsAndMalformedPoliciesFailDecoding() throws {
        let invalid = [
            #"{"enabled":true,"preserve":"pitchClass","windowFrets":5,"allowedStarts":{"kind":"auto"},"allowOriginal":true}"#,
            #"{"enabled":true,"preserve":"soundingPitch","windowFrets":7,"allowedStarts":{"kind":"auto"},"allowOriginal":true}"#,
            #"{"enabled":false,"windowFrets":5}"#,
            #"{"enabled":true}"#,
            #"{"enabled":true,"preserve":"soundingPitch","windowFrets":5,"allowedStarts":{"kind":"explicit","frets":[7,3]},"allowOriginal":true}"#,
            #"{"enabled":true,"preserve":"soundingPitch","windowFrets":5,"allowedStarts":{"kind":"explicit","frets":[7,7]},"allowOriginal":true}"#,
            #"{"enabled":true,"preserve":"soundingPitch","windowFrets":5,"allowedStarts":{"kind":"range","minimum":7,"maximum":3},"allowOriginal":true}"#,
            #"{"enabled":true,"preserve":"soundingPitch","windowFrets":5,"allowedStarts":{"kind":"range","minimum":0,"maximum":24,"step":0},"allowOriginal":true}"#,
            #"{"enabled":true,"preserve":"soundingPitch","windowFrets":5,"allowedStarts":{"kind":"auto","frets":[3]},"allowOriginal":true}"#
        ]
        for json in invalid { #expect(throws: PositioningError.invalidPolicy) { try JSONDecoder().decode(PositioningPolicy.self, from: Data(json.utf8)) } }
        for json in [#"{"kind":"region","firstFret":25}"#, #"{"kind":"original","firstFret":0}"#, #"{"kind":"transpose"}"#] {
            #expect(throws: PositioningError.invalidPolicy) { try JSONDecoder().decode(PositionChoice.self, from: Data(json.utf8)) }
        }
        #expect(throws: PositioningError.invalidPolicy) { try JSONDecoder().decode(FretRegion.self, from: Data(#"{"firstFret":24,"windowFrets":0}"#.utf8)) }
        #expect(try JSONDecoder().decode(PositioningPolicy.self, from: Data(#"{"enabled":false}"#.utf8)) == .disabled)
    }
}

struct PracticeActivitySnapshotTests {
    private func exercise() throws -> Exercise {
        try Exercise(id: "fragment", version: 3, events: [MusicalEvent(id: "fifth", startTick: 0, durationTicks: 960, kind: .note,
            positions: [FretPosition(string: 5, fret: 7)])], tuningPolicy: .fixedTuning, requiredTuning: .cStandard)
    }
    private func reference() throws -> PracticeActivityReference {
        try PracticeActivityReference(activityID: "explore", materialID: "note", entryID: "perform", choice: .region(firstFret: 7),
            positioning: PositioningPolicy(windowFrets: 5, allowedStarts: .explicit([7]), allowOriginal: false), requiredChoice: nil,
            resolverVersion: "lesson-activity-1", source: ExerciseSourceMapping(exerciseID: "fragment", exerciseVersion: 3, startTick: 3840, eventIDs: ["fifth"]),
            lessonTitles: ["en": "Lesson", "uk": "Урок"], activityTitles: ["en": "Note", "uk": "Нота"])
    }
    @Test func forgedPolicyChoiceVersionAndSourceIDsFailBeforeAudio() throws {
        let reference = try reference(), exercise = try exercise(), encoder = JSONEncoder()
        try reference.validate(exercise: exercise)
        let original = try #require(JSONSerialization.jsonObject(with: encoder.encode(reference)) as? [String: Any])
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["schemaVersion"] = 2 },
            { $0["choice"] = ["kind": "original"] },
            { $0["requiredChoice"] = ["kind": "region", "firstFret": 8] },
            { $0["source"] = ["exerciseID": "fragment", "exerciseVersion": 2, "startTick": 3840, "eventIDs": ["fifth"]] },
            { $0["source"] = ["exerciseID": "fragment", "exerciseVersion": 3, "startTick": 3840, "eventIDs": ["wrong"]] },
            { $0["source"] = ["exerciseID": "fragment", "exerciseVersion": 3, "startTick": Int64.max, "eventIDs": ["fifth"]] },
            { $0["lessonTitles"] = ["en": "Only one language"] }
        ]
        for mutate in mutations {
            var document = original; mutate(&document)
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(PracticeActivityReference.self, from: JSONSerialization.data(withJSONObject: document)).validate(exercise: exercise)
            }
        }
        let badConfirmation = try PracticeActivityReference(activityID: reference.activityID, materialID: reference.materialID,
            entryID: reference.entryID, choice: reference.choice, positioning: reference.positioning, requiredChoice: nil,
            resolverVersion: reference.resolverVersion, source: reference.source, lessonTitles: reference.lessonTitles,
            activityTitles: reference.activityTitles, selfConfirmation: PositionSelfConfirmation(choice: reference.choice, tuning: .standard, frets: .twentyFour))
        #expect(throws: PracticeError.invalidEvidence) { try badConfirmation.validate(exercise: exercise) }
        let wrong = try Exercise(id: "fragment", version: 3, events: [MusicalEvent(id: "fifth", startTick: 0, durationTicks: 960, kind: .note,
            positions: [FretPosition(string: 4, fret: 2)])], tuningPolicy: .fixedTuning, requiredTuning: .cStandard)
        #expect(throws: PracticeError.invalidEvidence) { try reference.validate(exercise: wrong) }
        #expect(throws: PracticeError.invalidEvidence) { try PracticeLessonReference(id: "lesson", version: 1, position: LessonPosition(firstFret: 7), activity: reference) }
    }
}
