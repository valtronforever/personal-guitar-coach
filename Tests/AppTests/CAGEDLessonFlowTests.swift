import Foundation
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

@MainActor struct CAGEDLessonFlowTests {
    @Test func dropMapShowsAllNotesWithoutPromisingOneGripThenOpensThePracticalFragment() throws {
        let root = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonCatalogLoader().load(directory:root.appendingPathComponent("Resources/Lessons"))
        let lesson = try #require(library.lessons.first { $0.id == "caged" })
        let instrument = InstrumentProfile(tuning:.dropC)
        let selection = LessonSelection(lesson:lesson,tuning:.dropC)
        selection.selectStep("g-family-map-shape")
        #expect(selection.failure == nil && selection.showsMusicalVisuals)
        #expect(selection.exercise?.assessmentMode == .displayOnly && selection.practiceEntries.isEmpty)
        let board = selection.fretboard(instrument:instrument)
        #expect(board.expected.count == 6 && board.fingers.isEmpty)
        #expect(board.expected.contains(try FretPosition(string:6,fret:10)))
        #expect(board.expected.contains(try FretPosition(string:4,fret:5)))
        selection.selectEvent("n1",exerciseID:"caged-g-family-map",extending:false)
        #expect(selection.fretboard(instrument:instrument).expected == [try FretPosition(string:6,fret:10)])
        selection.selectStep("g-family-fragment-shape")
        let fragment = selection.fretboard(instrument:instrument)
        #expect(selection.failure == nil && fragment.expected.count == 4 && fragment.mutedStrings == [5,6])
        #expect(!fragment.fingers.isEmpty && selection.practiceEntries.isEmpty)
        selection.selectStep("g-family-fragment-notes")
        #expect(selection.practiceEntries.map(\.id) == ["g-family-fragment-notes"])
        #expect(selection.exercise?.assessmentMode == .monophonic)
    }
}
