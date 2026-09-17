import Foundation
import Testing
import Domain
@testable import Learning

struct ElectricStylesCourseTests {
    @Test func originalStyleFormsRetainIndependentMusicAcrossEveryPresetAndNeck() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        func joined(_ parts: [Int]...) -> [Int] { parts.flatMap { $0 } }
        func repeated(_ notes: [Int], _ count: Int) -> [Int] { (0..<count).flatMap { _ in notes } }
        let bluesRoute = [0,0,0,0,5,5,0,0,7,5,0,7]
        let bluesChords = bluesRoute.flatMap { n in [58+n,64+n,67+n] }
        let shuffle = repeated([48,55,48,57],4)
        let call = [60,63,65], answer = [67,65,63,60]
        let rock = [48,48,51,53,55,53,48], rockChords = [48,55,60,44,51,56,46,53,58], fill = [60,63,65,67,65,63,60]
        let c = [48,55,60], f = [53,60,65], ab = [56,63,68], bb = [58,65,70]
        let stops = joined(repeated(c,6), repeated(f,4), repeated(ab,2), c)
        let e5 = [40,47,52], g5 = [43,50,55], a5 = [45,52,57]
        let cm7 = [60,64,71], am7 = [60,64,67], dm7 = [60,65,69], g9 = [59,65,69]
        let country = [48,64,67,64,48,69,67,53,65,69,65,53,72,69]
        var targets: [String: [String: [Int]]] = [:]
        targets["blues-accompaniment"] = ["chord-map": bluesChords, "shuffle-cell": shuffle,
                "shuffle-form": bluesRoute.flatMap { n in shuffle.map { $0+n } }, "ending": [7,5,0,0].flatMap { n in [58+n,64+n,67+n] }]
        targets["blues-solo"] = ["plain-call": call, "bent-call": call, "vibrato-answer": answer,
                "twelve-bar-solo": joined(call, [60], answer, call, [65,63,60], answer, [67,70,67,65,63,60], answer, [60])]
        targets["classic-rock"] = ["main-riff": joined(rock, rock), "rhythm-part": joined(rockChords, rockChords), "one-bar-fill": fill,
                "eight-bar-arrangement": joined(rock, rock, rockChords, rockChords, rock, rock, fill, c)]
        targets["punk-hardcore"] = ["steady-eighths": repeated(c,8), "hard-stops": stops, "broad-pulse": joined(c, c, f, f),
                "eight-bar-form": joined(repeated(c,8), repeated(f,8), repeated(ab,8), repeated(bb,4), stops)]
        targets["metal-study"] = ["low-pedal": joined(repeated([40],8), [43,45,40]), "gallop-burst": repeated([40],12),
                "tuning-shapes": joined(e5, g5, a5, e5), "four-bar-riff": joined(repeated([40],16), g5, a5, repeated([40],12), g5, a5, e5)]
        targets["rnb-neo-soul"] = ["color-chords": joined(cm7, am7, dm7, g9), "top-line": [71,67,69,69],
                "inversion-choice": [60,64,67,64,67,72], "ornament-answer": joined(cm7, [64], dm7, [65]),
                "color-study": joined(cm7, [64], am7, dm7, [65], g9, cm7)]
        targets["country-chicken-picking"] = ["pick-finger-exchange": country, "short-upper-notes": [64,67,69,67,64,62,60,60],
                "scratch-response": [64,67,69,67], "country-study": joined(country, [64,67,69,67], [48,64,67,72,64,60])]
        let bars: [String: [String: Int64]] = [
            "blues-accompaniment": ["chord-map":12,"shuffle-cell":1,"shuffle-form":12,"ending":2],
            "blues-solo": ["plain-call":1,"bent-call":1,"vibrato-answer":1,"twelve-bar-solo":12],
            "classic-rock": ["main-riff":2,"rhythm-part":2,"one-bar-fill":1,"eight-bar-arrangement":8],
            "punk-hardcore": ["steady-eighths":2,"hard-stops":4,"broad-pulse":2,"eight-bar-form":8],
            "metal-study": ["low-pedal":2,"gallop-burst":2,"tuning-shapes":2,"four-bar-riff":4],
            "rnb-neo-soul": ["color-chords":4,"top-line":4,"inversion-choice":2,"ornament-answer":2,"color-study":4],
            "country-chicken-picking": ["pick-finger-exchange":2,"short-upper-notes":1,"scratch-response":1,"country-study":4]]
        var cases = 0
        for id in targets.keys.sorted() {
            let lesson = try #require(report.lessons.first { $0.id == id })
            #expect(lesson.manifest.curriculum?.moduleID == "electric-styles" && lesson.manifest.practiceEntries.isEmpty)
            #expect(lesson.manifest.tasks.contains { $0.kind == .selfPractice })
            for (index,tuning) in TuningProfile.presets.enumerated() {
                let shift = (id == "metal-study" ? [0,-2,-2,-4,-4,-6,-5,-7] : [0,0,-2,-2,-4,-4,-5,-5])[index]
                for frets in GuitarFretCount.allCases {
                    let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                    for activity in lesson.manifest.activities {
                        #expect(lesson.availableChoices(activityID: activity.id, instrument: instrument) == [.original])
                        let snapshot = try lesson.resolveActivity(id: activity.id, instrument: instrument)
                        let exercise = try #require(snapshot.exercises.first)
                        let pitches = try exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi)
                        #expect(pitches == targets[id]![activity.id]!.map { $0+shift }, "\(id)/\(activity.id)/\(tuning.id)")
                        #expect(exercise.durationTicks == bars[id]![activity.id]! * 3840)
                        #expect(exercise.events.flatMap(\.techniquePositions).allSatisfy(instrument.contains))
                        #expect(exercise.assessmentMode == .displayOnly)
                        #expect(throws: MusicError.displayOnlyExercise) { try exercise.validateForPractice(instrument: tuning, bpm: 60) }
                        if id == "blues-accompaniment" && activity.id.hasPrefix("shuffle") {
                            #expect(exercise.triplets.count == (activity.id == "shuffle-cell" ? 4 : 48))
                            #expect(exercise.events.enumerated().allSatisfy { $0.element.durationTicks == ($0.offset % 2 == 0 ? 640 : 320) })
                        }
                        if id == "blues-solo" && activity.id == "twelve-bar-solo" {
                            #expect(exercise.events.filter { $0.bend != nil }.map(\.startTick) == [960,16320])
                            #expect(exercise.events.filter { $0.vibrato != nil }.map(\.startTick) == [9600,24960,40320])
                            #expect(exercise.events.filter { $0.bend != nil }.allSatisfy { $0.bend?.semitones == 2 })
                        }
                        if id == "metal-study" {
                            if activity.id == "tuning-shapes" {
                                let first = exercise.events[0].positions
                                #expect(first.map(\.string) == [6,5,4])
                                #expect(first.map(\.fret) == (index % 2 == 0 ? [0,2,2] : [0,0,0]))
                            }
                            if activity.id == "gallop-burst" {
                                #expect(exercise.events.prefix(12).map(\.durationTicks) == (0..<4).flatMap { _ in [480,240,240] })
                                #expect(exercise.events.prefix(12).allSatisfy { $0.palmMuted })
                                #expect(exercise.events.last?.durationTicks == 3840 && exercise.events.last?.kind == .rest)
                            }
                        }
                        if id == "rnb-neo-soul" && ["ornament-answer","color-study"].contains(activity.id) {
                            let chains = exercise.events.compactMap(\.legatoChain)
                            #expect(chains.count == 2 && chains[0].targets.map(\.semitones) == [1,-1] && chains[1].targets.map(\.semitones) == [2,-2])
                        }
                        if id == "country-chicken-picking" {
                            #expect(exercise.events.filter { $0.positions.first?.string == 5 }.allSatisfy { $0.pickStroke == .down })
                            #expect(exercise.events.filter { !$0.positions.isEmpty && $0.positions[0].string < 5 }.allSatisfy { $0.pluckFinger != nil })
                            if ["scratch-response","country-study"].contains(activity.id) {
                                #expect(exercise.events.filter { $0.mutedAttack != nil }.count == 4)
                                #expect(exercise.events.compactMap(\.mutedAttack).allSatisfy { $0.strings == [3] })
                            }
                        }
                        for language in [LessonLanguage.en,.uk] {
                            let text = snapshot.text(for: language)
                            #expect(text.body == lesson.text(for: language).body && !text.activities[activity.id]!.body.contains("{{"))
                        }
                        cases += 1
                    }
                }
            }
        }
        #expect(cases == 1160)
    }
}
