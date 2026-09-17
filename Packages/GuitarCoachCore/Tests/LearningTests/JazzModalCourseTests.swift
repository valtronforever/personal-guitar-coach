import Foundation
import Testing
import Domain
@testable import Learning

struct JazzModalCourseTests {
    @Test func harmonyDegreesChromaticTargetsAndHeldContextAdaptAcrossEveryPresetAndNeck() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        let dm = [50,53,60], g = [43,53,59], c = [48,52,59]
        var targets: [String:[String:[Int]]] = [:]
        targets["jazz-comping"] = ["shell-route": [dm,g,c,c].flatMap { $0 },"guide-tone-line":[53,60,53,59,52,59,52,59],
            "separate-shell-tones":[dm,g,c,c].flatMap { $0 },"offbeat-comping":[dm,dm,g,g,c,c,c,c].flatMap { $0 }]
        targets["jazz-lines"] = ["target-map":[65,59,64,60],"half-step-approaches":[64,65,60,59,63,64,61,60],"enclosures":[63,65,64,58,60,59],
            "four-bar-line":[62,64,65,69,72,71,69,65,67,68,67,65,62,61,60,59,60,64,67,71,74,73,72,71,72,71,69,67,64,62,59,60]]
        targets["modal-improvisation"] = ["dorian-scale":[62,64,65,67,69,71,72,74],"natural-minor-comparison":[62,64,65,67,69,70,72,74],
            "tonic-pedal":[50],"dorian-phrase":[62,65,69,71,72,71,69,62],"phrase-over-pedal":[50,62,65,69,71,72,71,69,62]]
        targets["harmonic-minor"] = ["natural-minor-reference":[60,62,63,65,67,68,70,72],"harmonic-minor-scale":[60,62,63,65,67,68,71,72],
            "characteristic-cell":[67,68,71,72,71,68,67,60],"leading-tone-resolution":[71,72,71,72],"dominant-to-minor":[59,62,65,60,63,67]]
        targets["melodic-minor"] = ["jazz-ascent":[60,62,63,65,67,69,71,72],"jazz-descent":[72,71,69,67,65,63,62,60],
            "classical-return":[60,62,63,65,67,69,71,72,70,68,67,65,63,62,60],"minor-major-arpeggio":[60,63,67,71,72,71,67,63,60],
            "application-phrase":[60,63,69,71,72]]
        targets["tension-resolution"] = ["neighbor-return":[48,64,65,64],"chromatic-arrivals":[48,63,64,48,61,60],
            "prepared-suspension":[43,65,48,64],"release-and-space":[48,65,64,62,60]]
        let graded: [String:Set<String>] = ["jazz-comping":["guide-tone-line","separate-shell-tones"],"jazz-lines":Set(targets["jazz-lines"]!.keys),
            "modal-improvisation":["dorian-scale","natural-minor-comparison","dorian-phrase"],
            "harmonic-minor":["natural-minor-reference","harmonic-minor-scale","characteristic-cell","leading-tone-resolution"],
            "melodic-minor":Set(targets["melodic-minor"]!.keys),"tension-resolution":[]]
        var count = 0
        for id in targets.keys.sorted() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(Set(lesson.manifest.practiceEntries.map(\.activityID)) == graded[id]!)
            #expect(lesson.manifest.curriculum?.moduleID == "specializations" && lesson.manifest.tasks.contains { $0.kind == .selfPractice })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning,frets: frets)
                    for activity in lesson.manifest.activities {
                        #expect(lesson.availableChoices(activityID: activity.id,instrument: instrument) == [.original])
                        let snapshot = try lesson.resolveActivity(id: activity.id,instrument: instrument)
                        let exercise = try #require(snapshot.exercises.first)
                        let pitches = try exercise.events.flatMap(\.attackedPositions).map { try tuning.pitch(at: $0).midi }
                        #expect(pitches == targets[id]![activity.id]!.map { $0+shift }, "\(id)/\(activity.id)/\(tuning.id)")
                        let bars: Int64 = id == "jazz-comping" || id == "jazz-lines" && activity.id != "enclosures" || activity.id == "classical-return" ? 4 : activity.id == "minor-major-arpeggio" ? 3 : 2
                        #expect(exercise.durationTicks == bars*3840)
                        #expect(exercise.events.flatMap(\.techniquePositions).allSatisfy(instrument.contains))
                        if graded[id]!.contains(activity.id) {
                            #expect(exercise.assessmentMode == .monophonic)
                            for bpm in [40.0,60.0,120.0] { try exercise.validateForPractice(instrument: tuning,bpm: bpm) }
                        } else {
                            #expect(exercise.assessmentMode == .displayOnly)
                            #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning,bpm: 60) }
                        }
                        if activity.id == "phrase-over-pedal" {
                            let spans = exercise.referenceVoiceSpans
                            #expect(spans.first?.startTick == 0 && spans.first?.endTick == 7680 && spans.first?.position.string == 5)
                            #expect(exercise.events.dropFirst().allSatisfy { $0.heldStrings == [5] })
                        }
                        if activity.id == "prepared-suspension" {
                            #expect(exercise.events.map(\.heldStrings) == [[],[2],[5]])
                            let spans = exercise.referenceVoiceSpans
                            #expect(spans.map(\.startTick) == [0,0,3840,5760] && spans.map(\.endTick) == [3840,5760,7680,7680])
                            let upper = try tuning.pitch(at: spans[1].position).midi, resolution = try tuning.pitch(at: spans[3].position).midi
                            #expect(upper-resolution == 1)
                        }
                        if activity.id == "characteristic-cell" { #expect(pitches[2]-pitches[1] == 3 && pitches[3]-pitches[2] == 1) }
                        if activity.id == "offbeat-comping" { #expect(exercise.events.filter { $0.kind == .note }.map { $0.startTick%3840 } == [480,1920,480,1920,480,1920,480,1920]) }
                        for language in [LessonLanguage.en,.uk] {
                            #expect(snapshot.text(for: language).body == lesson.text(for: language).body)
                            #expect(!snapshot.text(for: language).activities[activity.id]!.body.contains("{{"))
                        }
                        count += 1
                    }
                }
            }
        }
        #expect(count == 1080)
    }
}
