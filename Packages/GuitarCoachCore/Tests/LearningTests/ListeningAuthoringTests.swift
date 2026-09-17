import Foundation
import Testing
import Domain
@testable import Learning

struct ListeningAuthoringTests {
    private func manifest(visual: Bool = false, shared: Bool = false, positionable: Bool = false, wrongPolicy: Bool = false, gap: Bool = false) throws -> LessonManifest {
        let event = try MusicalEvent(id: "note", startTick: gap ? 960 : 0, durationTicks: 960, kind: .note, positions: [FretPosition(string: 1, fret: 0)])
        let exercise = try Exercise(id: "phrase", events: [event], tuningPolicy: .fixedTuning, requiredTuning: .standard)
        let source = LessonMaterialSource(kind: .exercise, exerciseID: "phrase")
        let material = LessonMaterial(id: "private", source: source, positioning: positionable ? try PositioningPolicy(windowFrets: 5, allowedStarts: .auto) : nil)
        return LessonManifest(id: "listen", steps: [LessonStep(id: "listen", kind: visual ? .events : .none,
            exerciseID: visual ? "phrase" : nil, eventIDs: visual ? ["note"] : [], activityID: "listen")], exercises: [exercise],
            adaptation: LessonAdaptationDefinition(policy: wrongPolicy ? .fretPattern : .transposeIntervals),
            materials: shared ? [material, LessonMaterial(id: "leak", source: source)] : [material],
            activities: [LessonActivity(id: "listen", materialID: "private", positionSelection: positionable ? ActivityPositionSelection(mode: .learner, defaultChoice: .original) : nil)],
            practiceEntries: [LessonPracticeEntry(id: "respond", activityID: "listen", exerciseID: "phrase", presentation: .listenAndRepeat)])
    }
    @Test func privateResponseCannotHaveVisualsSharedTargetsPositionControlsOrContextTokens() throws {
        let loader = LessonCatalogLoader(), valid = try manifest()
        try loader.validate(valid)
        #expect(try JSONDecoder().decode(LessonManifest.self, from: JSONEncoder().encode(valid)).practiceEntries.first?.presentation == .listenAndRepeat)
        for value in [try manifest(visual: true), try manifest(shared: true), try manifest(positionable: true), try manifest(wrongPolicy: true), try manifest(gap: true)] {
            #expect(throws: (any Error).self) { try loader.validate(value) }
        }
        func text(_ body: String) -> LessonText {
            LessonText(lessonID: "listen", locale: "en", title: "Listen", summary: "Listen and reproduce", goal: "Find the sound", body: "Listen first",
                steps: ["listen": LessonStepText(title: "Example", body: body)], activities: ["listen": LessonActivityText(title: "Example", body: body)])
        }
        try loader.validateListeningText(text("Listen and find the pitch"), manifest: valid)
        for token in ["{{first}}", "{{sequence}}", "{{positions}}", "{{notes}}"] {
            #expect(throws: (any Error).self) { try loader.validateListeningText(text(token), manifest: valid) }
        }
    }
}
