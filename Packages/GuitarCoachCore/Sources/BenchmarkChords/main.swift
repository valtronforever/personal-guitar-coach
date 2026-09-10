import Foundation
import AVFAudio
import Audio

struct Manifest: Decodable {
    struct Track: Decodable { let id: String; let file: String; let split: String; let player: Int }
    let tracks: [Track]
}
struct Frame: Encodable { let seconds: Double; let quality: String; let midi: Int? }
struct Attack: Encodable { let seconds: Double; let quality: String; let midi: Int? }
struct Result: Encodable {
    let id: String; let split: String; let player: Int; let condition: String
    let sampleRate: Double; let audioSeconds: Double; let processingSeconds: Double
    let frames: [Frame]; let attacks: [Attack]; let totalEvents: UInt64
}
struct Report: Encodable {
    let algorithmVersion: String; let mode = "offline-production-monophonic-baseline"
    let chordAssessmentSupported = false; let hardwareMeasured = false; let results: [Result]
}
func nearest(_ pitch: DetectedPitch?) -> Int? { pitch.flatMap { try? $0.nearestPitch().midi } }
func analyze(url: URL, track: Manifest.Track, condition: String) throws -> Result {
    let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
    guard file.length > 0, file.length <= 48000 * 60, file.processingFormat.channelCount == 1,
          [44100.0, 48000].contains(file.processingFormat.sampleRate),
          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
        throw AudioBackendError.invalidFormat
    }
    try file.read(into: buffer)
    guard let channel = buffer.floatChannelData?[0] else { throw AudioBackendError.invalidFormat }
    var samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    guard samples.allSatisfy(\.isFinite) else { throw AudioBackendError.invalidFormat }
    if condition == "derived-distortion" {
        let peak = max(samples.map { abs($0) }.max() ?? 0, 1e-12)
        samples = samples.map { tanh(4 * $0 / peak) * 0.5 }
    }
    let rate = file.processingFormat.sampleRate
    let analyzer = try MonophonicAnalyzer(sampleRate: rate)
    var frames: [Frame] = [], attacks: [Attack] = [], lastID: UInt64 = 0
    func collect() {
        let snapshot = analyzer.snapshot()
        for event in snapshot.events where event.id > lastID {
            attacks.append(Attack(seconds: event.onset.streamSeconds, quality: event.quality.rawValue, midi: nearest(event.pitch)))
            lastID = event.id
        }
    }
    let start = ContinuousClock.now
    samples.withUnsafeBufferPointer { input in
        for offset in stride(from: 0, to: input.count, by: 769) {
            analyzer.process(.init(rebasing: input[offset..<min(input.count, offset + 769)])) { observation in
                frames.append(Frame(seconds: observation.time.streamSeconds, quality: observation.quality.rawValue, midi: nearest(observation.pitch)))
            }
            collect()
        }
    }
    analyzer.finish(); collect()
    guard lastID == analyzer.snapshot().totalEvents else { throw AudioBackendError.dataLoss }
    let elapsed = start.duration(to: .now).components
    return Result(id: track.id, split: track.split, player: track.player, condition: condition, sampleRate: rate,
        audioSeconds: Double(samples.count) / rate,
        processingSeconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
        frames: frames, attacks: attacks, totalEvents: lastID)
}
let args = CommandLine.arguments
 guard args.count == 3 else {
    FileHandle.standardError.write(Data("Usage: BenchmarkChords corpus-directory output.json\nOffline monophonic baseline only; no chord scores.\n".utf8)); exit(2)
}
let root = URL(fileURLWithPath: args[1])
let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
var results: [Result] = []
for track in manifest.tracks {
    guard !track.file.contains("/"), track.file.hasSuffix(".wav") else { throw AudioBackendError.invalidFormat }
    for condition in ["clean", "derived-distortion"] {
        results.append(try analyze(url: root.appendingPathComponent(track.file), track: track, condition: condition))
        print("\(track.id) \(condition)")
    }
}
let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
try encoder.encode(Report(algorithmVersion: MonophonicAnalyzer.algorithmVersion, results: results))
    .write(to: URL(fileURLWithPath: args[2]), options: .atomic)
