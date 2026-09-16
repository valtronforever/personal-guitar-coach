import CryptoKit
import Foundation

public enum CoachAgentFailure: String, Error { case invalidRequest, missingCLI, authentication, failed, timeout, cancelled, invalidResponse }

/// Runs only in the separate, non-sandboxed XPC service. No shell command interpolation.
public final class CoachAgentRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    public init() {}
    public func cancel() {
        lock.lock(); cancelled = true; let active = process; lock.unlock()
        if let active, active.isRunning { active.terminate() }
    }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    public static func arguments(provider: String, directory: URL) throws -> [String] {
        if provider == "codex" {
            return ["exec", "--ephemeral", "--ignore-user-config", "--ignore-rules", "--skip-git-repo-check",
                    "--disable", "shell_tool", "--disable", "unified_exec", "--disable", "apps",
                    "--disable", "plugins", "--disable", "hooks", "--disable", "multi_agent",
                    "--disable", "view_image", "--disable", "image_generation", "-c", "web_search=\"disabled\"",
                    "--sandbox", "read-only", "--color", "never", "--output-schema", directory.appendingPathComponent("schema.json").path,
                    "--output-last-message", directory.appendingPathComponent("answer.json").path, "-"]
        }
        if provider == "claude" {
            return ["-p", "--safe-mode", "--output-format", "json", "--json-schema", CoachAgentContract.schema,
                    "--tools", "", "--strict-mcp-config", "--mcp-config", "{\"mcpServers\":{}}",
                    "--setting-sources", "", "--settings", "{\"disableAllHooks\":true}", "--no-session-persistence"]
        }
        throw CoachAgentFailure.invalidRequest
    }

    public static func executable(provider: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        guard ["codex", "claude"].contains(provider) else { return nil }
        let candidates = ["/opt/homebrew/bin/\(provider)", "/usr/local/bin/\(provider)",
                          home.appendingPathComponent(".local/bin/\(provider)").path,
                          "/Applications/Codex.app/Contents/Resources/codex"]
        return candidates.filter { provider == "codex" || !$0.contains("Codex.app") }
            .map { URL(fileURLWithPath: $0) }.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public func run(request: Data, audio: Data, provider: String, executableOverride: URL? = nil,
                    timeout: TimeInterval = 300) throws -> Data {
        guard request.count <= CoachAgentContract.maximumRequestBytes, audio.count > 0, audio.count <= 100 * 1024 * 1024,
              let object = try JSONSerialization.jsonObject(with: request) as? [String: Any],
              object["schemaVersion"] as? Int == 1,
              let filename = object["audioFile"] as? String, ["audio.wav", "audio.mp3"].contains(filename),
              let report = object["audio"] as? [String: Any],
              report["sha256"] as? String == SHA256.hash(data: audio).map({ String(format: "%02x", $0) }).joined() else { throw CoachAgentFailure.invalidRequest }
        guard let executable = executableOverride ?? Self.executable(provider: provider) else { throw CoachAgentFailure.missingCLI }
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("coach-agent-" + UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: directory) }
        try audio.write(to: directory.appendingPathComponent(filename))
        try request.write(to: directory.appendingPathComponent("request.json"))
        try Data(CoachAgentContract.schema.utf8).write(to: directory.appendingPathComponent("schema.json"))
        let prompt = CoachAgentContract.prompt(requestJSON: try CoachAgentContract.coachingData(object), audioPath: directory.appendingPathComponent(filename).path)
        try Data(prompt.utf8).write(to: directory.appendingPathComponent("prompt.txt"))
        let input = try FileHandle(forReadingFrom: directory.appendingPathComponent("prompt.txt"))
        let stdoutURL = directory.appendingPathComponent("stdout.txt"), stderrURL = directory.appendingPathComponent("stderr.txt")
        manager.createFile(atPath: stdoutURL.path, contents: nil); manager.createFile(atPath: stderrURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: stdoutURL), errors = try FileHandle(forWritingTo: stderrURL)
        defer { try? input.close(); try? output.close(); try? errors.close() }
        let child = Process(); child.executableURL = executable
        child.arguments = try Self.arguments(provider: provider, directory: directory); child.currentDirectoryURL = directory
        child.standardInput = input; child.standardOutput = output; child.standardError = errors
        // Preserve CLI-owned authentication; the app never reads or copies credentials.
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        child.environment = environment
        lock.lock()
        if cancelled { lock.unlock(); throw CoachAgentFailure.cancelled }
        do { try child.run(); process = child; lock.unlock() }
        catch { lock.unlock(); throw CoachAgentFailure.failed }
        defer { lock.lock(); process = nil; lock.unlock() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        var failure: CoachAgentFailure?
        while child.isRunning {
            if isCancelled { failure = .cancelled }
            else if ContinuousClock.now > deadline { failure = .timeout }
            else if [stdoutURL, stderrURL, directory.appendingPathComponent("answer.json")].contains(where: {
                ((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 2_000_000
            }) { failure = .invalidResponse }
            if failure != nil {
                child.terminate()
                let grace = ContinuousClock.now.advanced(by: .seconds(2))
                while child.isRunning && ContinuousClock.now < grace { Thread.sleep(forTimeInterval: 0.05) }
                if child.isRunning { kill(child.processIdentifier, SIGKILL) }
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        child.waitUntilExit()
        if let failure { throw failure }
        if isCancelled { throw CoachAgentFailure.cancelled }
        guard child.terminationStatus == 0 else {
            var diagnostics = ""
            for url in [stdoutURL, stderrURL] {
                if let handle = try? FileHandle(forReadingFrom: url) {
                    if let data = try? handle.read(upToCount: 65536) { diagnostics += String(decoding: data, as: UTF8.self).lowercased() }
                    try? handle.close()
                }
            }
            if ["failed to authenticate", "oauth session expired", "not logged in", "invalid api key", "token expired"].contains(where: diagnostics.contains) {
                throw CoachAgentFailure.authentication
            }
            throw CoachAgentFailure.failed
        }
        let answerURL = provider == "codex" ? directory.appendingPathComponent("answer.json") : stdoutURL
        let handle = try FileHandle(forReadingFrom: answerURL); defer { try? handle.close() }
        let data = try handle.read(upToCount: 2_000_001) ?? Data()
        guard data.count <= 2_000_000 else { throw CoachAgentFailure.invalidResponse }
        if provider == "codex" { return data }
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope["is_error"] as? Bool == false, envelope["subtype"] as? String == "success",
              let structured = envelope["structured_output"] as? [String: Any] else { throw CoachAgentFailure.invalidResponse }
        return try JSONSerialization.data(withJSONObject: structured, options: [.sortedKeys])
    }
}
