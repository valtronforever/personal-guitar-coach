import Foundation
import Testing
import Domain
@testable import Audio

struct AccentPreviewTests {
    @Test func accentChangesReferenceLoudnessWithoutChangingTimingOrPracticeAudio() throws {
        let position = try FretPosition(string: 3, fret: 0)
        func exercise(_ accented: Bool) throws -> Exercise {
            try Exercise(id: "accent", events: [MusicalEvent(id: "tone", startTick: 0, durationTicks: 1920, kind: .note,
                positions: [position], accented: accented)])
        }
        for rate in [44100.0, 48000.0] {
            func plan(_ accented: Bool, _ mode: TransportMode) throws -> TransportPlan {
                try TransportPlan(request: TransportRequest(exercise: exercise(accented), tuning: .standard, bpm: 60,
                    mode: mode, clickEnabled: false), sampleRate: rate)
            }
            let normal = try plan(false, .preview), accent = try plan(true, .preview)
            #expect(normal.endFrame == accent.endFrame && normal.practiceStartFrame == accent.practiceStartFrame)
            let start = normal.practiceStartFrame + Int64(rate * 0.1)
            let a = try normal.render(startFrame: start, count: 10000)
            let b = try accent.render(startFrame: start, count: 10000)
            #expect(zip(a,b).allSatisfy { abs($1 - $0 * 1.5) < 1e-6 })
            #expect(b.map(abs).max()! <= 0.3)
            let muted = try plan(true, .practice)
            #expect(try muted.render(startFrame: start, count: 10000).allSatisfy { $0 == 0 })
        }
    }
    @Test func defaultAccentPreservesArchivedEncodingAndRestsRejectAccent() throws {
        let original = Data(#"{"id":"n","startTick":0,"durationTicks":960,"kind":"note","positions":[{"string":3,"fret":0}]}"#.utf8)
        let note = try JSONDecoder().decode(MusicalEvent.self, from: original)
        #expect(!note.accented)
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
        #expect(object["accented"] == nil)
        let marked = try MusicalEvent(id: "accent", startTick: 0, durationTicks: 960, kind: .note, positions: note.positions, accented: true)
        #expect(try JSONDecoder().decode(MusicalEvent.self, from: JSONEncoder().encode(marked)) == marked)
        #expect(throws: MusicError.invalidEvent) { try MusicalEvent(id: "rest", startTick: 0, durationTicks: 960, kind: .rest, accented: true) }
    }
}
