import Foundation
import CryptoKit
import Testing
@testable import AgentBridge

struct AgentBridgeTests {
    @Test func coachingPromptKeepsSustainSummaryWithoutDumpingEveryFrame() throws {
        let source: [String: Any] = ["practice": ["sustain": ["notes": [["id": "held", "heldFraction": 0.5]]],
            "evidence": ["sustainTrace": ["frames": [["state": "pitched"]]], "analysisVersion": "fixture"]]]
        let text = try CoachAgentContract.coachingData(source)
        #expect(!text.contains("sustainTrace") && text.contains("heldFraction") && text.contains("analysisVersion"))
        #expect((source["practice"] as? [String: Any])?["evidence"] != nil)
    }
    private func request(_ audio: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "audioFile": "audio.wav",
            "audio": ["sha256": SHA256.hash(data: audio).map { String(format: "%02x", $0) }.joined()]])
    }
    @Test func providerSelectionAndPathCharactersCannotBecomeShellCommands() throws {
        let directory = URL(fileURLWithPath: "/tmp/coach ' $(touch nope)")
        let args = try CoachAgentRunner.arguments(provider: "codex", directory: directory)
        #expect(args.contains(directory.appendingPathComponent("answer.json").path))
        #expect(args.contains("read-only") && !args.contains("danger-full-access"))
        #expect(throws: CoachAgentFailure.invalidRequest) { try CoachAgentRunner.arguments(provider: "codex; touch nope", directory: directory) }
        let claude = try CoachAgentRunner.arguments(provider: "claude", directory: directory)
        #expect(claude.contains("--tools") && !claude.contains("--bare"))
    }
    @Test func corruptAudioIsRejectedBeforeAnyProviderLaunch() throws {
        let audio = Data([1, 2, 3])
        #expect(throws: CoachAgentFailure.invalidRequest) {
            try CoachAgentRunner().run(request: request(audio), audio: Data([4]), provider: "codex")
        }
    }
    @Test func providerErrorAndTimeoutNeverProduceFeedback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let stub = root.appendingPathComponent("stub")
        try Data("#!/bin/sh\nexit 7\n".utf8).write(to: stub)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stub.path)
        let audio = Data([1,2,3]), input = try request(audio)
        #expect(throws: CoachAgentFailure.failed) { try CoachAgentRunner().run(request: input, audio: audio, provider: "codex", executableOverride: stub) }
        try Data("#!/bin/sh\nwhile :; do :; done\n".utf8).write(to: stub)
        #expect(throws: CoachAgentFailure.timeout) { try CoachAgentRunner().run(request: input, audio: audio, provider: "codex", executableOverride: stub, timeout: 0.1) }
        let runner = CoachAgentRunner(); runner.cancel()
        #expect(throws: CoachAgentFailure.cancelled) { try runner.run(request: input, audio: audio, provider: "codex", executableOverride: stub) }
    }
    @Test func claudeStructuredEnvelopeMustExplicitlySucceed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let stub = root.appendingPathComponent("stub")
        try Data("#!/bin/sh\nprintf '%s' '{\"is_error\":false,\"subtype\":\"success\",\"structured_output\":{\"summary\":\"synthetic fixture\"}}'\n".utf8).write(to: stub)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stub.path)
        let audio = Data([1,2,3])
        let output = try CoachAgentRunner().run(request: request(audio), audio: audio, provider: "claude", executableOverride: stub)
        #expect(String(decoding: output, as: UTF8.self).contains("synthetic fixture"))
        try Data("#!/bin/sh\nprintf '%s' '{\"is_error\":true,\"structured_output\":{}}'\n".utf8).write(to: stub)
        #expect(throws: CoachAgentFailure.invalidResponse) { try CoachAgentRunner().run(request: request(audio), audio: audio, provider: "claude", executableOverride: stub) }
        try Data("#!/bin/sh\nprintf '%s' '{\"is_error\":true,\"result\":\"Failed to authenticate: OAuth session expired\"}'\nexit 1\n".utf8).write(to: stub)
        #expect(throws: CoachAgentFailure.authentication) { try CoachAgentRunner().run(request: request(audio), audio: audio, provider: "claude", executableOverride: stub) }
    }
}
