import AgentBridge
import Foundation
import CryptoKit

// Run only as the executable of a temporary signed sandboxed .app containing the XPC service.
let connection = NSXPCConnection(serviceName: CoachAgentContract.serviceName)
connection.remoteObjectInterface = NSXPCInterface(with: CoachAgentProtocol.self)
connection.invalidationHandler = { fputs("XPC invalidated\n", stderr); exit(1) }
connection.resume()
let proxy = connection.remoteObjectProxyWithErrorHandler { error in
    fputs("XPC connection failed: \(error)\n", stderr); exit(2)
} as! CoachAgentProtocol
let live = CommandLine.arguments.contains("--live-synthetic")
let provider = CommandLine.arguments.last == "claude" ? "claude" : "codex"
let id = UUID().uuidString
var wav = Data()
@MainActor func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
@MainActor func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
wav.append(Data("RIFF".utf8)); u32(96036); wav.append(Data("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
u32(48000); u32(96000); u16(2); u16(16); wav.append(Data("data".utf8)); u32(96000)
for frame in 0..<48000 { u16(UInt16(bitPattern: Int16(sin(Double(frame) * 2 * .pi * 220 / 48000) * 8192))) }
let input = try JSONSerialization.data(withJSONObject: [
    "schemaVersion": 1, "promptVersion": "file-coach-1", "id": id, "language": "uk", "audioFile": "audio.wav",
    "lessonContext": "Synthetic 220 Hz sine smoke test, not a person's guitar recording. Explain that practice timing cannot be judged without calibration. Do not invent guitar technique.",
    "alignment": "user-supplied-file; correspondence-and-start-offset-unverified",
    "audio": ["sha256": SHA256.hash(data: wav).map { String(format: "%02x", $0) }.joined(), "durationSeconds": 1, "sampleRate": 48000, "channel": 1,
              "events": [["id": "audio:1", "seconds": 0.1, "frequency": 220, "clarity": 1, "quality": "reliable"]]],
    "practice": ["validity": "uncalibrated", "rhythmCapability": "unmeasured", "notes": []]
])
proxy.analyze(request: live ? input : Data(), audio: live ? wav : Data(), provider: provider) { data, error in
    if live {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["requestID"] as? String == id, object["language"] as? String == "uk",
              object["summary"] as? String != nil else {
            print("Synthetic provider test failed: " + (error ?? "invalid JSON")); exit(3)
        }
        print("Signed sandbox → XPC → " + provider + " → structured Ukrainian synthetic response: passed.")
    } else {
        guard data == nil, error == "invalidRequest" else { print("Unexpected XPC reply"); exit(3) }
        print("Signed sandbox app → separate XPC service → invalidRequest: passed; no provider called.")
    }
    exit(0)
}
DispatchQueue.global().asyncAfter(deadline: .now() + (live ? 330 : 15)) { print("XPC probe timed out"); exit(4) }
dispatchMain()
