import Foundation
import Testing
import Domain
import Learning
import Persistence
@testable import PersonalGuitarCoach

@MainActor struct RapidRhythmFlowTests {
    private var root: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func result(bpm: Double) throws -> AssessedPractice {
        let lesson = try #require(LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons.first { $0.id == "tremolo-picking" })
        let instrument = InstrumentProfile(tuning: .cStandard, frets: .nineteen)
        let resolved = try lesson.resolveActivity(id: "fast-short", instrument: instrument)
        let request = try #require(PracticeRequest(lesson: lesson, snapshot: resolved, entryID: "fast-short"))
        let endpoint = try CalibrationEndpoint(uid: "synthetic", channel: 1, sampleRate: 48000, bufferFrames: 512, deviceLatencyFrames: 0, streamLatencyFrames: 0)
        let route = try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "synthetic")
        let manual = try ManualInstrumentSyncEvidence(instrument: instrument, outputSetting: nil, remainingOffset: 0.08)
        let calibration = try CalibrationProfile(route: route, method: .manualPersonal, residualOffsetSeconds: 0.08,
            uncertaintySeconds: ManualInstrumentSyncEvidence.scoringAllowance, manualInstrumentEvidence: manual)
        let configuration = try PracticeConfiguration(exercise: request.exercise, instrument: instrument, bpm: bpm, route: route, calibration: calibration)
        let start = try configuration.expectedStart(renderEpochSeconds: 100), seconds = request.exercise.timeSignature.secondsPerTick(bpm: bpm)
        let notes = configuration.selectedEvents.filter { $0.kind == .note }
        let attacks = try notes.enumerated().map { try PracticeAttack(id: UInt64($0.offset + 1), normalizedOnset: start + Double($0.element.startTick) * seconds + 0.08, frequency: nil, clarity: nil, reliable: false) }
        let frames = try (0..<Int((configuration.durationSeconds + 0.2) / 0.02)).map { index in
            let relative = Double(index) * 0.02
            let sounding = notes.contains { relative >= Double($0.startTick) * seconds && relative < Double($0.endTick) * seconds }
            return try SustainFrame(id: UInt64(index + 1), normalizedTime: start + relative + 0.08,
                state: sounding ? .pitched : .silence, frequency: sounding ? 207.6523 : nil)
        }
        let input = try PracticeEvidence(id: UUID(), configuration: configuration, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 20),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: attacks, clipping: [], pitchContour: PitchContourTrace(frames: frames), analysisVersion: "synthetic-rapid-flow")
        return try AssessmentEngine.evaluate(input)
    }
    @Test func manualAlignmentHasAnExplicitTempoLimitAndNeverProducesPitchAdvice() throws {
        let slow = try result(bpm: 40), fast = try result(bpm: 100)
        #expect(slow.validity == .valid && slow.rhythmCapability == .approximate)
        #expect(slow.overallScore == 100 && slow.pitchScore == nil && slow.timingScore == 100)
        #expect(fast.validity == .uncalibrated && fast.rhythmCapability == .uncertain)
        #expect(fast.overallScore == nil && fast.pitchScore == nil && fast.timingScore == nil)
        #expect(ResultPresentation.annotations(fast).isEmpty)
        #expect(!FeedbackEngine.recommendations(for: slow).contains { $0.kind == .pitch || $0.kind == .tuning })
        #expect(FeedbackEngine.recommendations(for: fast).first?.kind == .calibration)
        #expect(CoachExchange.promptVersion(for: slow) == "file-coach-11")
        #expect(slow.parameters == .rhythmOnly)
    }
    @Test func historyRoundTripKeepsAbsentPitchAndFrozenRhythmMode() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalRepository(root: directory)
        for bpm in [40.0,100.0] {
            let assessment = try result(bpm: bpm), record = try PracticeRecord(assessment: assessment)
            try await repository.save(record)
            #expect(try JSONDecoder().decode(PracticeRecord.self, from: JSONEncoder().encode(record)) == record)
        }
        let reopened = LocalRepository(root: directory)
        let history = try await reopened.history()
        #expect(history.issues.isEmpty && history.records.count == 2)
        #expect(history.records.allSatisfy { $0.result.payload.pitchScore == nil && $0.exercise.assessmentMode == .rhythmOnly })
        #expect(history.records.allSatisfy { $0.assessment?.payload.parameters == .rhythmOnly })
    }
    @Test func lessonSelectionRetainsRhythmModeAcrossEveryPresetAndNeck() throws {
        let lesson = try #require(LessonCatalogLoader().load(directory: root.appendingPathComponent("Resources/Lessons")).lessons.first { $0.id == "tremolo-picking" })
        for tuning in TuningProfile.presets {
            for frets in GuitarFretCount.allCases {
                let instrument = InstrumentProfile(tuning: tuning, frets: frets)
                let selection = LessonSelection(lesson: lesson, tuning: tuning)
                selection.updateInstrument(instrument); selection.selectStep("fast-short")
                let snapshot = try lesson.resolveActivity(id: "fast-short", instrument: instrument)
                let request = try #require(PracticeRequest(lesson: lesson, snapshot: snapshot, entryID: "fast-short"))
                let model = PracticeModel(audio: AudioSessionStore(repository: nil), calibration: CalibrationStore(repository: nil))
                model.configure(request)
                #expect(model.request?.exercise.assessmentMode == .rhythmOnly)
                #expect(request.exercise.maximumBPM == 100)
                #expect(request.lessonVersion == 2)
            }
        }
    }
}
