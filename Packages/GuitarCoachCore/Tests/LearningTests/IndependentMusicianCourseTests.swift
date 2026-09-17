import Foundation
import Testing
import Domain
@testable import Learning

struct IndependentMusicianCourseTests {
    private struct Event {
        let pitches: [Int]
        let beats: Double
        var held: [Int] = []
    }
    private func n(_ pitch: Int, _ beats: Double) -> Event { Event(pitches: [pitch], beats: beats) }
    private func r(_ beats: Double) -> Event { Event(pitches: [], beats: beats) }
    private func chord(_ pitches: [Int], _ beats: Double, held: [Int] = []) -> Event { Event(pitches: pitches, beats: beats, held: held) }
    private func joined(_ phrases: [Event]...) -> [Event] { phrases.flatMap { $0 } }
    private func goldens() -> [String: [String: [Event]]] {
        let a = [n(60,0.5),n(63,0.5),n(65,1),n(67,1),r(1)]
        let b = [n(67,1),n(65,0.5),n(63,0.5),n(60,1),r(1)]
        let c = [n(60,0.5),n(60,0.5),n(63,1),n(65,0.5),n(63,0.5),n(60,1)]
        let d = [n(63,1),n(62,1),n(60,1),r(1)]
        let riff = joined(a,b,c,d)
        let seed = [n(60,0.5),n(60,0.5),n(63,1),n(65,1),r(1)]
        let variant = [n(60,0.5),n(63,0.5),n(65,0.5),n(63,0.5),n(60,1),r(1)]
        let ending = [n(65,1),n(63,1),n(60,1),r(1)]
        var all: [String: [String: [Event]]] = [:]
        all["transcribe-riff-solo"] = ["phrase-a":a,"phrase-b":b,"phrase-c":c,"phrase-d":d,"complete-reference":riff]
        all["reading-music-formats"] = [
            "first-reading":[n(60,1),n(62,0.5),n(64,0.5),n(65,1),r(1),n(67,2),n(64,1),n(60,1)],
            "compact-shape":[chord([60,64,67],4)],
            "timed-chord":[chord([60,64,67],2),r(2),r(1),chord([60,64,67],1),r(2)],
            "chord-tone-reading":[n(60,1),n(64,1),n(67,1),r(1)],
            "second-reading":[r(1),n(64,1),n(62,0.5),n(60,0.5),n(62,1),n(65,1),n(64,1),n(60,2)]]
        all["write-a-riff"] = ["seed":seed,"variation":variant,"ending":ending,"four-bar-riff":joined(seed,seed,variant,ending)]
        let roots = [48,43,48,48], upper = [[64,67],[62,67],[64,62],[64,60]]
        var combined: [Event] = []
        for index in 0..<4 {
            combined.append(chord([roots[index]],1))
            combined.append(chord([roots[index],upper[index][0]],1,held: [index == 1 ? 6 : 5]))
            combined.append(chord([roots[index],upper[index][1]],2,held: [index == 1 ? 6 : 5]))
        }
        all["arrange-two-guitars"] = [
            "lower-role":roots.map { n($0,4) },
            "upper-role":upper.flatMap { [r(1),n($0[0],1),n($0[1],2)] },
            "combined-roles":combined,
            "more-space":upper.flatMap { [r(2),n($0[1],1),r(1)] }]
        let chords = [[60,64,67],[59,62,67],[60,64,67],[60,64,67]]
        let sparse = chords.flatMap { [r(1),chord($0,0.5),r(1.5),chord($0,0.5),r(0.5)] }
        let offbeat = chords.flatMap { [r(0.5),chord($0,0.5),r(1.5),chord($0,0.5),r(1)] }
        all["play-with-rhythm-section"] = [
            "foundation":roots.flatMap { [n($0,1),r(1),n($0,1),r(1)] },
            "sparse-guitar":sparse,"offbeat-guitar":offbeat,
            "ensemble-break":joined(Array(sparse.prefix(15)),[chord([60,64,67],1),r(3)])]
        let intro = [r(2),n(67,1),n(63,1)], outro = [n(60,2),r(2)]
        let bridge = [n(68,2),n(67,2),n(65,1),n(63,1),n(62,1),r(1)]
        let piece = joined(intro,a,b,c,b,bridge,outro)
        let boundary = joined(b,Array(bridge.prefix(2)))
        all["prepare-composition"] = ["entrance":intro,"main-idea":joined(a,b),"varied-return":joined(c,b),
            "bridge":bridge,"join-into-bridge":boundary,"ending":outro,"complete-miniature":piece]
        all["performance-recording"] = ["complete-performance":piece,"transition-repair":boundary,"ending-repair":joined(Array(bridge.suffix(4)),outro)]
        all["personal-practice-plan"] = [
            "technique-check":[n(60,0.5),n(61,0.5),n(62,0.5),n(63,0.5),n(62,0.5),n(61,0.5),n(60,0.5),r(0.5)],
            "rhythm-check":[n(60,1),r(0.5),n(60,0.5),r(1),n(60,1),r(1),n(60,0.5),r(0.5),n(60,1),r(1)],
            "ear-check":[n(64,1),n(62,1),n(65,1),r(1),n(64,1),n(60,2),r(1)],
            "musical-transfer":riff]
        return all
    }
    private func catalog() -> LessonCatalogReport {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
    }
    @Test func originalMusicFormAndRoleSeparationSurviveEveryPresetAndNeck() throws {
        let report = catalog(); #expect(report.issues.isEmpty)
        var cases = 0, graded = 0, recordings = 0
        for (id, expected) in goldens() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(Set(lesson.manifest.activities.map(\.id)) == Set(expected.keys))
            graded += lesson.manifest.practiceEntries.count
            recordings += lesson.manifest.activities.filter { $0.recording == .selfPractice }.count
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift = [0,0,-2,-2,-4,-4,-5,-5][index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for (activity, events) in expected {
                        #expect(lesson.availableChoices(activityID: activity, instrument: instrument) == [.original])
                        let snapshot = try lesson.resolveActivity(id: activity, instrument: instrument)
                        let exercise = try #require(snapshot.exercises.first)
                        let resolved = try exercise.resolvedEvents(instrument: tuning)
                        #expect(resolved.map { $0.pitches.map(\.midi).sorted() } == events.map { $0.pitches.map { $0 + shift }.sorted() }, "\(id)/\(activity)/\(tuning.id)")
                        #expect(exercise.events.map(\.durationTicks) == events.map { Int64($0.beats * 960) })
                        #expect(exercise.events.map(\.heldStrings) == events.map(\.held))
                        #expect(exercise.events.flatMap(\.positions).allSatisfy(instrument.contains))
                        if activity == "compact-shape" {
                            let visual = try snapshot.visual(stepID: "compact-shape")
                            #expect(visual.mutedStrings == [4,5,6] && Set(visual.positions.map { $0.position.string }) == [1,2,3])
                            #expect(visual.positions.allSatisfy { $0.finger != nil })
                        }
                        var start: Int64 = 0
                        for (actual, expected) in zip(exercise.events,events) {
                            #expect(actual.startTick == start && (actual.kind == .rest) == expected.pitches.isEmpty)
                            start += Int64(expected.beats * 960)
                        }
                        #expect(exercise.durationTicks == start && start % 3840 == 0)
                        if lesson.manifest.practiceEntries.contains(where: { $0.activityID == activity }) {
                            #expect(exercise.assessmentMode == .monophonic)
                            for tempo in [40.0,60,120] { try exercise.validateForPractice(instrument: tuning,bpm: tempo) }
                        } else {
                            #expect(exercise.assessmentMode == .displayOnly)
                            #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning,bpm: 60) }
                        }
                        if snapshot.activity.recording == .selfPractice {
                            #expect(snapshot.material.source.kind == .exercise && exercise.assessmentMode == .displayOnly)
                            #expect(try MusicalTime.seconds(forTicks: exercise.durationTicks, bpm: 40) <= 120)
                        }
                        for language in [LessonLanguage.en,.uk] {
                            #expect(!snapshot.text(for: language).activities[activity]!.body.contains("{{"))
                        }
                        cases += 1
                    }
                }
            }
        }
        #expect(cases == 1440 && graded == 14 && recordings == 10)
    }
    @Test func completeCourseHasSubstantialBilingualTeachingHiddenEarTargetsAndActualRecordingPath() throws {
        let report = catalog(); #expect(report.issues.isEmpty)
        let lessons = report.lessons.filter { $0.manifest.curriculum?.moduleID == "independent-musician" }
        #expect(lessons.count == 8 && Set(lessons.compactMap { $0.manifest.curriculum?.ordinal }) == Set(121...128))
        var hidden = 0
        for lesson in lessons {
            #expect(lesson.manifest.tasks.contains { $0.kind == .selfPractice && $0.itemIDs.count >= 4 })
            for language in [LessonLanguage.en,.uk] {
                let text = lesson.text(for: language)
                #expect(text.body.split(whereSeparator: \.isWhitespace).count >= (language == .en ? 340 : 260))
                #expect(text.body.components(separatedBy: "\n\n").count == 5)
                #expect(!text.goal.isEmpty && !text.summary.isEmpty)
            }
            for entry in lesson.manifest.practiceEntries where entry.presentation == .listenAndRepeat {
                hidden += 1
                let step = try #require(lesson.manifest.steps.first { $0.activityID == entry.activityID })
                #expect(step.kind == .none && step.eventIDs.isEmpty && step.exerciseID == nil)
                let material = try #require(lesson.manifest.materials.first { $0.id == entry.activityID })
                #expect(material.tonalRoot == nil && !material.policy.enabled)
                for language in [LessonLanguage.en,.uk] {
                    #expect(!lesson.text(for: language).activities[entry.activityID]!.body.contains("{{"))
                }
            }
        }
        #expect(hidden == 6)
        let prepared = try #require(lessons.first { $0.id == "prepare-composition" }?.manifest.exercises.first { $0.id.hasSuffix("complete-miniature") })
        let recorded = try #require(lessons.first { $0.id == "performance-recording" }?.manifest.exercises.first { $0.id.hasSuffix("complete-performance") })
        #expect(prepared.events == recorded.events && prepared.durationTicks == 8 * 3840)
        #expect(prepared.events.first?.kind == .rest && prepared.events.first?.durationTicks == 1920)
        #expect(prepared.events.last?.kind == .rest && prepared.events.last?.durationTicks == 1920)
        let arrangement = try #require(lessons.first { $0.id == "arrange-two-guitars" }?.manifest.exercises.first { $0.id.hasSuffix("combined-roles") })
        #expect(arrangement.referenceVoiceSpans.count == 12)
        #expect(arrangement.referenceVoiceSpans.filter { $0.position.string >= 5 }.map { $0.endTick - $0.startTick } == [3840,3840,3840,3840])
    }
}
