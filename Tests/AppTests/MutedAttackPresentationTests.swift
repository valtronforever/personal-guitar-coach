import Foundation
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

@MainActor struct MutedAttackPresentationTests {
    @Test func crossHeadsKeepRhythmWithoutPitchOrAccidentalAndBeamAroundRests() throws {
        let events = try (0..<8).map { index -> MusicalEvent in
            if index == 2 { return try MusicalEvent(id: "rest", startTick: Int64(index * 480), durationTicks: 480, kind: .rest) }
            return try MusicalEvent(id: "x-\(index)", startTick: Int64(index * 480), durationTicks: 480, kind: .note,
                mutedAttack: MutedStringAttack(strings: [1,2,3], direction: index % 2 == 0 ? .down : .up))
        }
        let timeline = try TimelineModel(exercise: Exercise(id: "unpitched", events: events, assessmentMode: .displayOnly), instrument: .cStandard)
        let model = StaffModel(timeline: timeline, key: .fMajor), symbols = try model.symbols(in: 0)
        #expect(symbols.count == 8 && symbols.allSatisfy { $0.pitch == nil && $0.accidental == nil })
        #expect(symbols.filter { $0.eventID != "rest" }.allSatisfy { $0.engravingStep == 34 && $0.hasStem && $0.flags == 1 })
        #expect(symbols[2].engravingStep == nil && !symbols[2].hasStem)
        #expect(model.beams(symbols).map { $0.ids.count } == [2,2,2])
        #expect(timeline.segments(in: 0).allSatisfy { $0.displayPitches.isEmpty && $0.displayPositions.isEmpty })
        #expect(model.beams(symbols).flatMap(\.ids).allSatisfy { $0.eventID != "rest" })
    }
    @Test func selectedScratchShowsMutedStringsRatherThanOpenStringPitchTargets() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        let lesson = try #require(report.lessons.first { $0.id == "funk-study" })
        let selection = LessonSelection(lesson: lesson, tuning: .cStandard)
        selection.selectStep("muted-grid")
        let board = selection.fretboard(instrument: InstrumentProfile(tuning: .cStandard, frets: .nineteen))
        #expect(board.expected.isEmpty && board.targets.isEmpty && board.mutedStrings == [1,2,3])
        #expect(board.isMuted(try FretPosition(string: 1, fret: 0)))
        #expect(!board.isMuted(try FretPosition(string: 6, fret: 0)))
        #expect(lesson.manifest.practiceEntries.isEmpty)
    }
}
