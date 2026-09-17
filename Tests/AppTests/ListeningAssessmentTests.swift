import Foundation
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

@MainActor struct ListeningAssessmentTests {
    private let goldens: [String: [[Int]]] = [
        "find-heard-note": [[62,62],[59,59],[65,65],[61,61]],
        "hear-pitch-direction": [[60,60,60,60],[60,62,60,62],[62,65,62,65],[65,60,65,60],[60,67,60,67]],
        "repeat-a-rhythm": [[62,62,62,62],[62,62,62],[62,62,62,62],[62,62,62,62,62,62]],
        "transcribe-short-melody": [[60,62,60],[62,65,64,62],[60,60,62,65,64,62,60],[64,62,60,62,65,64,62]]
    ]
    private func lessons() throws -> [LoadedLesson] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons"))
        #expect(report.issues.isEmpty)
        return report.lessons.filter { goldens[$0.id] != nil }
    }
    @Test func allSeventeenResponsesKeepPitchRhythmAndPrivatePresentationAcrossPresetsAndNecks() throws {
        let lessons = try lessons(); #expect(lessons.count == 4)
        var count = 0
        for lesson in lessons {
            for (index, entry) in lesson.manifest.practiceEntries.enumerated() {
                let source = try #require(lesson.manifest.exercises.first { $0.id == entry.exerciseID })
                for (t, tuning) in TuningProfile.presets.enumerated() {
                    let expected = try #require(goldens[lesson.id]?[index]).map { $0 + [0,0,-2,-2,-4,-4,-5,-5][t] }
                    for frets in GuitarFretCount.allCases {
                        let target = try lesson.resolveActivity(id: entry.activityID, instrument: InstrumentProfile(tuning: tuning, frets: frets))
                        let request = try #require(PracticeRequest(lesson: lesson, snapshot: target, entryID: entry.id))
                        #expect(request.activityReference?.presentation == .listenAndRepeat)
                        #expect(try request.exercise.resolvedEvents(instrument: tuning).flatMap(\.pitches).map(\.midi) == expected)
                        #expect(request.exercise.events.map(\.startTick) == source.events.map(\.startTick))
                        #expect(request.exercise.events.map(\.durationTicks) == source.events.map(\.durationTicks))
                        for bpm in [50.0,60.0,90.0] { try request.exercise.validateForPractice(instrument: tuning, bpm: bpm) }
                        #expect(request.exercise.events.flatMap(\.positions).allSatisfy { $0.fret <= frets.rawValue })
                        count += 1
                    }
                }
            }
        }
        #expect(count == 680)
    }
    private func evidence(request: PracticeRequest, guided: Bool = false, calibrated: Bool = true, wrongPitch: Bool = false, late: Bool = false, confirmed: Bool = true) throws -> PracticeEvidence {
        let endpoint = try CalibrationEndpoint(uid: "listen-fixture", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture")
        let instrument = InstrumentProfile()
        let sync = try ManualInstrumentSyncEvidence(instrument: instrument, outputSetting: nil, remainingOffset: 0)
        let calibration = try calibrated ? CalibrationProfile(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, route: route, createdAt: Date(timeIntervalSince1970: 1), method: .manualPersonal, residualOffsetSeconds: 0, uncertaintySeconds: ManualInstrumentSyncEvidence.scoringAllowance, manualInstrumentEvidence: sync) : nil
        let conditions = try PracticeListeningConditions(referencePlaybackCompleted: true, targetsRevealed: guided)
        let config = try PracticeConfiguration(exercise: request.exercise, instrument: instrument, bpm: 60, route: route, calibration: calibration,
            lesson: PracticeLessonReference(id: request.lessonID, version: request.lessonVersion, activity: request.activityReference), listeningConditions: conditions)
        let start = try config.expectedStart(renderEpochSeconds: 100)
        let notes = config.selectedEvents.filter { $0.kind == .note }
        let attacks = try notes.enumerated().map { i, note in
            try PracticeAttack(id: UInt64(i+1), normalizedOnset: start + Double(note.startTick) / 960 + (late ? 0.15 : 0),
                frequency: instrument.tuning.pitch(at: note.positions[0]).frequency() * (wrongPitch ? pow(2,1.0/12) : 1), clarity: 0.99, reliable: true)
        }
        return try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 30),
            phase: confirmed ? .completed : .preflightFailed, reason: confirmed ? nil : .noTestSignal, signalConfirmed: confirmed, renderEpochSeconds: confirmed ? 100 : nil, maximumClockDriftSeconds: 0,
            attacks: confirmed ? attacks : [], clipping: [], analysisVersion: "synthetic-listening-evidence")
    }
    @Test func responseScoresMeasuredPitchAndTimingWhileGuidanceIsFrozenAndComparedSeparately() throws {
        for lesson in try lessons() {
            let entry = try #require(lesson.manifest.practiceEntries.first)
            let request = try #require(PracticeRequest(lesson: lesson, snapshot: lesson.resolveActivity(id: entry.activityID, instrument: InstrumentProfile()), entryID: entry.id))
            let hidden = try AssessmentEngine.evaluate(evidence(request: request))
            let guided = try AssessmentEngine.evaluate(evidence(request: request, guided: true))
            let wrong = try AssessmentEngine.evaluate(evidence(request: request, wrongPitch: true))
            let late = try AssessmentEngine.evaluate(evidence(request: request, late: true))
            let uncalibrated = try AssessmentEngine.evaluate(evidence(request: request, calibrated: false))
            let absent = try AssessmentEngine.evaluate(evidence(request: request, confirmed: false))
            #expect(hidden.overallScore == 100 && guided.overallScore == 100)
            #expect(wrong.pitchScore == 0 && late.timingScore! < hidden.timingScore!)
            #expect(uncalibrated.timingScore == nil && absent.overallScore == nil)
            #expect(hidden.evidence.configuration.listeningConditions?.usedHiddenTargets == true)
            #expect(PracticeComparison.compatible(hidden, try AssessmentEngine.evaluate(evidence(request: request))))
            #expect(!PracticeComparison.compatible(hidden, guided))
            #expect(try JSONDecoder().decode(AssessedPractice.self, from: JSONEncoder().encode(hidden)) == hidden)
            #expect(CoachExchange.promptVersion(for: hidden) == "file-coach-7")
            let recommendations = FeedbackEngine.recommendations(for: wrong)
            if let recommendation = recommendations.first(where: { $0.action == .repeatFragment }) {
                let retry = try #require(PracticeRequest(result: wrong, recommendation: recommendation))
                #expect(retry.activityReference?.presentation == .listenAndRepeat)
            }
        }
    }
}
