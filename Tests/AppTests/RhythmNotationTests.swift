import Testing
import Foundation
import Domain
import Audio
import Learning
import AgentBridge
@testable import PersonalGuitarCoach

struct RhythmNotationTests {
    @MainActor @Test func authoredLessonAdaptsAndPracticeCannotCutItsTie() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let lesson = try #require(LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons.first { $0.id == "dotted-tied-notes" })
        for tuning in TuningProfile.presets {
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                for entry in lesson.manifest.practiceEntries {
                    let snapshot = try lesson.resolveActivity(id: entry.activityID, instrument: instrument)
                    let request = try #require(PracticeRequest(lesson: lesson, snapshot: snapshot, entryID: entry.id))
                    let original = try #require(lesson.manifest.exercises.first { $0.id == entry.exerciseID })
                    #expect(request.exercise.events.map(\.assessSustain) == original.events.map(\.assessSustain))
                    #expect(request.exercise.events.map(\.positions) == original.events.map(\.positions))
                    for bpm in [request.exercise.minimumBPM, request.exercise.defaultBPM, request.exercise.maximumBPM] {
                        try request.exercise.validateForPractice(instrument: tuning, bpm: bpm)
                    }
                    if entry.id == "ties" {
                        let model = PracticeModel(audio: AudioSessionStore(repository: nil), calibration: CalibrationStore(repository: nil))
                        model.configure(request)
                        model.setBars(first: 2, last: 2)
                        #expect(model.firstBar == 1 && model.lastBar == 2 && model.rangeExpandedForSustain)
                        #expect(model.selectedEventIDs.contains("across"))
                        model.setBars(first: 1, last: 2)
                        #expect(!model.rangeExpandedForSustain)
                    }
                }
            }
        }
    }
    @Test func largestTraceFitsBoundedCoachEnvelopeAndPromptRetainsOnlySummary() throws {
        let trace = try SustainTrace(frames: (0..<SustainTrace.maximumFrames).map { i in
            try SustainFrame(id: UInt64(i + 1), normalizedTime: 123456789.123456 + Double(i) * 0.02,
                state: .pitched, frequency: 1234.567890123456)
        })
        let encoded = try CoachExchange.encode(trace)
        #expect(encoded.count > 2_000_000 && encoded.count < CoachAgentContract.maximumRequestBytes - 4_000_000)
        #expect(try JSONDecoder().decode(SustainTrace.self, from: encoded) == trace)
    }
    @Test func sustainFailureAndUncertaintyDoNotLookLikeSuccessfulAttacks() throws {
        let event = try MusicalEvent(id: "held", startTick: 0, durationTicks: 1920, kind: .note,
            positions: [FretPosition(string: 3, fret: 0)], assessSustain: true)
        let endpoint = try CalibrationEndpoint(uid: "synthetic-ui", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let config = try PracticeConfiguration(exercise: Exercise(id: "held-ui", events: [event]), instrument: InstrumentProfile(), bpm: 60,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture"))
        let start = try config.expectedStart(renderEpochSeconds: 100), hz = try TuningProfile.standard.frequency(at: event.positions[0])
        for unknown in [false, true] {
            let frames = try (0..<121).map { i in
                let elapsed = Double(i) * 0.02 - 0.1
                let state: SustainFrame.State = unknown ? .uncertain : elapsed < 1 ? .pitched : .silence
                return try SustainFrame(id: UInt64(i + 1), normalizedTime: start + elapsed, state: state, frequency: state == .pitched ? hz : nil)
            }
            let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(), finishedAt: Date(), phase: .completed,
                reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
                attacks: [PracticeAttack(id: 1, normalizedOnset: start, frequency: hz, clarity: 0.99, reliable: true)], clipping: [],
                sustainTrace: SustainTrace(frames: frames), analysisVersion: "synthetic-ui")
            let result = try AssessmentEngine.evaluate(evidence)
            #expect(ResultPresentation.annotations(result)["held"] == (unknown ? .uncertain : .sustain))
            #expect(unknown ? result.sustainScore == nil : (result.sustainScore ?? 100) < 50)
        }
    }
    private func note(_ id: String, _ start: Int64, _ duration: Int64, fret: Int = 1) throws -> MusicalEvent {
        try MusicalEvent(id: id, startTick: start, durationTicks: duration, kind: .note, positions: [FretPosition(string: 3, fret: fret)])
    }
    private func model(_ events: [MusicalEvent], signature: TimeSignature = .fourFour) throws -> StaffModel {
        try StaffModel(timeline: TimelineModel(exercise: Exercise(id: "rhythm", events: events, timeSignature: signature), instrument: .standard), key: .neutral)
    }

    @Test func dottedValuesKeepOneAttackAndTheirActualDuration() throws {
        for (ticks, base) in [(Int64(720), Int64(480)), (1440, 960), (2880, 1920)] {
            let source = try note("dotted", 0, ticks), staff = try model([source])
            let symbol = try #require(staff.symbols(in: 0).first)
            #expect(symbol.fragment.duration == NotationDuration(baseTicks: base, dotted: true))
            #expect(symbol.fragment.duration.ticks == source.durationTicks)
            #expect(!symbol.fragment.tieFromPrevious && !symbol.fragment.tieToNext)
            #expect(staff.timeline.exercise.events == [source] && staff.timeline.exercise.noteCount == 1)
            #expect(symbol.hasStem && symbol.hollow == (base == 1920))
        }
    }
    @Test func crossBarTieHasOneSourceAndResetsAccidentalsForTheNextAttack() throws {
        let events = try [note("held", 0, 4800), note("reattack", 4800, 960)]
        let staff = try model(events), first = try staff.symbols(in: 0), second = try staff.symbols(in: 1)
        #expect(first.count == 1 && second.count == 2)
        #expect(first[0].fragment.tieToNext && !first[0].fragment.tieFromPrevious)
        #expect(second[0].fragment.tieFromPrevious && !second[0].fragment.tieToNext)
        #expect(first[0].eventID == second[0].eventID && first[0].id != second[0].id)
        #expect(first[0].fragment.duration.ticks == 3840 && second[0].fragment.duration.ticks == 960)
        #expect(first[0].accidental == "♯" && second[0].accidental == nil && second[1].accidental == "♯")
        #expect(staff.timeline.events.map(\.id) == ["held", "reattack"])
        #expect(staff.adjacent(to: first[0].id, offset: 1)?.id == second[0].id)
        #expect(staff.adjacent(to: second[0].id, offset: -1)?.id == first[0].id)
        #expect(staff.adjacent(to: second[0].id, offset: 1)?.id == second[1].id)
        #expect(staff.adjacent(to: first[0].id, offset: -1) == nil)
        #expect(staff.adjacent(to: second[1].id, offset: 1) == nil)
    }
    @Test func offBeatSustainSplitsAtThePulseAndDoesNotDuplicateItsAccidental() throws {
        let rest = try MusicalEvent(id: "rest", startTick: 0, durationTicks: 480, kind: .rest)
        let staff = try model([rest, note("held", 480, 1920)])
        let symbols = try staff.symbols(in: 0)
        #expect(symbols.map(\.startTick) == [0,480,960])
        #expect(symbols.map { $0.fragment.duration.ticks } == [480,480,1440])
        #expect(symbols.map(\.accidental) == [nil,"♯",nil])
        #expect(symbols[1].fragment.tieToNext && symbols[2].fragment.tieFromPrevious)
        #expect(symbols[2].fragment.duration.dotted)
        #expect(staff.adjacent(to: symbols[1].id, offset: 1)?.id == symbols[2].id)
    }
    @Test func restsNeverReceiveTiesAndFragmentIDsCannotCollideWithAuthoredIDs() throws {
        let rest = try MusicalEvent(id: "rest", startTick: 0, durationTicks: 4800, kind: .rest)
        let staff = try model([rest, note("rest@3840", 4800, 960)])
        let symbols = try (0..<staff.timeline.barCount).flatMap { try staff.symbols(in: $0) }
        #expect(symbols.count == 3 && Set(symbols.map(\.id)).count == 3)
        #expect(symbols.prefix(2).allSatisfy { !$0.fragment.tieFromPrevious && !$0.fragment.tieToNext && $0.pitch == nil })
    }
    @Test func writtenBarlineDoesNotRestartPreviewOrCreateAnAssessmentAttack() throws {
        let source = try note("one-attack", 0, 4800), staff = try model([source])
        _ = try staff.symbols(in: 0); _ = try staff.symbols(in: 1)
        let exercise = staff.timeline.exercise
        let request = try TransportRequest(exercise: exercise, tuning: .standard, bpm: 60,
            countInBars: 0, clickEnabled: false, toneVolume: 1)
        let plan = try TransportPlan(request: request, sampleRate: 48000)
        let frequency = try TuningProfile.standard.pitch(at: source.positions[0]).frequency()
        let start: Int64 = 4 * 48000 - 200
        let rendered = try plan.render(startFrame: start, count: 400)
        for (offset, sample) in rendered.enumerated() {
            let expected = Float(0.2 * sin(2 * .pi * frequency * Double(start + Int64(offset)) / 48000))
            #expect(abs(sample - expected) < 0.000001)
        }
        let endpoint = try CalibrationEndpoint(uid: "notation-test", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let config = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "synthetic-notation"))
        #expect(config.selectedEvents == [source])
    }
    @Test func practiceRangeIncludesEntireTiedNotesAndExplainsTheExpandedBars() throws {
        let events = try [note("a", 0, 4800), note("b", 4800, 4800), note("c", 9600, 5760), note("separate", 15360, 3840)]
        let exercise = try Exercise(id: "range", events: events)
        #expect(PracticeBarSelection.completeEvents(in: exercise, first: 2, last: 2) == 1...4)
        #expect(PracticeBarSelection.completeEvents(in: exercise, first: 4, last: 4) == 1...4)
        #expect(PracticeBarSelection.completeEvents(in: exercise, first: 5, last: 5) == 5...5)
        let bars = PracticeBarSelection.completeEvents(in: exercise, first: 3, last: 3)
        let endpoint = try CalibrationEndpoint(uid: "range-test", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let config = try PracticeConfiguration(exercise: exercise, instrument: InstrumentProfile(), bpm: 60,
            range: Int64(bars.lowerBound - 1) * 3840..<Int64(bars.upperBound) * 3840,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "synthetic-notation"))
        #expect(config.selectedEvents.map(\.id) == ["a", "b", "c"])
    }
    @Test func everySimpleMeterSixteenthGridDurationIsConservedWithoutCrossingBars() throws {
        for signature in TimeSignature.allCases {
            for start in stride(from: Int64(0), to: signature.ticksPerBar, by: 240) {
                for duration in stride(from: Int64(240), through: signature.ticksPerBar * 3, by: 240) {
                    var events: [MusicalEvent] = []
                    if start > 0 { events.append(try MusicalEvent(id: "lead", startTick: 0, durationTicks: start, kind: .rest)) }
                    let source = try note("note", start, duration); events.append(source)
                    let staff = try model(events, signature: signature)
                    var fragments: [StaffSymbol] = []
                    for bar in 0..<staff.timeline.barCount {
                        let symbols = try staff.symbols(in: bar)
                        for symbol in symbols {
                            #expect(symbol.startTick >= bar * signature.ticksPerBar)
                            #expect(symbol.endTick <= (bar + 1) * signature.ticksPerBar)
                            if symbol.eventID == source.id { fragments.append(symbol) }
                        }
                    }
                    #expect(fragments.reduce(0) { $0 + $1.fragment.duration.ticks } == duration)
                    #expect(fragments.first?.startTick == start && fragments.last?.endTick == source.endTick)
                    #expect(zip(fragments, fragments.dropFirst()).allSatisfy { $0.endTick == $1.startTick })
                    #expect(fragments.dropFirst().allSatisfy { $0.fragment.tieFromPrevious })
                    #expect(fragments.dropLast().allSatisfy { $0.fragment.tieToNext })
                    #expect(staff.timeline.events.last?.event == source)
                }
            }
        }
    }
}
