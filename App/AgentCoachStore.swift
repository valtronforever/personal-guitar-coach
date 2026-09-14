import AgentBridge
import Domain
import SwiftUI

/// One opt-in job at a time. Files/results are separate from immutable numeric assessments.
@MainActor @Observable final class AgentCoachStore {
    static let shared = AgentCoachStore()
    private(set) var busyAttempt: UUID?
    private(set) var responses: [UUID: CoachAnalysisResponse] = [:]
    private(set) var errors: [UUID: String] = [:]
    private(set) var savedRequests: [UUID: CoachAnalysisRequest] = [:]
    private(set) var deletionFailed = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var connection: NSXPCConnection?
    @ObservationIgnored private var continuation: CheckedContinuation<Data, Error>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let root: URL
    var provider: CoachProvider {
        get { CoachProvider(rawValue: UserDefaults.standard.string(forKey: "coach.provider") ?? "codex") ?? .codex }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "coach.provider") }
    }
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PersonalGuitarCoach/AgentCoach", isDirectory: true)
    }
    func directory(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    func load(_ practice: AssessedPractice) async {
        guard busyAttempt != practice.id else { return }
        let token = generation
        let url = directory(practice.id).appendingPathComponent("response.json")
        let value = await Task.detached { try? CoachExchange.readResponse(url, practice: practice) }.value
        guard token == generation else { return }
        if let value { responses[practice.id] = value }
        let requestURL = directory(practice.id).appendingPathComponent("last-request.json")
        let request = await Task.detached { () -> CoachAnalysisRequest? in
            guard let data = try? Data(contentsOf: requestURL), data.count <= 2_000_000 else { return nil }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            guard let value = try? decoder.decode(CoachAnalysisRequest.self, from: data),
                  value.practiceDigest == (try? CoachExchange.digest(practice)),
                  ["audio.wav", "audio.mp3"].contains(value.audioFile) else { return nil }
            return value
        }.value
        if token == generation, let request { savedRequests[practice.id] = request }
    }
    func retry(_ practice: AssessedPractice, language: String) {
        guard let previous = savedRequests[practice.id] else { return }
        let source = directory(practice.id).appendingPathComponent(previous.id.uuidString).appendingPathComponent(previous.audioFile)
        analyze(practice: practice, file: source, channel: previous.audio.channel, language: language, previous: previous)
    }
    func fileSelectionFailed(_ error: Error, practiceID: UUID) {
        let cocoa = error as NSError
        if cocoa.domain == NSCocoaErrorDomain && cocoa.code == NSUserCancelledError { return }
        errors[practiceID] = "coach.error.failed"
    }
    func cancel() {
        task?.cancel()
        (connection?.remoteObjectProxy as? CoachAgentProtocol)?.cancel()
        resolve(.failure(CoachAgentFailure.cancelled))
    }
    private func resolve(_ result: Result<Data, Error>) {
        guard let continuation else { return }
        self.continuation = nil; timeoutTask?.cancel(); timeoutTask = nil
        connection?.invalidationHandler = nil; connection?.interruptionHandler = nil
        connection?.invalidate(); connection = nil
        continuation.resume(with: result)
    }
    private func invoke(request: Data, audio: Data, provider: CoachProvider) async throws -> Data {
        try Task.checkCancellation()
        let token = generation
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let connection = NSXPCConnection(serviceName: CoachAgentContract.serviceName)
            self.connection = connection
            connection.remoteObjectInterface = NSXPCInterface(with: CoachAgentProtocol.self)
            let failed: @Sendable () -> Void = { [weak self] in
                Task { @MainActor in if self?.generation == token { self?.resolve(.failure(CoachAgentFailure.failed)) } }
            }
            connection.invalidationHandler = failed; connection.interruptionHandler = failed
            connection.resume()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in failed() }) as? CoachAgentProtocol else {
                resolve(.failure(CoachAgentFailure.failed)); return
            }
            timeoutTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(315)) } catch { return }
                guard self?.generation == token else { return }
                self?.resolve(.failure(CoachAgentFailure.timeout))
            }
            proxy.analyze(request: request, audio: audio, provider: provider.rawValue) { [weak self] data, error in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if let data { self.resolve(.success(data)) }
                    else { self.resolve(.failure(CoachAgentFailure(rawValue: error ?? "failed") ?? .failed)) }
                }
            }
        }
    }

    func analyze(practice: AssessedPractice, take: CoachRecordedTake? = nil, file: URL? = nil,
                 channel: Int = 1, language: String, lessonContext: String = "", previous: CoachAnalysisRequest? = nil) {
        guard busyAttempt == nil else { return }
        let id = practice.id, attemptDirectory = directory(practice.id), provider = provider, jobID = UUID()
        let directory = attemptDirectory.appendingPathComponent(jobID.uuidString, isDirectory: true)
        busyAttempt = id; errors[id] = nil; generation = UUID()
        task = Task {
            defer { busyAttempt = nil; task = nil }
            do {
                let preparation = Task.detached { () throws -> (CoachAnalysisRequest, Data) in
                    let manager = FileManager.default
                    try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    let source = directory.appendingPathComponent("audio." + (file?.pathExtension.lowercased() ?? "wav"))
                    if let take { try take.write(to: source) }
                    else if let file {
                        guard ["wav", "mp3"].contains(file.pathExtension.lowercased()) else { throw CoachFileError.unsupported }
                        let scoped = file.startAccessingSecurityScopedResource()
                        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
                        if source != file {
                            try CoachAudioFile.copy(file, to: source)
                        }
                    } else { throw CoachFileError.invalid }
                    let request = try CoachExchange.prepare(audio: source, channel: channel, practice: practice,
                        language: language, lessonContext: lessonContext, take: take, id: jobID, previous: previous)
                    let data = try Data(contentsOf: source)
                    guard data.count <= CoachAudioFile.maximumBytes, CoachAudioFile.hash(data) == request.audio.sha256 else { throw CoachFileError.invalid }
                    try CoachExchange.encode(request).write(to: directory.appendingPathComponent("request.json"), options: .atomic)
                    try CoachExchange.encode(request).write(to: attemptDirectory.appendingPathComponent("last-request.json"), options: .atomic)
                    return (request, data)
                }
                let (request, audio) = try await withTaskCancellationHandler { try await preparation.value } onCancel: { preparation.cancel() }
                try Task.checkCancellation()
                savedRequests[id] = request
                let answer = try await invoke(request: CoachExchange.encode(request), audio: audio, provider: provider)
                try Task.checkCancellation()
                let feedback = try JSONDecoder().decode(CoachFeedback.self, from: answer)
                let response = CoachAnalysisResponse(schemaVersion: 1, provider: provider, createdAt: Date(), request: request, feedback: feedback)
                let save = Task.detached {
                    try Task.checkCancellation()
                    let candidate = directory.appendingPathComponent("response.pending.json")
                    defer { try? FileManager.default.removeItem(at: candidate) }
                    try CoachExchange.encode(response).write(to: candidate, options: .atomic)
                    let checked = try CoachExchange.readResponse(candidate, practice: practice)
                    try Task.checkCancellation()
                    try CoachExchange.encode(checked).write(to: attemptDirectory.appendingPathComponent("response.json"), options: .atomic)
                    try CoachExchange.encode(checked).write(to: directory.appendingPathComponent("response.json"), options: .atomic)
                    return checked
                }
                let checked = try await withTaskCancellationHandler { try await save.value } onCancel: { save.cancel() }
                try Task.checkCancellation()
                responses[id] = checked
            } catch {
                if error is CancellationError || error as? CoachAgentFailure == .cancelled { errors[id] = "coach.error.cancelled" }
                else if let failure = error as? CoachAgentFailure { errors[id] = "coach.error." + failure.rawValue }
                else if let failure = error as? CoachFileError {
                    switch failure {
                    case .tooLarge: errors[id] = "coach.error.tooLarge"
                    case .unsupported: errors[id] = "coach.error.unsupported"
                    case .channel: errors[id] = "coach.error.channel"
                    default: errors[id] = "coach.error.invalidResponse"
                    }
                } else { errors[id] = "coach.error.failed" }
            }
        }
    }

    func delete(_ id: UUID) {
        guard busyAttempt == nil else { return }
        generation = UUID()
        do { if FileManager.default.fileExists(atPath: directory(id).path) { try FileManager.default.removeItem(at: directory(id)) }; responses[id] = nil; errors[id] = nil; savedRequests[id] = nil }
        catch { errors[id] = "coach.error.delete" }
    }
    func deleteAll() {
        guard busyAttempt == nil else { return }
        generation = UUID(); deletionFailed = false
        do {
            if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
            responses = [:]; errors = [:]; savedRequests = [:]
        } catch { deletionFailed = true }
    }
}
