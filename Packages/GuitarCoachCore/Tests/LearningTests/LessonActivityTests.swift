import Foundation
import Testing
import Domain
@testable import Learning

struct LessonActivityTests {
    private func source(_ id: String = "c-major") throws -> LoadedLesson {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try #require(LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons.first { $0.id == id })
    }
    private func fixture(_ id: String = "c-major", scope: LessonMaterialSource? = nil, width: Int = 5,
                         starts: AllowedPositionStarts = .auto, enabled: Bool = true, policy: LessonAdaptationPolicy? = nil) throws -> LoadedLesson {
        let source = try source(id), adaptation = try #require(source.manifest.adaptation)
        let material = LessonMaterial(id: "material", source: scope ?? LessonMaterialSource(kind: .lesson),
            positioning: enabled ? try PositioningPolicy(windowFrets: width, allowedStarts: starts) : nil)
        let activity = LessonActivity(id: "explore", materialID: material.id,
            positionSelection: enabled ? ActivityPositionSelection(mode: .learner, defaultChoice: .original) : nil)
        let shapes = source.manifest.fingerings
        let provisional = LessonManifest(id: id, steps: source.manifest.steps, exercises: source.manifest.exercises, materials: [], activities: [], practiceEntries: [], fingerings: shapes)
        let exerciseIDs = material.exerciseIDs(in: provisional)
        let filtered = source.manifest.steps.filter { step in
            guard step.kind != .none, let exerciseID = step.exerciseID, exerciseIDs.contains(exerciseID) else { return step.kind == .none }
            if material.source.kind == .fingering { return "shape-\(step.id)" == material.source.fingeringID }
            if material.source.kind == .events { return !Set(step.eventIDs).intersection(material.source.eventIDs ?? []).isEmpty }
            return true
        }
        let steps = filtered.map { step in
            LessonStep(id: step.id, kind: step.kind, exerciseID: step.exerciseID,
                eventIDs: material.source.kind == .events ? step.eventIDs.filter { material.source.eventIDs!.contains($0) } : step.eventIDs,
                activityID: activity.id, fingeringID: step.fingeringID)
        }
        // A shape-only activity coexists with an independent monophonic practice material.
        let practiceMaterial = LessonMaterial(id: "practice", source: LessonMaterialSource(kind: .exercise, exerciseID: source.manifest.practiceEntries.map(\.exerciseID)[0]))
        let practiceActivity = LessonActivity(id: "practice", materialID: practiceMaterial.id)
        let practiceID = material.source.kind == .fingering ? "practice" : activity.id
        let practiceExerciseID = material.source.kind == .fingering ? source.manifest.practiceEntries.map(\.exerciseID)[0] : exerciseIDs.first { source.manifest.practiceEntries.map(\.exerciseID).contains($0) } ?? exerciseIDs[0]
        let extra = material.source.kind == .fingering
        let manifest = LessonManifest(schemaVersion: 2, id: id, steps: steps, exercises: source.manifest.exercises,
            adaptation: LessonAdaptationDefinition(policy: policy ?? adaptation.policy),
            materials: extra ? [material, practiceMaterial] : [material], activities: extra ? [activity, practiceActivity] : [activity],
            practiceEntries: [LessonPracticeEntry(id: "perform", activityID: practiceID, exerciseID: practiceExerciseID)], fingerings: shapes)
        func text(_ text: LessonText) -> LessonText {
            let activities = Dictionary(uniqueKeysWithValues: manifest.activities.map { ($0.id, LessonActivityText(title: "Example", body: "{{positionLabel}}: {{notes}}; {{positions}}")) })
            return LessonText(lessonID: id, lessonVersion: manifest.version, locale: text.locale, title: "Generic lesson",
                summary: "Summary", goal: "Goal", body: "Theory", steps: Dictionary(uniqueKeysWithValues: steps.map { ($0.id, text.steps[$0.id]!) }),
                historicalTitle: text.historicalTitle, activities: activities)
        }
        try LessonCatalogLoader().validate(manifest)
        return LoadedLesson(manifest: manifest, english: text(source.english), ukrainian: text(source.ukrainian))
    }
    @Test func schema2RoundTripLoadsSingleEditionAndLocalizesActivities() throws {
        let lesson = try fixture(), directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = directory.appendingPathComponent(lesson.id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        try encoder.encode(LessonCatalogManifest(lessons: [lesson.id])).write(to: directory.appendingPathComponent("catalog.json"))
        try encoder.encode(lesson.manifest).write(to: folder.appendingPathComponent("lesson.json"))
        for (name, text) in [("en",lesson.english),("uk",lesson.ukrainian)] {
            try encoder.encode(text).write(to: folder.appendingPathComponent("\(name).json"))
        }
        let report = LessonCatalogLoader().load(directory: directory)
        #expect(report.issues.isEmpty)
        let loaded = try #require(report.lessons.first)
        let enPath = folder.appendingPathComponent("en.json")
        let originalText = try String(contentsOf: enPath, encoding: .utf8)
        try originalText.replacingOccurrences(of: "{{notes}}", with: "{{unknown}}").write(to: enPath, atomically: true, encoding: .utf8)
        #expect(LessonCatalogLoader().load(directory: directory).issues.first?.code == .invalidText)
        try originalText.replacingOccurrences(of: "{{notes}}", with: "{{first}}").write(to: enPath, atomically: true, encoding: .utf8)
        #expect(LessonCatalogLoader().load(directory: directory).issues.first?.code == .translationMismatch)
        try originalText.write(to: enPath, atomically: true, encoding: .utf8)
        let result = try loaded.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: .cStandard), choice: .region(firstFret: 7))
        #expect(result.exercises[0].events.flatMap(\.positions).map(\.fret) == [8,10,7,8,10,7,9,10,9,7,10,8,7,10,8])
        #expect(try result.exercises[0].resolvedEvents(instrument: .standard).flatMap(\.pitches).map(\.midi) == [44,46,48,49,51,53,55,56,55,53,51,49,48,46,44])
        for language in [LessonLanguage.en, .uk] {
            let text = result.text(for: language)
            #expect(text.activities["explore"]?.body.contains("{{") == false)
            #expect(text.steps["root-c"]?.body.contains("(6/8)") == true)
        }
        // Semantic v2 fields must never be silently ignored by a legacy manifest.
        var json = try #require(JSONSerialization.jsonObject(with: encoder.encode(lesson.manifest)) as? [String: Any])
        json["schemaVersion"] = 1
        try JSONSerialization.data(withJSONObject: json).write(to: folder.appendingPathComponent("lesson.json"))
        #expect(LessonCatalogLoader().load(directory: directory).issues.first?.code == .unsupportedSchema)
        json["schemaVersion"] = 99; json["materials"] = "invalid-payload"
        try JSONSerialization.data(withJSONObject: json).write(to: folder.appendingPathComponent("lesson.json"))
        #expect(LessonCatalogLoader().load(directory: directory).issues.first?.code == .unsupportedSchema)
    }
    @Test func allTuningsNecksAndWindowWidthsPreserveExactTargetsAndReportAvailability() throws {
        for width in [5,6] {
            let lesson = try fixture(width: width, starts: .explicit([3,7]))
            for tuning in TuningProfile.presets {
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    let original = try lesson.resolveActivity(id: "explore", instrument: instrument)
                    let available = lesson.availableChoices(activityID: "explore", instrument: instrument)
                    #expect(available.contains(.region(firstFret: 7)) == (width == 6 || [TuningProfile.standard,.dStandard,.cStandard,.bStandard].contains(tuning)))
                    for choice in available {
                        let result = try lesson.resolveActivity(id: "explore", instrument: instrument, choice: choice)
                        #expect(try result.exercises[0].resolvedEvents(instrument: tuning).flatMap(\.pitches) == original.exercises[0].resolvedEvents(instrument: tuning).flatMap(\.pitches))
                        #expect(result.exercises[0].events.map(\.startTick) == original.exercises[0].events.map(\.startTick))
                        if let region = try result.material.policy.region(for: choice) { #expect(result.exercises.flatMap(\.events).flatMap(\.positions).allSatisfy { region.contains($0, maximumFret: frets.rawValue) }) }
                    }
                }
            }
        }
    }
    @Test func noteAndFragmentScopesNormalizeTicksWithoutDraggingTheRestOfTheExercise() throws {
        let lesson = try fixture(scope: LessonMaterialSource(kind: .events, exerciseID: "c-major-practice", eventIDs: ["up-5"]))
        let result = try lesson.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: .cStandard), choice: .region(firstFret: 12))
        let event = try #require(result.exercises.first?.events.first)
        #expect(result.exercises[0].events.count == 1 && event.id == "up-5" && event.startTick == 0 && event.durationTicks == 960)
        #expect(result.sourceMappings[0].startTick == 3840 && result.sourceMappings[0].eventIDs == ["up-5"])
        #expect(try result.exercises[0].resolvedEvents(instrument: .standard).flatMap(\.pitches).map(\.midi) == [51])
        #expect(try result.visual(stepID: "upper-half").positions.map(\.position) == event.positions)
        let fragment = try fixture(scope: LessonMaterialSource(kind: .events, exerciseID: "c-major-practice", eventIDs: ["down-7","finish-rest"]))
        let resolved = try fragment.resolveActivity(id: "explore", instrument: InstrumentProfile())
        #expect(resolved.exercises[0].events.map(\.kind) == [.note,.rest])
        #expect(resolved.exercises[0].events.map(\.startTick) == [0,960])
        #expect(throws: ContentFailure.self) { try fixture(scope: LessonMaterialSource(kind: .events, exerciseID: "c-major-practice", eventIDs: ["finish-rest"]), enabled: false) }
        #expect(throws: ContentFailure.self) { try fixture(scope: LessonMaterialSource(kind: .events, exerciseID: "c-major-practice", eventIDs: ["up-1","up-3"])) }
    }
    @Test func explicitPermissionIsIndependentOfTuningAdaptationAndDefaultsOff() throws {
        let disabled = try fixture(enabled: false)
        #expect(disabled.availableChoices(activityID: "explore", instrument: InstrumentProfile()) == [.original])
        #expect(throws: PositioningError.forbiddenChoice) { try disabled.resolveActivity(id: "explore", instrument: InstrumentProfile(), choice: .region(firstFret: 7)) }
        let physical = try fixture(scope: LessonMaterialSource(kind: .events, exerciseID: "c-major-practice", eventIDs: ["up-5"]), policy: .fretPattern)
        let before = try physical.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: .dropD))
        let after = try physical.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: .dropD), choice: .region(firstFret: 7))
        #expect(before.exercises[0].events != after.exercises[0].events)
        #expect(try before.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches) == after.exercises[0].resolvedEvents(instrument: .dropD).flatMap(\.pitches))
    }
    @Test func shapeAndWholeLessonPreserveVoicingAndSharedArpeggioMapping() throws {
        let whole = try fixture("em-arpeggio")
        let result = try whole.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: .dropD), choice: .region(firstFret: 0))
        let shape = try #require(result.fingerings.first)
        #expect(shape.fingering.positions.reversed().map(\.fret) == [2,2,2,0,0,0])
        #expect(shape.fingering.fingerNumbers.isEmpty && Set(shape.fingering.positions.map(\.string)).count == 6)
        #expect(Set(result.exercises.flatMap(\.events).flatMap(\.positions)).isSubset(of: Set(shape.fingering.positions)))
        let shapeOnly = try fixture("em-arpeggio", scope: LessonMaterialSource(kind: .fingering, fingeringID: shape.id))
        let resolved = try shapeOnly.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: .dropD))
        #expect(resolved.exercises.count == 1 && resolved.exercises[0].assessmentMode == .displayOnly)
        #expect(resolved.exercises[0].events.count == 1 && resolved.exercises[0].events[0].positions.count == 6)
    }
    @Test func malformedActivityReferencesAndForbiddenAuthorChoicesFailBeforeResolution() throws {
        let lesson = try fixture(starts: .explicit([3,7]))
        let original = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(lesson.manifest)) as? [String: Any])
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["materials"] = [] },
            { $0["activities"] = [["id":"explore","materialID":"missing"]] },
            { $0["activities"] = [["id":"explore","materialID":"material","positionSelection":["mode":"fixed","value":["kind":"region","firstFret":9]]]] },
            { $0["activities"] = [["id":"explore","materialID":"material","positionSelection":["mode":"fixed","default":["kind":"original"],"value":["kind":"original"]]]] },
            { $0["activities"] = [["id":"explore","materialID":"material"]] },
            { $0["practiceEntries"] = [["id":"perform","activityID":"missing","exerciseID":"c-major-practice"]] },
            { var steps = $0["steps"] as! [[String: Any]]; steps[0]["activityID"] = "missing"; $0["steps"] = steps },
            { var steps = $0["steps"] as! [[String: Any]]; steps[0]["eventIDs"] = ["missing"]; $0["steps"] = steps },
            { var materials = $0["materials"] as! [[String: Any]]; materials.append(materials[0]); $0["materials"] = materials }
        ]
        for mutate in mutations {
            var json = original; mutate(&json)
            #expect(throws: (any Error).self) {
                try LessonCatalogLoader().validate(JSONDecoder().decode(LessonManifest.self, from: JSONSerialization.data(withJSONObject: json)))
            }
        }
    }
    @Test func sameMaterialCanHaveIndependentLearnerAndFixedActivities() throws {
        let lesson = try fixture(starts: .explicit([3,7])), m = lesson.manifest
        let fixed = LessonActivity(id: "fixed-seven", materialID: "material", positionSelection: ActivityPositionSelection(mode: .fixed, value: .region(firstFret: 7)))
        let fixedStep = LessonStep(id: "fixed-step", kind: .events, exerciseID: "c-major-practice", eventIDs: ["up-1"], activityID: fixed.id)
        let manifest = LessonManifest(schemaVersion: 2, id: m.id, steps: m.steps + [fixedStep], exercises: m.exercises, adaptation: m.adaptation,
            materials: m.materials, activities: m.activities + [fixed], practiceEntries: m.practiceEntries + [LessonPracticeEntry(id: "fixed-practice", activityID: fixed.id, exerciseID: "c-major-practice")], fingerings: m.fingerings)
        try LessonCatalogLoader().validate(manifest)
        func text(_ source: LessonText) -> LessonText {
            var steps = source.steps; steps[fixedStep.id] = LessonStepText(title: "Fixed example", body: "{{positions}}")
            var activities = source.activities; activities[fixed.id] = LessonActivityText(title: "Near seven", body: "{{positionLabel}}: {{positions}}")
            return LessonText(lessonID: source.lessonID, lessonVersion: source.lessonVersion, locale: source.locale, title: source.title,
                summary: source.summary, goal: source.goal, body: source.body, steps: steps, activities: activities)
        }
        let combined = LoadedLesson(manifest: manifest, english: text(lesson.english), ukrainian: text(lesson.ukrainian))
        let instrument = InstrumentProfile(tuning: .cStandard)
        let exploring = try combined.resolveActivity(id: "explore", instrument: instrument, choice: .region(firstFret: 3))
        let fixedResult = try combined.resolveActivity(id: fixed.id, instrument: instrument)
        #expect(fixedResult.choice == .region(firstFret: 7) && fixedResult.steps.map(\.id) == [fixedStep.id])
        #expect(exploring.choice == .region(firstFret: 3) && exploring.exercises[0].events != fixedResult.exercises[0].events)
        #expect(combined.availableChoices(activityID: fixed.id, instrument: instrument) == [.region(firstFret: 7)])
        #expect(throws: PositioningError.forbiddenChoice) { try combined.resolveActivity(id: fixed.id, instrument: instrument, choice: .original) }
        #expect(throws: PositioningError.regionUnplayable) { try combined.resolveActivity(id: fixed.id, instrument: InstrumentProfile(tuning: .dropBFlat)) }
        #expect(try combined.resolveActivity(id: "explore", instrument: InstrumentProfile(tuning: .dropBFlat), choice: .region(firstFret: 3)).choice == .region(firstFret: 3))
        #expect(try combined.resolveActivity(id: "explore", instrument: instrument, choice: .region(firstFret: 3)) == exploring)
    }
    @Test func wholeMaterialsRejectDifferentPitchesButAllowEquivalentNamedProfiles() throws {
        let lesson = try fixture(), encoder = JSONEncoder()
        let original = try #require(JSONSerialization.jsonObject(with: encoder.encode(lesson.manifest)) as? [String: Any])
        func addingSecond(_ tuning: TuningProfile) throws -> LessonManifest {
            var json = original, exercises = json["exercises"] as! [[String: Any]], second = exercises[0]
            second["id"] = "second-exercise"
            second["requiredTuning"] = try JSONSerialization.jsonObject(with: encoder.encode(tuning))
            exercises.append(second); json["exercises"] = exercises
            return try JSONDecoder().decode(LessonManifest.self, from: JSONSerialization.data(withJSONObject: json))
        }
        #expect(throws: ContentFailure.self) { try LessonCatalogLoader().validate(addingSecond(.cStandard)) }
        let equivalent = try TuningProfile(id: "named-standard", name: "My Standard", strings: TuningProfile.standard.strings)
        try LessonCatalogLoader().validate(addingSecond(equivalent))
    }

}
