import AgentBridge
import Domain
import Foundation

enum CoachProvider: String, Codable, CaseIterable, Sendable { case codex, claude }

struct CoachAnalysisRequest: Codable, Sendable {
    let schemaVersion: Int
    let promptVersion: String
    let id: UUID
    let language: String
    let practiceDigest: String
    let audioFile: String
    let audio: CoachAudioReport
    let practice: AssessedPractice
    let alignment: String
    let lessonContext: String
    let recordingStartHostSeconds: Double?
    let renderEpochHostSeconds: Double?
    let expectedNotes: [String]

    var evidenceIDs: Set<String> {
        Set(["audio:summary", "practice:summary"] + audio.events.map(\.id) + audio.pitchSamples.map(\.id) + practice.notes.map { "practice:" + $0.id })
    }
}

struct CoachFinding: Codable, Sendable {
    let text: String
    let evidenceIDs: [String]
}

struct CoachFeedback: Codable, Sendable {
    let schemaVersion: Int
    let requestID: UUID
    let language: String
    let summary: String
    let findings: [CoachFinding]
}

struct CoachAnalysisResponse: Codable, Sendable {
    let schemaVersion: Int
    let provider: CoachProvider
    let createdAt: Date
    let request: CoachAnalysisRequest
    let feedback: CoachFeedback
}

enum CoachExchange {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    static func digest(_ practice: AssessedPractice) throws -> String { CoachAudioFile.hash(try encode(practice)) }

    static func prepare(audio: URL, channel: Int, practice: AssessedPractice, language: String,
                        lessonContext: String, take: CoachRecordedTake? = nil, id: UUID = UUID(),
                        previous: CoachAnalysisRequest? = nil) throws -> CoachAnalysisRequest {
        let report = try CoachAudioFile.analyze(audio, channel: channel)
        if let previous, previous.audio.sha256 != report.sha256 { throw CoachFileError.invalid }
        let config = practice.evidence.configuration
        let tuning = config.exercise.requiredTuning ?? config.instrument.tuning
        let expected = try config.selectedEvents.map { event -> String in
            let names = try event.positions.map { try tuning.pitch(at: $0).name(spelling: tuning.preferredSpelling) }.joined(separator: ", ")
            return "\(event.id): tick=\(event.startTick), durationTicks=\(event.durationTicks), sounding pitches=\(names), kind=\(event.kind.rawValue)"
        }
        return CoachAnalysisRequest(schemaVersion: 1, promptVersion: "file-coach-1", id: id,
            language: language == "uk" ? "uk" : "en", practiceDigest: try digest(practice),
            audioFile: "audio." + audio.pathExtension.lowercased(), audio: report, practice: practice,
            alignment: previous?.alignment ?? (take == nil ? "user-supplied-file; correspondence-and-start-offset-unverified" : "capture-host-time; metronome-render-reference; audible-output-delay-not-measured"),
            lessonContext: String((previous?.lessonContext ?? lessonContext).prefix(20_000)),
            recordingStartHostSeconds: take?.recording.firstHostSeconds ?? previous?.recordingStartHostSeconds,
            renderEpochHostSeconds: take?.renderEpoch ?? previous?.renderEpochHostSeconds, expectedNotes: expected)
    }

    static func readResponse(_ url: URL, practice: AssessedPractice) throws -> CoachAnalysisResponse {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: 2_000_001) ?? Data()
        guard data.count <= 2_000_000 else { throw CoachFileError.response }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let value = try decoder.decode(CoachAnalysisResponse.self, from: data)
        let request = value.request, feedback = value.feedback
        guard value.schemaVersion == 1, request.schemaVersion == 1, request.promptVersion == "file-coach-1",
              request.practice.id == practice.id, request.practiceDigest == (try digest(practice)),
              (try digest(request.practice)) == request.practiceDigest,
              ["user-supplied-file; correspondence-and-start-offset-unverified", "capture-host-time; metronome-render-reference; audible-output-delay-not-measured"].contains(request.alignment),
              feedback.schemaVersion == 1, feedback.requestID == request.id,
              ["en", "uk"].contains(request.language), feedback.language == request.language,
              !feedback.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, feedback.summary.count <= 2000,
              (1...8).contains(feedback.findings.count),
              request.audio.sha256.count == 64, request.audio.durationSeconds > 0,
              request.audio.durationSeconds <= CoachAudioFile.maximumSeconds,
              request.audio.events.count <= 12_000,
              request.audio.pitchSamples.count <= 1501,
              (request.audio.events + request.audio.pitchSamples).allSatisfy({ $0.seconds.isFinite && $0.seconds >= 0 && $0.seconds <= request.audio.durationSeconds }),
              feedback.findings.allSatisfy({ finding in
                  !finding.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && finding.text.count <= 1000 &&
                  (1...12).contains(finding.evidenceIDs.count) && Set(finding.evidenceIDs).count == finding.evidenceIDs.count && Set(finding.evidenceIDs).isSubset(of: request.evidenceIDs)
              }) else { throw CoachFileError.response }
        return value
    }

}
