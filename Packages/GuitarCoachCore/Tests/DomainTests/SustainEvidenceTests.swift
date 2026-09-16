import Foundation
import Testing
@testable import Domain

struct SustainEvidenceTests {
    @Test func authorOptInIsRestrictedToSingleNotesAndSurvivesCoding() throws {
        let position = try FretPosition(string: 6, fret: 0)
        let note = try MusicalEvent(id: "held", startTick: 0, durationTicks: 960, kind: .note, positions: [position], assessSustain: true)
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: JSONEncoder().encode(note)) == note)
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "rest", startTick: 0, durationTicks: 960, kind: .rest, assessSustain: true) }
        #expect(throws: MusicError.invalidExercise) { try Exercise(id: "display", events: [note], assessmentMode: .displayOnly) }
        let short = try MusicalEvent(id: "short", startTick: 0, durationTicks: 240, kind: .note, positions: [position], assessSustain: true)
        #expect(throws: MusicError.unsupportedDuration) { try Exercise(id: "short", events: [short]).validateForPractice(instrument: .standard, bpm: 60) }
        let legacy = Data(#"{"id":"old","startTick":0,"durationTicks":960,"kind":"note","positions":[{"string":6,"fret":0}]}"#.utf8)
        let old = try JSONDecoder().decode(MusicalEvent.self, from: legacy)
        #expect(!old.assessSustain)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        #expect(encoded["assessSustain"] == nil)
    }
    @Test func traceRejectsLostFramesReorderedTimesUnboundedDataAndInventedPitch() throws {
        let first = try SustainFrame(id: 1, normalizedTime: 10, state: .pitched, frequency: 110)
        let second = try SustainFrame(id: 2, normalizedTime: 10.02, state: .silence, frequency: nil)
        let valid = try SustainTrace(frames: [first, second])
        #expect(try JSONDecoder().decode(SustainTrace.self, from: JSONEncoder().encode(valid)) == valid)
        #expect(throws: PracticeError.invalidEvidence) { try SustainTrace(frames: [second, first]) }
        #expect(throws: PracticeError.invalidEvidence) { try SustainTrace(frames: [first, SustainFrame(id: 3, normalizedTime: 10.04, state: .silence, frequency: nil)]) }
        #expect(throws: PracticeError.invalidEvidence) { try SustainTrace(frames: Array(repeating: first, count: SustainTrace.maximumFrames + 1)) }
        #expect(throws: PracticeError.invalidEvidence) { try SustainFrame(id: 1, normalizedTime: 10, state: .pitched, frequency: nil) }
        #expect(throws: PracticeError.invalidEvidence) { try SustainFrame(id: 1, normalizedTime: 10, state: .silence, frequency: 110) }
    }
}
