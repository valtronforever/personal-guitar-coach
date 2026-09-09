import Foundation
import AVFAudio
import Audio
import AudioTestSupport
import Domain

struct Metrics: Codable {
    let count: Int
    let median: Double?
    let p95: Double?
    let maximum: Double?
    init(_ values: [Double]) {
        let sorted = values.sorted(); count = sorted.count
        func percentile(_ p: Double) -> Double? { sorted.isEmpty ? nil : sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * p)) - 1)] }
        median = percentile(0.5); p95 = percentile(0.95); maximum = sorted.last
    }
}
struct CaseResult: Codable {
    let id: String
    let source: String
    let method: PitchMethod
    let sampleRate: Double
    let expectedOnsets: Int
    let detectedOnsets: Int
    let missedOnsets: Int
    let extraOnsets: Int
    let onsetErrorsMs: [Double]
    let noteResolutionMs: [Double]
    let stableFrames: Int
    let reliableFrames: Int
    let within15Cents: Int
    let pitchErrorsCents: [Double]
    let qualityCounts: [String: Int]
    let processingSeconds: Double
    let audioSeconds: Double
    let events: [DetectedNoteEvent]
    let ambiguousFundamentalFractions: Metrics
}
struct Corpus: Decodable {
    struct Clip: Decodable {
        let file: String
        let sampleRate: Double
        let referenceHz: Double
        let nominalMIDI: Int
        let stableStart: Double
        let stableEnd: Double
        let onsetSeconds: Double?
    }
    let clips: [Clip]
}
struct Summary: Codable {
    let source: String
    let method: PitchMethod
    let cases: Int
    let pitchErrorCents: Metrics
    let onsetErrorMs: Metrics
    let noteResolutionMs: Metrics
    let reliableCoverage: Double
    let fractionWithin15Cents: Double
    let onsetRecall: Double?
    let extraOnsets: Int
    let realTimeFactor: Double
    init(source: String, method: PitchMethod, values: [CaseResult]) {
        self.source = source; self.method = method; cases = values.count
        pitchErrorCents = Metrics(values.flatMap(\.pitchErrorsCents)); onsetErrorMs = Metrics(values.flatMap(\.onsetErrorsMs))
        noteResolutionMs = Metrics(values.flatMap(\.noteResolutionMs))
        let frames = values.map(\.stableFrames).reduce(0, +)
        reliableCoverage = Double(values.map(\.reliableFrames).reduce(0, +)) / Double(max(1, frames))
        fractionWithin15Cents = Double(values.map(\.within15Cents).reduce(0, +)) / Double(max(1, frames))
        let expected = values.map(\.expectedOnsets).reduce(0, +)
        onsetRecall = expected == 0 ? nil : 1 - Double(values.map(\.missedOnsets).reduce(0, +)) / Double(expected)
        extraOnsets = values.map(\.extraOnsets).reduce(0, +)
        realTimeFactor = values.map(\.processingSeconds).reduce(0, +) / max(1e-9, values.map(\.audioSeconds).reduce(0, +))
    }
}
struct Report: Encodable {
    let schemaVersion = 1
    let algorithmVersion = MonophonicAnalyzer.algorithmVersion
    let generatedAt = Date()
    let operatingSystem = ProcessInfo.processInfo.operatingSystemVersionString
    let mode: String
    let caveats = "Synthetic audio is original generated signal, not a guitar recording. Iowa clips are public acoustic-guitar recordings resampled from 96 kHz; reference Hz/onsets are independent algorithmic annotations, not laboratory ground truth. CPU is offline worker processing, not live callback jitter. Hardware electric/piezo/microphone validation remains U02/U04."
    let summaries: [Summary]
    let cases: [CaseResult]
}

func analyze(id: String, source: String, method: PitchMethod, rate: Double, signal: [Float], onsets: [Double], onsetsKnown: Bool = true,
             references: [(start: Double, end: Double, hz: Double)]) throws -> CaseResult {
    let analyzer = try MonophonicAnalyzer(sampleRate: rate, method: method)
    var frames = 0, reliable = 0, within = 0, qualities: [String: Int] = [:], pitchErrors: [Double] = []
    var ambiguousFractions: [Double] = []
    let start = ContinuousClock.now
    signal.withUnsafeBufferPointer { input in
        // Deliberately not aligned to DSP hop/window or the real capture buffer size.
        for offset in stride(from: 0, to: input.count, by: 769) {
            analyzer.process(.init(rebasing: input[offset..<min(input.count, offset + 769)])) { observation in
                qualities[observation.quality.rawValue, default: 0] += 1
                guard let target = references.first(where: { ($0.start...$0.end).contains(observation.time.streamSeconds) }) else { return }
                frames += 1
                if observation.quality == .ambiguous, let evidence = observation.periodEvidence { ambiguousFractions.append(evidence.fundamentalFraction) }
                if let pitch = observation.pitch, observation.quality == .reliable {
                    reliable += 1
                    guard target.hz > 0 else { return }
                    let error = abs(1200 * log2(pitch.frequency / target.hz))
                    pitchErrors.append(error); if error <= 15 { within += 1 }
                }
            }
        }
    }
    analyzer.finish()
    let elapsed = start.duration(to: .now).components
    let events = analyzer.snapshot().events
    var used: Set<UInt64> = [], errors: [Double] = [], resolutions: [Double] = [], missed = 0
    for onset in onsets {
        if let closest = events.filter({ !used.contains($0.id) }).min(by: { abs($0.onset.streamSeconds - onset) < abs($1.onset.streamSeconds - onset) }),
           abs(closest.onset.streamSeconds - onset) <= 0.06 {
            used.insert(closest.id); errors.append(abs(closest.onset.streamSeconds - onset) * 1000)
            if closest.quality == .reliable { resolutions.append((closest.resolvedAt.streamSeconds - onset) * 1000) }
        } else { missed += 1 }
    }
    return CaseResult(id: id, source: source, method: method, sampleRate: rate, expectedOnsets: onsets.count,
        detectedOnsets: events.count, missedOnsets: missed, extraOnsets: onsetsKnown ? events.count - used.count : 0,
        onsetErrorsMs: errors, noteResolutionMs: resolutions, stableFrames: frames, reliableFrames: reliable,
        within15Cents: within, pitchErrorsCents: pitchErrors, qualityCounts: qualities,
        processingSeconds: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
        audioSeconds: Double(signal.count) / rate, events: events, ambiguousFundamentalFractions: Metrics(ambiguousFractions))
}

func readWave(_ url: URL) throws -> (Double, [Float]) {
    let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
    guard file.length > 0, file.length < 48000 * 10, file.processingFormat.channelCount == 1,
          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
        throw AudioBackendError.invalidFormat
    }
    try file.read(into: buffer)
    guard let samples = buffer.floatChannelData?[0] else { throw AudioBackendError.invalidFormat }
    return (file.processingFormat.sampleRate, Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength))))
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let root = arguments.first, !root.hasPrefix("--") else {
    FileHandle.standardError.write(Data("Usage: BenchmarkAudio Tests/Fixtures/Audio [--quick] [--output report.json]\n".utf8))
    exit(2)
}
let quick = arguments.contains("--quick")
var results: [CaseResult] = []
for method in PitchMethod.allCases {
    for rate in [44100.0, 48000] {
        let pitches = quick ? [36, 38, 40, 55, 64, 76, 88] : Array(36...88)
        for midi in pitches {
            for (kind, harmonics) in [("sine", [1.0]), ("harmonic", [1, 0.4, 0.2, 0.1]), ("second", [0.25, 1, 0.1])] {
                let hz = try Pitch(midi: midi).frequency()
                let note = SyntheticNote(duration: 0.45, frequency: hz, harmonics: harmonics)
                results.append(try analyze(id: "\(kind)-midi\(midi)", source: "synthetic", method: method, rate: rate,
                    signal: SyntheticAudio.render(rate: rate, duration: 0.7, notes: [note]), onsets: [note.onset],
                    references: [(0.28, 0.5, hz)]))
            }
        }
        for midi in quick ? [36, 64] : Array(36...88) {
            for referenceA4 in [400.0, 440.0, 480.0] {
            for duration in [0.125, 0.2, 0.3, 0.5] {
                let hz = try Pitch(midi: midi).frequency(referenceA4: referenceA4)
                let notes = (0..<4).map { SyntheticNote(onset: 0.1 + Double($0) * duration, duration: duration, frequency: hz) }
                results.append(try analyze(id: "repeat-midi\(midi)-a4-\(referenceA4)-duration\(duration)", source: "durationMatrix", method: method, rate: rate,
                    signal: SyntheticAudio.render(rate: rate, duration: duration * 4 + 0.3, notes: notes), onsets: notes.map(\.onset),
                    references: notes.map { ($0.onset + min(0.16, duration * 0.8), $0.onset + duration - 0.02, hz) }))
            }
        }
        }
        for hz in [65.4064, 82.4069, 146.8324, 329.6276, 1318.5102] {
            for (name, amplitude, noise, attack) in [("quiet", 0.008, 0.0001, 0.003), ("noisy", 0.15, 0.005, 0.003),
                                                    ("loud", 0.8, 0.0001, 0.003), ("soft-attack", 0.25, 0.0001, 0.02)] {
                let note = SyntheticNote(duration: 0.6, frequency: hz, amplitude: amplitude, attack: attack)
                results.append(try analyze(id: "\(name)-hz\(hz)", source: "robustness", method: method, rate: rate,
                    signal: SyntheticAudio.render(rate: rate, duration: 0.9, notes: [note], noise: noise), onsets: [0.1],
                    references: [(0.3, 0.65, hz)]))
            }
        }
        let negativeCases: [(String, [SyntheticNote], Double, Bool)] = [
            ("silence", [], 0, false), ("noise", [], 0.1, false),
            ("clipping", [.init(duration: 1, frequency: 220, amplitude: 5)], 0, true),
            ("poly-fifth", [.init(duration: 1, frequency: 130.8128), .init(duration: 1, frequency: 195.9977)], 0, false),
            ("poly-triad", [164.8138, 195.9977, 246.9417].map { .init(duration: 1, frequency: $0) }, 0, false),
            ("low-range", [.init(duration: 1, frequency: 40)], 0, false),
            ("high-range", [.init(duration: 1, frequency: 2000)], 0, false),
            ("ambiguous-octave", [.init(duration: 1, frequency: 110, harmonics: [0.1, 1])], 0, false)
        ]
        for (name, notes, noise, clip) in negativeCases {
            results.append(try analyze(id: name, source: "negative", method: method, rate: rate,
                signal: SyntheticAudio.render(rate: rate, duration: 1, notes: notes, noise: noise, clip: clip),
                onsets: [], references: [(0.3, 1, 0)]))
        }
    }
    let directory = URL(fileURLWithPath: root, isDirectory: true)
    let corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    for clip in corpus.clips {
        let (rate, signal) = try readWave(directory.appendingPathComponent(clip.file))
        guard rate == clip.sampleRate else { throw AudioBackendError.invalidFormat }
        results.append(try analyze(id: clip.file, source: "recorded", method: method, rate: rate,
            signal: signal, onsets: clip.onsetSeconds.map { [$0] } ?? [], onsetsKnown: clip.onsetSeconds != nil,
            references: [(clip.stableStart, clip.stableEnd, clip.referenceHz)]))
    }
}
let summaries = ["synthetic", "durationMatrix", "robustness", "negative", "recorded"].flatMap { source in
    PitchMethod.allCases.map { method in Summary(source: source, method: method, values: results.filter { $0.source == source && $0.method == method }) }
}
let report = Report(mode: quick ? "quick" : "full", summaries: summaries, cases: results)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
let data = try encoder.encode(report)
if let flag = arguments.firstIndex(of: "--output"), arguments.indices.contains(flag + 1) {
    try data.write(to: URL(fileURLWithPath: arguments[flag + 1]), options: .atomic)
    print("Wrote \(results.count) cases to \(arguments[flag + 1])")
} else { FileHandle.standardOutput.write(data); print("") }
