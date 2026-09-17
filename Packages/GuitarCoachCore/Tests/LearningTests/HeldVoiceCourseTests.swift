import Foundation
import Testing
import Domain
@testable import Learning

struct HeldVoiceCourseTests {
    private func catalog() -> LessonCatalogReport {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
    }
    @Test func independentAttacksAndHoldsSurviveEveryPresetAndNeck() throws {
        let report = catalog(); #expect(report.issues.isEmpty)
        let melody = [64,65,67,64,62,59,62,67,64,62,60,64,67,64,60]
        let expected: [String:[String:[Int]]] = [
            "fingerstyle-bass-melody": ["bass-line":[48,43,48,48],"melody-line":melody,
                "hold-the-bass":[48,64,65,67,64],"hold-the-melody":[48,64,43,48,65,43,48,67,43,48,64,43],
                "two-line-study":[48,64,65,67,64,43,62,59,62,67,48,64,62,60,64,48,67,64,60]],
            "chord-melody": ["top-line":[67,69,67,65,67,69,67,67,65,64,67,72],
                "supporting-chords":[60,64,67,57,60,65,59,62,67,60,64,72],
                "retain-the-chord":[60,64,67,69,67,57,60,65,67,69,67],
                "chord-melody-study":[60,64,67,69,67,57,60,65,67,69,67,59,62,67,65,60,64,64,67,72]]]
        var count = 0
        for id in expected.keys.sorted() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(lesson.manifest.practiceEntries.isEmpty && lesson.manifest.tasks.contains { $0.kind == .selfPractice })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning,frets: frets)
                    for activity in lesson.manifest.activities {
                        let source = try #require(lesson.manifest.exercises.first { $0.id.hasSuffix(activity.id) })
                        #expect(lesson.availableChoices(activityID: activity.id,instrument: instrument) == [.original])
                        let snapshot = try lesson.resolveActivity(id: activity.id,instrument: instrument)
                        let exercise = try #require(snapshot.exercises.first)
                        let attacks = try exercise.events.flatMap(\.attackedPositions).map { try tuning.pitch(at: $0).midi }
                        #expect(attacks == expected[id]![activity.id]!.map { $0+shift }, "\(id)/\(activity.id)/\(tuning.id)")
                        #expect(exercise.durationTicks == (activity.id == "hold-the-bass" ? 3840 : ["hold-the-melody","retain-the-chord"].contains(activity.id) ? 7680 : 15360))
                        #expect(exercise.events.map(\.heldStrings) == source.events.map(\.heldStrings))
                        #expect(exercise.events.flatMap(\.positions).allSatisfy(instrument.contains))
                        #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning,bpm: 60) }
                        if exercise.hasHeldVoices {
                            let actual = exercise.referenceVoiceSpans
                            #expect(actual.count == attacks.count)
                            #expect(actual.map(\.startTick) == source.referenceVoiceSpans.map(\.startTick))
                            #expect(actual.map(\.endTick) == source.referenceVoiceSpans.map(\.endTick))
                            #expect(exercise.events.map { $0.positions.map(\.string) } == source.events.map { $0.positions.map(\.string) })
                            if activity.id == "hold-the-bass" {
                                #expect(actual.first?.startTick == 0 && actual.first?.endTick == 3840 && actual.first?.position.string == 5)
                            }
                            if activity.id == "retain-the-chord" {
                                #expect(actual.prefix(2).map(\.endTick) == [3840,3840])
                            }
                        }
                        for language in [LessonLanguage.en,.uk] {
                            #expect(snapshot.text(for: language).body == lesson.text(for: language).body)
                            #expect(!snapshot.text(for: language).activities[activity.id]!.body.contains("{{"))
                        }
                        count += 1
                    }
                }
            }
        }
        #expect(count == 360)
    }
    @Test func loaderRejectsRelocationFragmentsAndShapeProjectionAndTextNamesHolds() throws {
        let lesson = try #require(catalog().lessons.first { $0.id == "fingerstyle-bass-melody" })
        let manifest = lesson.manifest
        func object() throws -> [String:Any] { try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String:Any]) }
        for mode in ["positioning","fragment"] {
            var data = try object(), materials = try #require(data["materials"] as? [[String:Any]])
            let index = try #require(materials.firstIndex { $0["id"] as? String == "hold-the-bass" })
            if mode == "positioning" {
                materials[index]["positioning"] = ["enabled":true,"preserve":"soundingPitch","windowFrets":6,"allowOriginal":true,"allowedStarts":["kind":"explicit","frets":[5]]]
            } else {
                materials[index]["source"] = ["kind":"events","exerciseID":"fingerstyle-bass-melody-hold-the-bass","eventIDs":["event-1","event-2","event-3","event-4"]]
            }
            data["materials"] = materials
            let changed = try JSONDecoder().decode(LessonManifest.self,from: JSONSerialization.data(withJSONObject: data))
            #expect(throws: (any Error).self) { try LessonCatalogLoader().validateActivities(changed) }
        }
        let shape = try LessonSourceFingering(id: "lost-hold",exerciseID: "fingerstyle-bass-melody-hold-the-bass",fingering: Fingering(positions: [FretPosition(string: 5,fret: 3)]))
        let shaped = LessonManifest(id: manifest.id,steps: manifest.steps,exercises: manifest.exercises,adaptation: manifest.adaptation,materials: manifest.materials,activities: manifest.activities,practiceEntries: [],fingerings: [shape],learningTasks: manifest.learningTasks)
        #expect(throws: (any Error).self) { try LessonCatalogLoader().validateActivities(shaped) }
        func text(_ original: LessonText) throws -> LessonText {
            var data = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String:Any])
            var activities = try #require(data["activities"] as? [String:[String:Any]])
            activities["hold-the-bass"]?["body"] = "{{sequence}} | {{positions}}"; data["activities"] = activities
            return try JSONDecoder().decode(LessonText.self,from: JSONSerialization.data(withJSONObject: data))
        }
        let changed = try LoadedLesson(manifest: manifest,english: text(lesson.english),ukrainian: text(lesson.ukrainian))
        let snapshot = try changed.resolveActivity(id: "hold-the-bass",instrument: InstrumentProfile(tuning: .cStandard))
        #expect(snapshot.text(for: .en).activities["hold-the-bass"]!.body.contains("keep ringing"))
        #expect(snapshot.text(for: .uk).activities["hold-the-bass"]!.body.contains("продовжуй звучання"))
    }
}
