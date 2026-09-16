import AVFoundation
import Domain
import Learning
import Audio
import Testing
@testable import PersonalGuitarCoach

struct CoachAudioTests {
    @MainActor @Test func recordingReservationPreventsAnotherJobFromTakingItsSlot() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = AgentCoachStore(root: root), first = UUID(), other = UUID()
        #expect(store.reserveRecording(first))
        #expect(!store.reserveRecording(other))
        store.releaseRecording(other)
        #expect(store.busyAttempt == first)
        store.releaseRecording(first)
        #expect(store.busyAttempt == nil && store.reserveRecording(other))
        store.releaseRecording(other)
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func wav(_ url: URL, silence: Bool = false) throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000))
        buffer.frameLength = 48000
        let channels = try #require(buffer.floatChannelData)
        for i in 0..<48000 {
            channels[0][i] = silence ? 0 : Float(sin(Double(i) * 2 * .pi * 220 / 48000) * 0.25)
            channels[1][i] = 0
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
    @Test func importedWAVHonorsChannelAndSilenceWithoutInventingPitch() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("quote ' and $() ü.wav"); try wav(source)
        let guitar = try CoachAudioFile.analyze(source, channel: 1), silent = try CoachAudioFile.analyze(source, channel: 2)
        #expect(guitar.sha256 == silent.sha256 && guitar.durationSeconds == 1)
        #expect(guitar.rms > 0.1 && silent.rms == 0 && silent.events.allSatisfy { $0.frequency == nil })
        #expect(guitar.observationsByQuality["reliable", default: 0] > 0)
        #expect(throws: CoachFileError.channel) { try CoachAudioFile.analyze(source, channel: 3) }
        let bad = root.appendingPathComponent("bad.mp3"); try Data("not audio".utf8).write(to: bad)
        #expect(throws: (any Error).self) { try CoachAudioFile.analyze(bad, channel: 1) }
    }
    @Test func genuineMP3DecodesWithFinitePitchMeasurements() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let report = try CoachAudioFile.analyze(root.appendingPathComponent("Fixtures/AgentCoach/sine-220hz.mp3"), channel: 1)
        #expect(report.sampleRate == 48000 && report.durationSeconds >= 1 && report.durationSeconds < 1.2)
        #expect(report.observationsByQuality["reliable", default: 0] > 0)
        #expect(report.pitchSamples.contains { abs(($0.frequency ?? 0) - 220) < 2 })
    }
    @MainActor @Test func stereoRecordingKeepsGuitarCleanAndAlignsClickReferenceToHostTime() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let result = try AssessmentFixtureView.result("valid"), config = result.evidence.configuration
        let transport = try TransportRequest(exercise: config.exercise, tuning: config.instrument.tuning, bpm: config.bpm, mode: .practice)
        let take = CoachRecordedTake(recording: PracticeRecording(samples: [Float](repeating: 0, count: 48000), sampleRate: 48000, firstHostSeconds: 99.75), renderEpoch: 100, transport: transport)
        let url = root.appendingPathComponent("audio.wav"); try take.write(to: url)
        let file = try AVAudioFile(forReading: url)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 48000))
        try file.read(into: buffer)
        let channels = try #require(buffer.floatChannelData)
        #expect((0..<48000).allSatisfy { channels[0][$0] == 0 })
        #expect((0..<12000).allSatisfy { channels[1][$0] == 0 })
        #expect((12000..<12600).contains { abs(channels[1][$0]) > 0.01 })
        let request = try CoachExchange.prepare(audio: url, channel: 1, practice: result, language: "uk", lessonContext: "Мета уроку", take: take)
        #expect(request.recordingStartHostSeconds == 99.75 && request.renderEpochHostSeconds == 100)
        #expect(request.audio.rms == 0 && request.practice == result && request.lessonContext == "Мета уроку")
        #expect(request.alignment.contains("audible-output-delay-not-measured"))
    }
    @MainActor @Test func replyCannotCrossAttemptsOrCiteInventedEvidence() throws {
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("audio.wav"); try wav(url)
        let result = try AssessmentFixtureView.result("uncalibrated")
        let request = try CoachExchange.prepare(audio: url, channel: 1, practice: result, language: "uk", lessonContext: "Goal")
        #expect(request.alignment.contains("unverified") && request.practice.timingScore == nil)
        let file = root.appendingPathComponent("response.json")
        func write(_ refs: [String], language: String = "uk") throws {
            let feedback = CoachFeedback(schemaVersion: 1, requestID: request.id, language: language,
                summary: "Синтетична перевірка", findings: [CoachFinding(text: "Перевірте калібрування", evidenceIDs: refs)])
            try CoachExchange.encode(CoachAnalysisResponse(schemaVersion: 1, provider: .codex, createdAt: Date(), request: request, feedback: feedback)).write(to: file)
        }
        try write(["practice:summary"])
        #expect(try CoachExchange.readResponse(file, practice: result).feedback.language == "uk")
        #expect(throws: (any Error).self) { try CoachExchange.readResponse(file, practice: AssessmentFixtureView.result("valid")) }
        try write(["audio:invented"])
        #expect(throws: CoachFileError.response) { try CoachExchange.readResponse(file, practice: result) }
        try write(["practice:summary"], language: "en")
        #expect(throws: CoachFileError.response) { try CoachExchange.readResponse(file, practice: result) }
    }
    @Test func bendExchangeVersionsAndPreservesUnscoredObservationIDs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bend-coach-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("audio.wav"); try wav(url)
        let event = try MusicalEvent(id: "bend", startTick: 0, durationTicks: 2880, kind: .note,
            positions: [FretPosition(string: 3, fret: 9)], bend: PitchBend(semitones: 1, riseStartTick: 480, riseEndTick: 960))
        let endpoint = try CalibrationEndpoint(uid: "bend-coach", channel: 1, sampleRate: 48000, bufferFrames: 512)
        let config = try PracticeConfiguration(exercise: Exercise(id: "bend-coach", events: [event]), instrument: InstrumentProfile(), bpm: 60,
            route: CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "fixture"))
        let start = try config.expectedStart(renderEpochSeconds: 100), hz = try Pitch(midi: 64).frequency()
        let trace = try PitchContourTrace(frames: (0..<161).map { try SustainFrame(id: UInt64($0 + 1), normalizedTime: start - 0.1 + Double($0) * 0.02, state: .pitched, frequency: hz) })
        let evidence = try PracticeEvidence(id: UUID(), configuration: config, startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 10),
            phase: .completed, reason: nil, signalConfirmed: true, renderEpochSeconds: 100, maximumClockDriftSeconds: 0,
            attacks: [PracticeAttack(id: 1, normalizedOnset: start, frequency: hz, clarity: 0.99, reliable: true),
                      PracticeAttack(id: 2, normalizedOnset: start + 1.2, frequency: nil, clarity: nil, reliable: false)],
            clipping: [], pitchContour: trace, analysisVersion: "fixture")
        let result = try AssessmentEngine.evaluate(evidence)
        let request = try CoachExchange.prepare(audio: url, channel: 1, practice: result, language: "uk", lessonContext: "Bend")
        #expect(request.promptVersion == "file-coach-2" && request.unscoredBendObservationIDs == [2])
        let response = CoachAnalysisResponse(schemaVersion: 1, provider: .codex, createdAt: Date(), request: request,
            feedback: CoachFeedback(schemaVersion: 1, requestID: request.id, language: "uk", summary: "Bend", findings: [CoachFinding(text: "Target", evidenceIDs: ["practice:bend"])]))
        let file = root.appendingPathComponent("response.json"), bytes = try CoachExchange.encode(response)
        try bytes.write(to: file)
        #expect(try CoachExchange.readResponse(file, practice: result).request.unscoredBendObservationIDs == [2])
        var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var altered = try #require(object["request"] as? [String: Any]); altered["unscoredBendObservationIDs"] = []
        object["request"] = altered
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        #expect(throws: CoachFileError.response) { try CoachExchange.readResponse(file, practice: result) }
    }

}
